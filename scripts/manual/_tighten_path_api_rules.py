#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "pb_migrations/1787076000_durable_paths.js"
text = path.read_text(encoding="utf-8-sig")

text = text.replace(
    '        "active_revision_link.user_id = @request.auth.id && " +\n        "active_revision_link.path_id = path_id",',
    '        "active_revision_link.user_id = @request.auth.id && " +\n        "active_revision_link.lifecycle = \\\"published\\\" && " +\n        "active_revision_link.path_id = @request.body.path_id",',
    1,
)
text = text.replace(
    '        "@request.body.user_id:changed = false && " +\n        "@request.body.category_link:changed = false && " +',
    '        "@request.body.user_id:changed = false && " +\n        "@request.body.path_id:changed = false && " +\n        "@request.body.category_link:changed = false && " +',
    1,
)
text = text.replace(
    '        "active_revision_link.user_id = @request.auth.id && " +\n        "active_revision_link.path_id = path_id",',
    '        "active_revision_link.user_id = @request.auth.id && " +\n        "active_revision_link.lifecycle = \\\"published\\\" && " +\n        "active_revision_link.path_id = path_id",',
    1,
)

required = (
    '@request.body.path_id:changed = false',
    'active_revision_link.lifecycle = \\\"published\\\"',
    'active_revision_link.path_id = @request.body.path_id',
)
for token in required:
    if token not in text:
        raise SystemExit(f"Path API invariant patch missing {token}")
path.write_text(text.rstrip() + "\n", encoding="utf-8", newline="\n")

manifest_path = ROOT / "docs/POCKETBASE_MANIFEST.md"
manifest = manifest_path.read_text(encoding="utf-8-sig")
manifest = manifest.replace(
    "- `user_id` must equal `@request.auth.id` on create and remain unchanged.",
    "- `user_id` must equal `@request.auth.id` on create and remain unchanged; `path_id` and `category_link` are immutable after Path creation.",
)
manifest = manifest.replace(
    "- `paths.active_revision_link` is the sole active gate; no draft/review row may be consumed by Planner merely because it exists.",
    "- `paths.active_revision_link` is the sole active gate and may relate only to a `published` revision with the same owner and `path_id`; draft/review rows cannot be activated.",
)
manifest_path.write_text(manifest.rstrip() + "\n", encoding="utf-8", newline="\n")
print("path_api_invariants: applied")
