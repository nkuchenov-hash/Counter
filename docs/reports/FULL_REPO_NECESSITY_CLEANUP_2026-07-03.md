# Full repo necessity cleanup (2026-07-03)

Scan-and-delete pass: every tracked file must justify existence. **No production Dart behavior changed.**

| | SHA | Tracked files |
|---|---:|---:|
| **Baseline** | `b4206b4` | 548 |
| **Final** | *(commit SHA below)* | 524 (−24) |

---

## Files deleted (24)

### `design/` — removed entirely (6 files)

| File | Reason |
|---|---|
| `design/CardPlan Large.png` | Not in `pubspec.yaml` assets; no `Image.asset` / runtime load |
| `design/CardPlan Large.svg` | Same — reference-only mockups superseded by coded CardPlan geometry in `plan_card_geometry.dart` |
| `design/CardPlan Medium.png` | Same |
| `design/CardPlan Medium.svg` | Same |
| `design/CardPlan Small.png` | Same |
| `design/CardPlan Small.svg` | Same |

**Evidence:** `git grep` found comments/docs only; `pubspec.yaml` has no `assets:` section; no Dart asset loaders reference `design/`.

**`design/` folder:** **removed from repo** (empty after delete).

### Perf capture outputs (2) — should never have been tracked

| File | Reason |
|---|---|
| `shell_timeline_swipe_capture.txt` | Listed in `.gitignore`; written by `test/perf_shell_date_settle_test.dart` at runtime |
| `timeline_perf_capture.txt` | Listed in `.gitignore`; written by `test/perf_date_swipe_diag_test.dart` at runtime |

### Legacy Firebase hosting (2)

| File | Reason |
|---|---|
| `firebase.json` | Firebase hosting config; live deploy is GitHub Pages (`docs/DEPLOY.md`) |
| `.firebaserc` | Firebase project pointer; no CI or script references |

### Obsolete / dangerous scripts (10)

| File | Reason |
|---|---|
| `scripts/manual/COMPLETE_INSTALL.ps1` | Obsolete nested `counter/counter` paths, deleted `tool/*` scripts, **hardcoded credentials** |
| `scripts/manual/_count_pr.dart` | One-off probe; no workflow reference |
| `scripts/manual/_probe_pb_auth.dart` | One-off probe; no workflow reference |
| `scripts/manual/plans_dry_run_audit.dart` | Completed duplicate-plan audit (2026-06) |
| `scripts/manual/plans_duplicate_cleanup_apply.dart` | Completed one-off cleanup |
| `scripts/manual/repair_2026_06_25_plan_times_msk.dart` | Completed one-off PB repair |
| `scripts/manual/extract_l10n_from_dictionary.dart` | Superseded by `scripts/sync_locales.dart` (documented in `lib/l10n/langs/HELP HOW TO UPDATE the languages`) |
| `tools/migrate_to_pb.dart` | PocketBase migration complete; only consumer of `tools/sample_data/` |
| `tools/sample_data/plans.csv` | Sample input for removed migration script |
| `tools/sample_data/tags.csv` | Sample input for removed migration script |

### Other nonessential root files (4)

| File | Reason |
|---|---|
| `.claude/settings.local.json` | Local IDE/agent settings; not project law |
| `pocketbase.service` | Example systemd unit; not used by build/CI/scripts |
| `run_desktop_voice_test.bat` | Dev convenience launcher; not required by CI/deploy/tests |
| `scripts/p0b_build_apk.ps1` | Duplicate of `android.ps1` APK workflow |

---

## Needs human decision (1 kept)

| File | Why suspicious | Why kept |
|---|---|---|
| `scripts/manual/export_price_reporter_timesheet.dart` | No CI reference; one-off billing export | Documented in `docs/website/INTERNAL_NOTES_NOT_FOR_SITE.md` as owner billing tool; may still be run manually |

---

## Suspicious files kept with evidence

| File | KEEP reason | Evidence |
|---|---|---|
| `android.ps1` | Current local APK build | `GIT_COMMIT`/`BUILD_TIME` dart-defines; `CHANGELOG.md` shipped marker |
| `scripts/sync_locales.dart` | Locale SSOT sync | Documented in `lib/l10n/langs/HELP HOW TO UPDATE the languages` |
| `scripts/manual/td.ps1` | Deploy pipeline | `update.ps1`, `docs/DEPLOY.md` |
| `scripts/audit/architecture_guard.ps1` | Structure enforcement | `-Strict` in verification |
| `scripts/manual/generate_app_structure_detailed.py` | Doc regeneration | `APP_STRUCTURE.md` §0 |
| `scripts/manual/structure_scan.ps1` | Structure audit | `APP_STRUCTURE.md` §6 |
| `scripts/manual/smoke_desktop_*.ps1` | Desktop voice QA | Windows voice feature in `DEPLOY.md` |
| `scripts/manual/run_desktop_voice_acceptance.ps1` | Voice acceptance | Desktop voice workflow |
| `scripts/manual/check_no_preparing_ui.ps1` | UI regression guard | Desktop voice contract |
| `installer/windows/*` | Windows installer | CI `windows-desktop-build.yml`, `DEPLOY.md` |
| `pb_hooks/*.pb.js` | Server hooks | `POCKETBASE_MANIFEST.md`, `DEPLOY.md` auth section |
| `docs/website/*` (12) | Marketing pack | Intentionally repo-only per `PROJECT_KNOWLEDGE_PACK.md` |
| `integration_test/perf_date_swipe_test.dart` | Device perf test | Tracked integration test |
| `.cursor/rules/flutter_expert.mdc` | Cursor agent rules | Referenced by `.cursorrules` |
| `.github/copilot-instructions.md` | Copilot scope | GitHub Copilot entry point |

---

## Project Knowledge pack

**Unchanged — still 14 upload docs.** See `docs/PROJECT_KNOWLEDGE_PACK.md`.

---

## Interactive owner HTML map

**Not tracked in this repository.** No generator found under `git ls-files`. External HTML owner map must be regenerated manually from updated `APP_STRUCTURE.md` / `APP_STRUCTURE_DETAILED.md` if used outside git.

---

## Verification (2026-07-03)

| Check | Result |
|---|---|
| `architecture_guard.ps1 -Strict` | ✅ 0 violations |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | ✅ 0 errors |
| `flutter test` | ✅ 248/248 |
| `flutter build web --release --base-href="/Counter/" --no-tree-shake-icons --no-wasm-dry-run` | ✅ |
| `flutter build apk --release --split-per-abi --no-tree-shake-icons` | ✅ arm64-v8a + siblings |

`update.ps1`: **not run**.

---

## Confirmations

- No production Dart source changed (comments in `plan_card_geometry.dart` still mention CardPlan refs historically — no code edits)
- No app source files moved or renamed
- `design/` folder removed
- Perf capture files removed from git (tests still write gitignored paths at runtime)
