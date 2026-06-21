# AI context — pointer

**Canonical roadmap:** [`docs/ROADMAP.md`](ROADMAP.md) — phases, bugs, execution order, and future work. Do not duplicate roadmap content in this file.

---

## Repo root (June 2026)

`C:\Users\nkuch\Development\Apps\counter` — git root, `pubspec.yaml`, `.github/`, `lib/`.

The nested `counter/counter/` layout was flattened in June 2026. The old outer Flutter skeleton was backed up to `C:\Users\nkuch\Development\Apps\counter_WRAPPER_BACKUP` (sibling folder, not in git).

---

## Governing docs

| File | Purpose |
| :--- | :--- |
| `docs/ROADMAP.md` | **Current plan** — read first for structural work |
| `docs/ARCHITECTURE.md` | Iron Laws, data flow |
| `docs/APP_STRUCTURE.md` | Directory map |
| `docs/DATA_MAP.md` | Field names, business IDs |
| `docs/POCKETBASE_MANIFEST.md` | PB collections, relations |
| `docs/DEPLOY.md` | Website update / GitHub Pages |
| `CLAUDE.md` | AI navigation map, symbols, drift notes |
| `docs/reports/` | Archived audit and one-off reports |
| `docs/archive/` | Archived prompts and legacy planning notes |

---

## Deploy website

From repo root:

```powershell
.\update.ps1
```

Implementation: `scripts/manual/td.ps1` (`flutter analyze --no-fatal-infos --no-fatal-warnings`, then `flutter build web` with `--no-tree-shake-icons`). Push to `main` triggers GitHub Actions → `gh-pages`.

---

## Note on history

A full copy of the May 2026 roadmap previously lived in this file and duplicated `docs/ROADMAP.md`. That duplicate was removed 2026-06-09. Audit source material remains in `docs/reports/AUDIT_NOTES.md`.

---

## Shipped laws (do not regress)

### Record category payload

- `records.category_id` and `records.category_link` are **PocketBase relations** → `categories.id` (15-char).
- Business category slug (`categories.category_id`, e.g. `"life"`) must be **normalized to `categories.id`** before records POST/PATCH.
- Never send business slug in `records.category_id` or `records.category_link` (PB **400** `validation_missing_rel_records`).
- Anchors: `category_service.dart` (`_mapCategoryIdToLinkForPb`, `_normalizeRecordCategoryFieldsForPbApi`), `record_service.dart`.

### Tag default duration

- Field: `tags.default_plan_duration_minutes` (optional **number** in PocketBase).
- PB may return `10.0` (double); client parser must accept `num` / `int` / `double`.
- UI: `tag_default_duration_settings_view.dart` (Durations tab in tag settings).

### Time mode

- UTC instant is source of truth; **profile timezone** projection drives day filter, block placement, labels, and now-line.
- User wall time at create/edit = profile wall time (not device-local default).
- **5-minute** min duration and snap; micro/compact/medium/large card density by rendered height.
- Now-line **above** cards; **no** “outside visible range” bucket.
- Docs: `UX_CONTRACT.md` § Planning Time Mode, `DESIGN_SYSTEM.md` § PlanTimeTaskCard.

### Date swipe (do not remove)

- Horizontal swipe in **Timeline / Planning** changes the calendar day — **not** bottom-nav tab switching.
- Do **not** remove date swipe or replace with tap-only day change.
- Code: `TimelineSwipeWrapper` (`timeline_view.dart`), `PlanningSwipeWrapper` (`planning_view.dart`).
- Time-mode card drag/resize may temporarily lock day paging only while the interaction is active.
- See `UX_CONTRACT.md` § Gesture Ownership / Date Swipe Law. Performance changes require DevTools/profile proof — commit `73e87e7` date-swipe layer was **reverted** (regression).

### Recurring edit

- Virtual occurrence time/metadata edit **materializes** a one-off plan row and adds parent `exception_dates` entry (`plan_service.dart`).
