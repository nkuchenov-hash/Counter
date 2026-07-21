# Repository hygiene audit — 2026-07-21

**Baseline SHA:** `9367479ab0245bac528647bd3653ea742bf0025c` (`origin/main`)  
**Working tree at start:** clean; local `main` == `origin/main`  
**Audit source:** `git ls-files` only (ignored build output not treated as repo content)

---

## 1. Tracked inventory and classification

| Role | Count (pre-cleanup) | Count (post-cleanup) |
| :--- | ---: | ---: |
| production Dart | 371 | 371 |
| platform runner/configuration | 127 | 127 |
| test | 86 | 86 |
| reusable development script | 40 | 40 |
| architecture/documentation | 37 | 38 (+this report) |
| fixture/test data | 33 | 24 (−9 timestamped JSON) |
| CI/deployment | 14 | 14 |
| localization | 13 | 13 |
| required package metadata | 6 | 6 |
| database/backend configuration | 3 | 3 |
| generated documentation | 1 | 1 |
| **Total tracked** | **731** | **722** (−9) + report + lock/pubspec deltas |

Every retained tracked path has a concrete present-day role (runtime, platform, test/fixture, script, CI/deploy, docs, PB backend, or package metadata). Installer/Windows STT helper paths classify under CI/deployment.

---

## 2. Largest maintained source files

### Production Dart (raw physical lines / Measure-Object non-blank)

Architecture guard `LARGE_FILE` uses PowerShell `Measure-Object -Line` (non-blank). Acceptance uses that metric.

| File | Raw lines | Measure-Object | Notes |
| :--- | ---: | ---: | :--- |
| `lib/features/planning/planning_page.dart` | 2002 | 1794 | Single page + state; Time/Lists seams already extracted |
| `lib/data/plan_service.dart` | 1875 | 1775 | `part of` Brain coordinator; recent helper extractions |
| `lib/core/services/desktop_stt_helper_service.dart` | 1815 | 1715 | Already split via `part` diagnostics/lifecycle |
| `lib/features/shared/planning_task_edit_sheet.dart` | 1750 | 1719 | Edit-sheet surface |
| `lib/data/records/record_crud.dart` | 1518 | — | Record CRUD cluster |
| `lib/features/shared/desktop_voice_widget.dart` | 1501 | — | Desktop voice overlay UI |
| `lib/features/lists/lists_view.dart` | 1431 | — | Lists tab |
| `lib/data/voice_command_parser.dart` | 1397 | — | Voice parse |
| `lib/features/notes/note_editor_page.dart` | 1371 | — | Notes editor |

**Files >1200 raw lines inspected for mixed ownership:** no unjustified split recommended in this pass. Future splits only where a real ownership boundary already exists (e.g. further Planning page seams, STT helper already using `part`).

### Other large tooling / docs / binary

| Path | Size | Kind |
| :--- | ---: | :--- |
| `docs/APP_STRUCTURE_DETAILED.md` | ~1.4 MB | Generated; generator `scripts/manual/generate_app_structure_detailed.py` |
| `installer/windows/stt_helper_build/counter_stt_helper.exe` | ~33 MB | Intentional installer payload (documented; not Dart source) |
| `test/fixtures/.../scw_delmod_submit_counter_native_raw_2026_07_08.wav` | ~1.3 MB | Intentional STT fixture |

---

## 3. LARGE_FILE result

**LARGE_FILE: 0** (architecture guard Measure-Object threshold 1800).

Raw physical line counts still exceed 1800 for three files; guard does not flag them. Do not split solely for raw line count.

---

## 4. Exact duplicates

| Group | Verdict |
| :--- | :--- |
| iOS/macOS `IDEWorkspaceChecks.plist`, `WorkspaceSettings.xcsettings`, Debug/Release `.xcconfig` pairs | Flutter/Xcode scaffolding — **retain** (platform requires each path) |
| iOS LaunchImage 1x/2x/3x identical PNGs; AppIcon size aliases with same bytes | Asset catalog placeholders — **retain** |
| android debug/profile `AndroidManifest.xml` identical | Flutter template — **retain** |

No unexplained duplicate **application** source or docs requiring deletion. No duplicate scripts with identical content.

---

## 5. Tracked artifacts found

| Finding | Action |
| :--- | :--- |
| Nine `real_helper_latency_2026-07-11T*.json` under `test/fixtures/.../benchmark_reports/` | **Deleted from git** — already matched `.gitignore` rule `real_helper_latency_[0-9]*.json`; keep `real_helper_latency_latest.json` |
| `counter_stt_helper.exe` | **Retained** — installer/bench payload |
| Filename false positives (`fixed_time`, `SCREENSHOT_SHOTLIST`, `PUBLIC_COPY_DRAFTS`) | **Not junk** — product/docs names |

No tracked `build/`, `.dart_tool/`, `.bak`, `.tmp`, APK/ZIP installers, or editor swap files.

---

## 6. Orphan production Dart investigated

Import/export/`part` graph from `lib/main.dart` (+ reachable graph). **33** files not reachable from production roots; each investigated.

| Category | Examples | Disposition |
| :--- | :--- | :--- |
| Compatibility re-exports | `lib/core/widgets/plan_card/*`, `plan_create_outbox.dart`, `shell_side_navigation.dart` (core), `settings_page` feature re-export, `desktop_voice_error_classification.dart`, `profile_hydration_status_bar` feature re-export | **Retain** — deliberate shims; zero callers today but documented compat |
| Design-system / V7 pending | `confirm_dialog.dart`, `life_card.dart` | **Retain** — `DESIGN_SYSTEM_INVENTORY` marks confirm as dead-candidate for focused V7, not Stage A delete |
| Test/dev/bench-only | `desktop_voice_*benchmark*`, `desktop_voice_install_smoke_policy.dart`, `desktop_voice_wav_stt_benchmark.dart`, conditional `desktop_voice_recognizer_io.dart` | **Retain** — tests/scripts/conditional imports |
| Superseded UI (zero Dart callers) | `notes_library_page.dart`, `desktop_voice_command_panel.dart`, `notes_editor_launcher.dart` / sheet stack, `lists_inline_add.dart`, `desktop_voice_window_flags.dart`, `desktop_voice_benchmark_service.dart` | **Retain (watchlist)** — high orphan suspicion but product/docs still name them; deleting would be a feature/UI surface change outside this hygiene pass |
| Notes core barrel | `lib/core/widgets/notes/*` | **Retain** — imported by notes_editor_sheet (itself currently unused from shell; same watchlist) |

**Proven obsolete production orphans deleted:** none (insufficient consent to remove named product surfaces).

---

## 7. Unused scripts investigated

All under `scripts/`, `installer/windows/*.ps1`, `update.ps1`, `android.ps1`, `scripts/manual/td` (+ `.ps1`): each has a documented manual, deploy, smoke, structure-guide, or installer role. **No script deleted.**

---

## 8. Obsolete tests / fixtures

| Item | Verdict |
| :--- | :--- |
| Timestamped latency JSON (9) | Removed — gitignored run outputs |
| `real_helper_latency_latest.json` | Retained — canonical artifact |
| `last_attempt_diag_*.txt` / contaminated WAVs | Retained — referenced by live-quiet / contamination tests |
| Golden/parity Notes fixtures | Retained — active parity tests |

No tests deleted.

---

## 9. Documentation duplication

Multiple historical reports under `docs/reports/` remain useful decision history (`FINAL_STRUCTURE_AUDIT_*`, `FULL_REPO_NECESSITY_CLEANUP_*`, `ARCHITECTURE_GUARD_BASELINE_*`). Canonical live maps: `docs/APP_STRUCTURE.md`, generated `APP_STRUCTURE_DETAILED.md`, `docs/ARCHITECTURE.md`, `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`. **No docs deleted** in this pass (single new audit report only).

Stale NocoDB naming is already redirected by root `.cursorrules` → PocketBase docs; no mass doc rewrite performed.

---

## 10. Dependencies / assets

`pubspec.yaml` has **no** declared `assets:` / custom fonts section — no broken asset declarations.

| Dependency | Evidence | Action |
| :--- | :--- | :--- |
| `table_calendar` | Zero `lib/`/`test/`/`scripts/` imports; calendar uses custom grids; Omni-Picker no longer imports it | **Removed** |
| `cupertino_icons` | Zero `CupertinoIcons` / package imports | **Removed** |
| `crypto` | Zero package imports | **Retained (ambiguous)** — may be intended for auth/hashing; not proven safe vs future hooks |
| `app_links` | Zero Dart imports; still registered in platform plugin registrants | **Retained (ambiguous)** — deep-link/OAuth platform wiring risk |

`flutter pub get` confirmed removal of `table_calendar`, `cupertino_icons`, and transitive `simple_gesture_detector`.

---

## 11. Files deleted (exact evidence)

| Path | Former purpose | Evidence | Canonical replacement |
| :--- | :--- | :--- | :--- |
| `test/fixtures/desktop_voice_wav/benchmark_reports/real_helper_latency_2026-07-11T00-01-52.686540Z.json` | Timestamped bench run output | `.gitignore` line 75; no test reads path; writer also emits `*_latest.json` | `real_helper_latency_latest.json` |
| `...T00-06-30.043433Z.json` | same | same | same |
| `...T00-21-36.195835Z.json` | same | same | same |
| `...T00-30-11.646191Z.json` | same | same | same |
| `...T00-33-19.252197Z.json` | same | same | same |
| `...T00-36-40.392651Z.json` | same | same | same |
| `...T00-41-23.611948Z.json` | same | same | same |
| `...T00-47-14.369218Z.json` | same | same | same |
| `...T00-51-32.668341Z.json` | same | same | same |

Searches: `git grep` / ripgrep for each basename → docs generator + CHANGELOG only; tests import harness, not these files. `git check-ignore --no-index` matches `.gitignore:75`.

Also removed unused pub deps (not files): `table_calendar`, `cupertino_icons`.

---

## 12. Ambiguous candidates retained

See §6 watchlist (superseded UI, design-system pending wire-up, compat re-exports) and §10 (`crypto`, `app_links`). Also retained large intentional binary `counter_stt_helper.exe`.

---

## 13. Architecture / analyzer checks

Commands run after cleanup:

| Command | Result |
| :--- | :--- |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | exit **0** (pre-existing infos/warnings only; no new fatals) |
| `.\scripts\audit\architecture_guard.ps1 -Strict` | Violations **0**; Warnings **4** (RAW_UI only); LARGE_FILE **0**; exit **0** |
| `.\scripts\audit\architecture_guard.ps1` | Violations **0**; LARGE_FILE **0**; exit **0** |
| `.\scripts\manual\structure_scan.ps1` | tracked=723 |
| `git diff --check` | exit **0** |

---

## 14. Detailed-guide determinism

`python scripts/manual/generate_app_structure_detailed.py` run **twice** after staging the audit report; SHA-256 identical (`296DCEC0…E9D94C`). Generator reports **723** tracked files.

---

## 15. Conclusion

**The repository is structurally clean** for hygiene purposes:

- No unjustified tracked junk remaining after removing the nine gitignored timestamped bench JSONs
- No unexplained exact duplicates of application source
- No proven orphan production files deleted without product consent (watchlist documented)
- LARGE_FILE guard metric **0**
- Folders match architectural ownership already documented in `APP_STRUCTURE.md`
- Residual risk is a **product watchlist** of unused UI/compat modules and two ambiguous pub deps — not structural disorder

---

*End of report.*
