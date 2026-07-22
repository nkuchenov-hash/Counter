# Internal Notes — NOT FOR PUBLIC WEBSITE

**Audit date:** 2026-06-24 · **Pass 2:** `WEBSITE_CLAIMS_REVIEW.md`, `WEBSITE_V1_SCOPE.md`  
**Audience:** Product, engineering, content reviewers only. Do not publish, SEO-index, or paste into marketing CMS.

---

## Purpose

This file holds technical debt, WIP, risks, failed experiments, and sensitive implementation notes excluded from `PRODUCT_INVENTORY.md` public-ready messaging and all customer-facing copy.

---

## Active velocity track (June 2026)

- **Feature work paused** unless explicitly requested. Active project: **V3 UX_CONTRACT** + **V7 Design System** + Component Lab (admin).
- Website work is **separate** from V3/V7 Flutter component migration — do not block site on `_PlanningTaskCard` → `AppTaskCard` migration.

---

## WIP / unstable — do not market as complete

### Time View (large CHANGELOG surface)

Many `[wip]` entries 2026-06-15 — 2026-06-24:

- Rubber minute scale, `TimeViewYScale`, card-on-card drop resolver
- Sequential cascade patches
- Day length `RangeSlider` (−3..27h extended window)
- Drag-over-card guards, target insertion intent
- CardPlan density visual fixes

**Website rule:** Show Time View as **available** with simple schedules; avoid “professional DnD perfection” claims until owner signs off.

### Header timezone quick switcher

- CHANGELOG `[wip]` 2026-06-15: `HeaderTimezoneQuickSwitcher`, `profile_timezone_catalog.dart`
- Code exists in `global_app_header.dart` — **needs human review** before hero marketing

### Planning realtime / duplicate cards

- `[wip]` stream hub, warm window kill switch `kPlansWarmWindowEnabled=false`
- Duplicate virtual plan scrubbing — correctness project, not user feature

### P0U / performance experiments

- Kill switches in `lib/shared/diagnostics/performance/runtime_flags.dart`, `shell_flags.dart`
- `kShellDeferHiddenTabsUntilFirstFrame=false` (regressed first frame)
- `kTimelineAdjacentRowVmWarmup=false`
- `kPlanStreamLifecycleDiag=true` — diagnostic, not product

**Never mention** P0U, P0T, mounted strip, warm window on public site.

### F3 auto-save (paused)

- Notes may be **lost on sheet close without Save** — ROADMAP F3
- Do not claim “never lose notes” on website

### F2B plan category filter (deferred)

- Not implemented — only SharedPreferences design in roadmap

### Lists pin (schema gap)

- `lists_pin_item_todo` — requires `plans.is_pinned` in PocketBase
- No client-only pin — do not screenshot or promise

---

## do-not-market-yet

### Desktop Price Reporter voice command

- Shipped 2026-06-24 but `kDesktopVoiceCommandEnabled` default **false**
- Requires `--dart-define=DESKTOP_VOICE_COMMAND=true`
- Niche parser: `parsePriceReporterVoiceCommand`, `price_reporter_client_match.dart`
- Export script `scripts/manual/export_price_reporter_timesheet.dart` — **internal billing**, not end-user feature
- **Never** use Price Reporter export CSVs in marketing assets

### AI / Pro tier

- `profiles.tier`: `free` | `pro` in DATA_MAP — **client does not read `tier` in `profile.dart` / `profile_service.dart` (pass 2)**
- `pro_badge_*` in l10n — **no UI usage in `lib/`**
- `SmartPlanSheet` + `parsePlanningItemsViaAiBackend` — live; server gate unknown in repo
- **v1 website: omit AI entirely**

### Android OAuth verification

- DEPLOY.md: real-device Google/Yandex OAuth **must be verified**; may need `authWithOAuth2Code` deep link

### Wear OS

- Code complete enough for companion timer; **store/QA status unverified** in docs

### Native download links

- No verified Play Store / App Store / APK URL in governing docs
- Web is only confirmed distribution channel

---

## O1 offline limitations (honest support, not hero copy)

From ROADMAP O1.4:

- Outbox queues **device-global** — sign-out does not clear (single-user-per-device)
- Virtual recurring materialize flows need network
- `bulkUpdatePlans` / bulk complete not fully offline-queued
- Optimistic overlays **not persisted** across process death until outbox replay
- Brief stale UI possible after restart until flush

---

## Known bugs / defer items (low severity)

- `auth_service.dart` legacy UID fallbacks — non-deterministic (low, defer)
- 3 runtime test failures in roadmap (perf harness) — not user-facing
- Calendar adjacent-month overflow #19 — cosmetic defer

---

## Out of scope projects

- **Attachments #17** — separate spec; no PB file storage marketing
- **F2B, F3, V4 merges, V6 icon registry** — engineering debt
- **V9 growth** — undefined until foundation solid

---

## Security & secrets — NEVER on website

| Item | Location | Note |
| :--- | :--- | :--- |
| PocketBase production host | DEPLOY.md | sslip.io URL — internal ops |
| OAuth redirect endpoint | DEPLOY.md | PB `/api/oauth2-redirect` |
| SMTP / mail admin | DEPLOY.md | Ops only |
| `lib/core/env/env.dart` | gitignored | No env values in screenshots |
| GitHub repo | public | OK to link repo; not backend |

---

## Internal-only UI

| Feature | Gate |
| :--- | :--- |
| Component Lab | `profiles.is_admin` |
| Admin flag debug in More sheet | `debugPrint` / dev |
| `kPlanStreamLifecycleDiag` | diagnostics |
| Perf diag | `--dart-define=PERF_DIAG=true` |

---

## Architecture snippets (for reviewers, not customers)

- **Brain:** `database_service.dart` + parts; only file for HTTP
- **Singleton timeline:** client stop + `pb_hooks/records.interval_sanitize.pb.js`
- **15-char PB ids** vs business UUIDs — REST path law
- **God Object split** complete — do not market “rewrite in progress”

---

## Design system debt (V7)

- `_PlanningTaskCard`, `_BacklogPlanCard`, `_TimelineRecordCard` still legacy — `AppTaskCard` foundation only
- ~41 raw `IconButton` call sites remain
- Raw buttons in auth/profile/sheets — migration deferred

**Website:** OK to say “consistent card design”; do not claim “every pixel migrated to design system.”

---

## Changelog hygiene for public release notes

If `/changelog` on website:

- Include: O1 shipped, F1 Lists, F2A/F2C, offline banner, category default time, web deploy
- Exclude: P0U diagnostics, Price Reporter voice MVP, export scripts, kill switch toggles, `[wip]` Time View internals

---

## Uncertain features — human review checklist

- [ ] Market Wear OS?
- [ ] Market AI Smart Plan? Under what tier?
- [ ] Header timezone quick picker — shipped for users?
- [ ] Public name: Life OS vs Counter vs both?
- [ ] APK / store URLs for Download page?
- [ ] Pro pricing page or hide tier entirely?
- [ ] Light theme in marketing if app defaults dark chrome?

---

## Accidental production change protocol

If any `lib/`, `pb_hooks/`, platform folder is modified during website doc work: **revert immediately** and report. This audit touched **docs/website/** only.
