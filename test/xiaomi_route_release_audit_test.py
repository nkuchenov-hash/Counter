"""Offline regression audit of the approved Xiaomi route-cache behavior.

No account, health records, external network or installed mi_fitness needed.
The real bridge is loaded with SDK import placeholders; only region I/O is mocked.
"""
import importlib.util
import sys
import tempfile
import time
import types
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch, AsyncMock

sdk = types.ModuleType("mi_fitness")
sdk.MiHealthClient = object
sdk.XiaomiAuth = object
with patch.dict(sys.modules, {"mi_fitness": sdk}):
    spec = importlib.util.spec_from_file_location(
        "xiaomi_bridge_audit", Path(__file__).resolve().parents[1] / "pb_hooks" / "xiaomi_sleep_bridge.py"
    )
    bridge = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bridge)

def session(start, end):
    return {"start": datetime.fromtimestamp(start, timezone.utc).isoformat(),
            "end": datetime.fromtimestamp(end, timezone.utc).isoformat()}

class RouteAudit(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.token = Path(self.temp.name) / "token.json"
        self.now = int(time.time())
        self.cutoff = self.now - 3600
        self.primary, self.other, *_ = bridge._route_candidates()
        self.fresh = {"fresh": session(self.now - 27000, self.now - 120)}
        self.stale = {"old": session(self.now - 100000, self.now - 80000)}

    async def run_selection(self, probe, diagnostic=None):
        with patch.object(bridge, "_probe_region", new=probe):
            return await bridge._select_sleep_region(
                self.token, 1, self.now - 30 * 86400, self.now, 32, self.cutoff,
                diagnostics=diagnostic)

    async def test_warm_preferred_route_uses_one_region(self):
        bridge._save_route_state(self.token, self.other, self.now, {})
        probe = AsyncMock(return_value=(self.fresh, {"success": 1, "errors": []}))
        rows, route = await self.run_selection(probe)
        self.assertEqual(route, self.other)
        self.assertEqual(rows, self.fresh)
        self.assertEqual(probe.await_count, 1)

    async def test_stale_primary_falls_back_and_keeps_independent_history(self):
        async def answer(token, uid, host, *args):
            if host == self.primary:
                return self.stale, {"success": 1, "errors": []}
            if host == self.other:
                return self.fresh, {"success": 1, "errors": []}
            return {}, {"success": 0, "errors": ["TimeoutError"]}
        probe = AsyncMock(side_effect=answer)
        diagnostics = {}
        rows, route = await self.run_selection(probe, diagnostics)
        self.assertEqual(route, self.other)
        self.assertEqual(set(rows), {"old", "fresh"})
        self.assertEqual(diagnostics["source_status"], "available")
        self.assertEqual(probe.await_count, len(bridge._route_candidates()))
        preferred, cooldowns = bridge._load_route_state(self.token, time.time())
        self.assertEqual(preferred, self.other)
        self.assertNotIn(self.other, cooldowns)

    async def test_empty_unrelated_success_does_not_hide_primary_outage(self):
        async def answer(token, uid, host, *args):
            return ({}, {"success": 0, "errors": ["TimeoutError"]}) if host == self.primary else ({}, {"success": 1, "errors": []})
        diagnostic = {}
        with self.assertRaises((bridge.XiaomiCloudTimeout, bridge.XiaomiCloudUnavailable)):
            await self.run_selection(AsyncMock(side_effect=answer), diagnostic)
        self.assertEqual(diagnostic["source_status"], "network_unavailable")

    async def test_all_cooldown_routes_are_retried(self):
        bridge._save_route_state(self.token, self.primary, self.now,
            {host: self.now + 600 for host in bridge._route_candidates()})
        probe = AsyncMock(return_value=(self.fresh, {"success": 1, "errors": []}))
        rows, _ = await self.run_selection(probe)
        self.assertEqual(rows, self.fresh)
        self.assertEqual(probe.await_count, 1)

    def test_bad_cache_does_not_supply_an_arbitrary_host(self):
        bridge._route_cache_path(self.token).write_text(
            '{"preferred":"https://untrusted.invalid","confirmed_at":' + str(self.now) + '}')
        self.assertEqual(bridge._load_route_state(self.token, self.now), (None, {}))
        bridge._route_cache_path(self.token).write_text("corrupt json")
        self.assertEqual(bridge._load_route_state(self.token, self.now), (None, {}))

    def test_overlap_preserves_preferred_version(self):
        rows = dict(self.fresh)
        bridge._merge_missing_intervals(rows, {
            "revision": session(self.now - 26990, self.now - 180),
            "old": self.stale["old"],
        })
        self.assertEqual(set(rows), {"fresh", "old"})

if __name__ == "__main__":
    unittest.main()
