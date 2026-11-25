#!/usr/bin/env python3
"""Fail closed on changes to release-critical content without owner approval."""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import tempfile
from pathlib import Path

# Bootstrap locks the existing revision, not a claim of functional acceptance.
BASELINE = "613765109ef6484ea5a786604adfb146b258a502"
APPROVAL_VARIABLE = "LIFEOS_CRITICAL_APPROVED_DIGEST"
PROTECTED_PATHS = (
    "lib/main.dart",
    "lib/app/shell/",
    "lib/data/",
    "lib/features/auth/",
    "lib/features/settings/health/",
    "lib/services/health_connect/",
    "pb_hooks/",
    "pb_migrations/",
    "pubspec.yaml",
    "pubspec.lock",
    "android/app/src/main/AndroidManifest.xml",
    "ios/Runner/Runner.entitlements",
)
ROOT = Path(__file__).resolve().parents[2]


def snapshot(revision: str, root: Path = ROOT) -> dict[bytes, bytes]:
    raw = subprocess.check_output(
        ["git", "ls-tree", "-r", "-z", "--full-tree", revision, "--", *PROTECTED_PATHS],
        cwd=root,
    )
    out = {}
    for entry in raw.split(b"\0"):
        if not entry:
            continue
        metadata, path = entry.split(b"\t", 1)
        out[path] = metadata
    if not out:
        raise RuntimeError("Protected tree is empty; refusing approval")
    return out


def fingerprint(tree: dict[bytes, bytes]) -> str:
    digest = hashlib.sha256()
    for path in sorted(tree):
        digest.update(path + b"\0" + tree[path] + b"\0")
    return digest.hexdigest()


def approved(actual: str, baseline: str, configured: str) -> bool:
    # Once an owner configures a new fingerprint, the old baseline is no
    # longer implicitly allowed. Never accept a malformed or blank override.
    expected = configured.strip() or baseline
    return bool(re.fullmatch(r"[0-9a-f]{64}", expected)) and actual == expected


def verify() -> int:
    before = snapshot(BASELINE)
    after = snapshot("HEAD")
    baseline = fingerprint(before)
    actual = fingerprint(after)
    configured = os.environ.get(APPROVAL_VARIABLE, "")
    print(f"critical_tree_sha256={actual}")
    if approved(actual, baseline, configured):
        print("critical_release_guard: OK (exact protected content matches approval)")
        return 0
    print("critical_release_guard: BLOCKED — protected content lacks owner approval")
    for path in sorted(before.keys() | after.keys()):
        if before.get(path) != after.get(path):
            print(f"  changed from bootstrap: {os.fsdecode(path)}")
    print(f"Owner review required; do not modify this guard or set {APPROVAL_VARIABLE} as an agent.")
    return 1


def self_test() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)

        def git(*args: str) -> None:
            subprocess.run(["git", *args], cwd=root, check=True, capture_output=True)

        def put(path: str, text: str) -> None:
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")

        def commit(message: str) -> None:
            git("add", "-A")
            git("-c", "user.name=Guard Test", "-c", "user.email=guard@example.invalid",
                "commit", "-m", message)

        git("init")
        put("pb_hooks/sleep_sync.pb.js", "baseline")
        put("lib/features/timeline/view.dart", "presentation")
        commit("baseline")
        original = fingerprint(snapshot("HEAD", root))
        put("lib/features/timeline/view.dart", "new presentation")
        commit("unprotected change")
        assert fingerprint(snapshot("HEAD", root)) == original
        put("pb_hooks/sleep_sync.pb.js", "changed sleep")
        commit("protected change")
        changed = fingerprint(snapshot("HEAD", root))
        assert changed != original
        assert not approved(changed, original, "")
        assert approved(changed, original, changed)
        assert not approved(original, original, changed)
        assert not approved(changed, original, "invalid")
        put("pb_hooks/new_hook.js", "new hook")
        commit("protected addition")
        added = fingerprint(snapshot("HEAD", root))
        assert added != changed and not approved(added, original, changed)
        (root / "pb_hooks/sleep_sync.pb.js").unlink()
        commit("protected deletion")
        deleted = fingerprint(snapshot("HEAD", root))
        assert deleted != added and not approved(deleted, original, added)
    print("critical_release_guard: self-test OK (UI change, modification, addition, deletion, exact approval, rollback)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    if parser.parse_args().self_test:
        self_test()
    else:
        raise SystemExit(verify())
