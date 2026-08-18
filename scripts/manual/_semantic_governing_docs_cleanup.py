#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "docs/ARCHITECTURE.md"
text = path.read_text(encoding="utf-8-sig")

text = text.replace(
    "| `lib/data/database_service.dart` | **The Brain** | PocketBase SDK for profiles, categories, records, plans. Single place for server I/O. |",
    "| `lib/data/database_service.dart` | **The Brain** | PocketBase SDK coordinator for profiles, categories, records, plans, Paths, and other app-owned collections; focused `part of` modules own domain persistence while this library remains the server-I/O boundary. |",
)
text = text.replace(
    "| `lib/features/voice/` | **Desktop Voice UI** | Flutter overlay widget, capsule, correction sheet, command panel. |",
    "| `lib/features/voice/` | **Desktop Voice UI** | Flutter desktop overlay widget, capsule, and correction sheet. |",
)
text = text.replace(
    "- **Business IDs:** `user_id` (UUID string), `record_id`, `plan_id`, `categories.category_id` (business slug) — carried in row data for filtering and matching. **Record REST category payloads** use 15-char `categories.id`, not the business slug.",
    "- **Ownership vs business IDs:** child-collection `user_id` is a PocketBase Relation to 15-char `profiles.id`. Domain business identifiers such as `record_id`, `plan_id`, and `categories.category_id` remain separate application identifiers. **Record REST category payloads** use 15-char `categories.id`, not the category business key.",
)
path.write_text(text.rstrip() + "\n", encoding="utf-8", newline="\n")
print("governing_docs_semantics: applied")
