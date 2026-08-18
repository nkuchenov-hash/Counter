#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path: str, body: str) -> None:
    (ROOT / path).write_text(body.rstrip() + "\n", encoding="utf-8", newline="\n")


for rel in (
    "docs/APP_STRUCTURE.md",
    "docs/ARCHITECTURE.md",
    "docs/POCKETBASE_MANIFEST.md",
    "docs/DATA_MAP.md",
):
    body = read(rel).replace("active_revision_id", "active_revision_link")
    write(rel, body)

manifest = read("docs/POCKETBASE_MANIFEST.md")
manifest = manifest.replace(
    "| `category_id` | integer | LIFE OS category business id; one Path per owner/category. |",
    "| `category_link` | relation | → `categories.id`; stable server relation; one Path per owner/category. |",
)
manifest = manifest.replace(
    "| **`active_revision_link`** | text | **Only executable revision pointer.** Must reference this Path's business `revision_id`. |",
    "| **`active_revision_link`** | relation | → `path_revisions.id`; **only executable revision relation**. API rules require the referenced revision to have the same owner and `path_id`. |",
)
manifest = manifest.replace(
    "Stable Path/project identity + single `active_revision_link` execution pointer.",
    "Stable Path/project identity + category relation + single `active_revision_link` execution relation.",
)
manifest = manifest.replace(
    "Only `paths.active_revision_link` activates a revision.",
    "Only the `paths.active_revision_link` relation activates a revision.",
)
write("docs/POCKETBASE_MANIFEST.md", manifest)

data_map = read("docs/DATA_MAP.md")
data_map = data_map.replace(
    "| `paths` | `category_id` | LIFE OS category business id attached to the project. |",
    "| `paths` | `category_link` | Stable PocketBase relation → `categories.id`; never a local `CategoryRule.id`. |",
)
data_map = data_map.replace(
    "| `paths` | `active_revision_link` | Sole revision permitted to feed Planner. |",
    "| `paths` | `active_revision_link` | Relation → `path_revisions.id`; sole revision permitted to feed Planner. |",
)
write("docs/DATA_MAP.md", data_map)

architecture = read("docs/ARCHITECTURE.md")
architecture = architecture.replace(
    "`paths.active_revision_link` is the sole executable revision pointer.",
    "`paths.active_revision_link` is the sole executable revision relation.",
)
architecture = architecture.replace(
    "`paths.active_revision_link` selects one executable revision;",
    "`paths.active_revision_link` relates the project to one executable revision;",
)
write("docs/ARCHITECTURE.md", architecture)

print("durable_paths_relation_docs: applied")
