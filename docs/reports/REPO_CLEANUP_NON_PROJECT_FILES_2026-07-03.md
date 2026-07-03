# Repo Cleanup — Non-Project Files (2026-07-03)

**Baseline SHA:** `4aa7987`  
**Pass type:** Hygiene only — remove junk; no production Dart changes

---

## Scan method

```powershell
git rev-parse --short HEAD
git status --short
git status --ignored --short
git ls-files
Get-ChildItem -Recurse -File  # compared against tracked + gitignore
.\scripts\audit\architecture_guard.ps1 -Strict
flutter analyze --no-fatal-infos --no-fatal-warnings
```

**Tracked files before cleanup:** 592  
**Tracked files after cleanup:** 588 (−4 export artifacts)

---

## Files deleted

### Local only (untracked / gitignored — no commit for these alone)

| Path | Reason |
| :--- | :--- |
| `docs/reports/_structure_tree_snapshot.tmp` | Ephemeral structure-scan output (`docs/reports/_*.tmp` gitignored) |
| `docs/reports/_tracked_files.tmp` | Same |
| `docs/reports/_tracked_lib_files.tmp` | Ad-hoc scan list from earlier session |
| `docs/reports/_working_tree_status.tmp` | Same |
| `android/hs_err_pid515424.log` | JVM crash dump (not project source) |
| `android/hs_err_pid518908.log` | Same |
| `android/hs_err_pid519196.log` | Same |
| `android/replay_pid515424.log` | Same |
| `android/replay_pid519196.log` | Same |
| `scripts/__pycache__/` | Python bytecode cache |
| `planning_perf_capture.txt` | Perf test capture (`*_perf_capture.txt` gitignored) |
| `shell_timeline_swipe_capture.txt` | Perf capture (gitignored) |
| `timeline_perf_capture.txt` | Perf capture (gitignored) |

### Removed from git tracking (committed cleanup)

| Path | Reason |
| :--- | :--- |
| `exports/price_reporter_timesheet_2026-05-11_to_now.csv` | Accidental commit of Price Reporter audit export output — user data, not app source |
| `exports/price_reporter_timesheet_2026-05-11_to_now excel.xlsx` | Same |
| `exports/price_reporter_timesheet_2026-05-11_to_now_audit.csv` | Same |
| `exports/price_reporter_timesheet_2026-05-11_to_now_audit exc.csv` | Same |

**`.gitignore` updated:** added `exports/` (script output dir; was only `tools/exports/` before).

Export script `scripts/manual/export_price_reporter_timesheet.dart` still writes to `exports/` locally — output must stay untracked.

---

## Files kept intentionally

| Path / group | Reason |
| :--- | :--- |
| `scripts/pass3_*`, `scripts/extract_*`, `scripts/split_planning_page.py` | Historical Pass 3 extraction tooling; documented in `APP_STRUCTURE.md` §7 |
| `scripts/manual/structure_scan.ps1`, `generate_app_structure_detailed.py` | Current structure doc workflow |
| `scripts/audit/architecture_guard.ps1`, `scripts/manual/td.ps1`, `scripts/sync_locales.dart` | Active CI/deploy/audit |
| `docs/archive/*` | Intentional archived notes |
| `docs/reports/*` (pass reports) | Historical decomposition audit trail |
| `tools/sample_data/*.csv` | Migration/sample fixtures |
| `run_desktop_voice_test.bat` | Tracked desktop voice test entry |
| Platform folders (`android/`, `ios/`, …) | Flutter embedder boilerplate required for builds |
| `.claude/settings.local.json` | Local IDE config (gitignored) — not deleted |

---

## Needs human decision

| Item | Notes |
| :--- | :--- |
| **None blocking** | All candidates either deleted (clear junk) or kept with documented reason |

Optional future hygiene (not done in this pass):

- Archive or delete historical `scripts/pass3_*` / `scripts/extract_*` if team agrees they are no longer reference-only (currently kept per `APP_STRUCTURE.md` §7).

---

## Ignored / generated folders confirmed excluded

| Folder | Status |
| :--- | :--- |
| `.git/` | VCS |
| `.dart_tool/`, `build/` | Flutter generated |
| `.idea/`, `*.iml` | IDE local |
| `android/.gradle/`, `android/build/` | Gradle cache/output |
| `installer/windows/output/` | Installer build output |
| `tools/exports/`, `tools/reports/` | Already gitignored |
| `exports/` | **Now gitignored** (was mistakenly tracked) |
| `docs/reports/_*.tmp` | Scan temp files |

---

## Verification

| Gate | Result |
| :--- | :--- |
| `architecture_guard -Strict` | 0 violations |
| `flutter analyze` | 0 errors |
| `flutter test` | 248/248 |
| Web/APK build | Skipped (no runtime changes) |

---

## Conclusion

- **No production Dart behavior changed**
- **No app files moved or renamed**
- Structure docs (`APP_STRUCTURE.md`, `APP_STRUCTURE_DETAILED.md`) still match tree — only removed non-source export artifacts not listed in structure docs
- Failed Pass 4 scripts (`pass4_brain_split.py`, `pass4_split_fast.py`) were **already absent** from disk and git
