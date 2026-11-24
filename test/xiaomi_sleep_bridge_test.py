"""Regression checks for the server-only Xiaomi sleep bridge (no real credentials)."""
import asyncio
import importlib.util
import sys
import types
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

sys.modules["mi_fitness"] = types.SimpleNamespace(MiHealthClient=object, XiaomiAuth=object)
spec = importlib.util.spec_from_file_location("xiaomi_sleep_bridge", Path(__file__).resolve().parents[1] / "pb_hooks/xiaomi_sleep_bridge.py")
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)

class SleepBridgeTests(unittest.IsolatedAsyncioTestCase):
    async def test_request_timeout_and_partial_success(self):
        class Client:
            async def _request(self, method, path, **kwargs):
                if path == "slow":
                    await asyncio.sleep(10)
                return {"code": 0, "result": {"data_list": []}}
        stats = {"success": 0, "errors": []}
        with patch.object(bridge, "XIAOMI_REQUEST_TIMEOUT_SECONDS", 0.01):
            self.assertEqual(await bridge._query_sleep(Client(), stats, "GET", "slow"), {})
            self.assertTrue(await bridge._query_sleep(Client(), stats, "GET", "fast"))
        self.assertEqual(stats, {"success": 1, "errors": ["TimeoutError"]})

    async def test_region_fallback_runs_concurrently(self):
        cutoff = datetime.now(timezone.utc).timestamp() - 60
        active = 0
        maximum = 0
        fresh = {"latest": {"end": datetime.now(timezone.utc).isoformat()}}
        primary = bridge.XIAOMI_HEALTH_BASE_URL
        target = next(base for base in bridge.XIAOMI_HEALTH_REGION_URLS if base != primary)
        async def probe(token, uid, base, start, end, limit):
            nonlocal active, maximum
            active += 1
            maximum = max(active, maximum)
            await asyncio.sleep(0.01)
            active -= 1
            return (fresh if base == target else {}, {"success": 1, "errors": []})
        with patch.object(bridge, "_probe_region", probe):
            sessions, selected = await bridge._select_sleep_region(Path("unused"), 1, 0, 1, 30, cutoff)
        self.assertEqual(sessions, fresh)
        self.assertEqual(selected, target)
        self.assertGreater(maximum, 1)

    async def test_complete_failure_is_not_empty_success(self):
        async def probe(*args):
            return {}, {"success": 0, "errors": ["TimeoutError"]}
        with patch.object(bridge, "_probe_region", probe):
            with self.assertRaises(bridge.XiaomiCloudTimeout):
                await bridge._select_sleep_region(Path("unused"), 1, 0, 1, 30, 1)

    async def test_valid_empty_response_is_not_auth_failure(self):
        async def probe(*args):
            return {}, {"success": 1, "errors": []}
        with patch.object(bridge, "_probe_region", probe):
            sessions, selected = await bridge._select_sleep_region(Path("unused"), 1, 0, 1, 30, 1)
        self.assertEqual(sessions, {})
        self.assertEqual(selected, bridge.XIAOMI_HEALTH_BASE_URL)

    async def test_all_auth_failures_classified(self):
        async def probe(*args):
            return {}, {"success": 0, "errors": ["XiaomiCloudAuthError"]}
        with patch.object(bridge, "_probe_region", probe):
            with self.assertRaises(bridge.XiaomiCloudAuthError):
                await bridge._select_sleep_region(Path("unused"), 1, 0, 1, 30, 1)

if __name__ == "__main__":
    unittest.main()
