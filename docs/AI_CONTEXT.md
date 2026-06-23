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

---

## Performance Kill Switch Law (P0V — mandatory for all AI work)

**Read:** `docs/ARCHITECTURE.md` § **PERFORMANCE_KILL_SWITCH_LAW** · `docs/UX_CONTRACT.md` § **Performance & Responsiveness Contract**

Performance, responsiveness, and stability are sacred. The worst possible failure is not imperfect UI — it is damaging speed, stability, instant feedback, or basic usability.

### If the user reports slowness, crash, missing instant update, or “it became impossible to work”

**Stop all new feature / preload / design / V3 / V7 work immediately.** Do not stack more experiments. Do not add another preload/cache/render layer.

**Emergency stabilization sequence:**
1. Find the regression (recent P0S/P0T/mounted strip/render snapshot/reveal gate/boot projection changes are prime suspects).
2. **Disable** the latest risky path **by default** (`kUseP0tMountedStrip`, verbose projection flags, experimental `PerfFlags`, etc.).
3. Restore last known stable behavior (`PageView.builder` + `DatePagerSettleGate`, live optimistic streams on active pages).
4. Preserve optimistic UI — record/plan create must appear instantly without refresh.
5. Remove hot-path overload (no full-plan projection, mounted window explosion, per-row log spam on startup/swipe).
6. Add or verify log guards (`P0U_RELEASE_LOG_GUARD`, gated `TIME_TZ_PROJECT`).
7. Run **web** test and **Android APK** if mobile is affected.
8. Report exact root cause; only then continue with smaller scoped fixes.

### Banned reasoning (implementation failed if user feels it)

- “The cache exists” is **not** enough.
- “Snapshot is ready” is **not** enough.
- “Body cache exists” is **not** enough.
- If the user sees lag, loading, freeze, or crash, the implementation **failed** — regardless of theoretical benefits.
- Do **not** keep broken experimental code active because it is “theoretically better” or “will be faster later.”

### Experimental preload/render paths

- Must be **default-off** until proven stable on **web and Android**.
- Release defaults choose **stability** over theoretical preload.
- Anchors: `lib/core/p0u_feature_flags.dart`, `lib/core/perf_flags.dart`.
