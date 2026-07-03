# Final structure parity and documentation cleanup (2026-07-03)

Architecture-only pass. **No production Dart behavior changed.** No app source files moved or renamed.

---

## Baseline and final SHA

| | SHA | Tracked files |
| :--- | :--- | :--- |
| **Baseline** (start of pass) | `19d794a` | 589 |
| **After cleanup** (pre-commit) | `19d794a` | 553 (−36) |
| **Final** (after commit) | `e52e364` | 554 (+1 new report) |

---

## Physical scan method

1. `git ls-files`, `git status --short`, `git status --ignored --short`
2. Recursive classification of repo root into: application source, tooling, canonical docs, historical docs, generated/ignored, delete candidates
3. Cross-check against `docs/APP_STRUCTURE.md`, `docs/APP_STRUCTURE_DETAILED.md`, `AGENTS.md`, `CLAUDE.md`
4. Post-cleanup: `python scripts/manual/generate_app_structure_detailed.py`, `.\scripts\manual\structure_scan.ps1`
5. `git grep` for every deleted path stem — broken references fixed in governing docs

---

## Files deleted (36 total)

### Obsolete / superseded documentation (20)

| Path | Reason |
| :--- | :--- |
| `docs/reports/REFACTOR_SUMMARY.md` | Supabase-era refactor notes; app uses PocketBase |
| `docs/reports/WEB_DEPLOYMENT_SUMMARY.md` | Firebase-era deploy; superseded by `docs/DEPLOY.md` |
| `docs/reports/ENTRANCE_BUILD.md` | One-off build notes; no current workflow |
| `docs/reports/VISUAL_AUDIT_328_RECORDS.md` | Point-in-time visual audit; decisions in `AUDIT_NOTES.md` / ROADMAP |
| `docs/reports/FIXES_SURGICAL_AND_COLLISION.md` | Surgical fix log; shipped fixes recorded in `CHANGELOG.md` |
| `docs/reports/HYBRID_CLOUD.md` | Obsolete hybrid-cloud experiment |
| `docs/reports/AUTH_SETUP.md` | Supabase/Yandex OAuth setup; auth is PocketBase (`POCKETBASE_MANIFEST.md`) |
| `docs/reports/CODEBASE_CLEANUP_AUDIT_2026-06-22.md` | Intermediate cleanup audit; superseded by final parity + `ROADMAP.md` |
| `docs/reports/REPO_STRUCTURE_LOCKDOWN_2026-06-23.md` | Lockdown inventory; contract now in `APP_STRUCTURE.md` + guard |
| `docs/reports/STRUCTURE_DECOMPOSITION_AUDIT_2026-07-02.md` | Pre-pass audit; Pass 3–4D complete |
| `docs/reports/LARGE_FILE_SPLIT_BLUEPRINT_2026-07-02.md` | Blueprint executed as Pass 3–4D; summary below |
| `docs/reports/STRUCTURE_DECOMPOSITION_PASS3_2026-07-03.md` | Intermediate pass report |
| `docs/reports/STRUCTURE_DECOMPOSITION_PASS3B_2026-07-03.md` | Intermediate pass report |
| `docs/reports/STRUCTURE_DECOMPOSITION_PASS4A_PLAN_2026-07-03.md` | Intermediate pass report |
| `docs/reports/STRUCTURE_DECOMPOSITION_PASS4B_RECORD_2026-07-03.md` | Intermediate pass report |
| `docs/reports/STRUCTURE_DECOMPOSITION_PASS4C_CATEGORY_2026-07-03.md` | Intermediate pass report |
| `docs/reports/STRUCTURE_DECOMPOSITION_PASS4D_PROFILE_2026-07-03.md` | Intermediate pass report |
| `docs/reports/_lockdown_inventory.csv` | Temporary lockdown CSV; not a canonical doc |
| `docs/archive/LIFE_OS_CURSOR_PROMPT.md` | Legacy prompt; superseded by `AGENTS.md` / `CLAUDE.md` |
| `docs/archive/lib_notes_scratch.txt` | Personal dev scratch; not project knowledge |

### Obsolete one-off extraction scripts (16)

| Path | Reason |
| :--- | :--- |
| `scripts/extract_app_shell_pass2.py` | Pass 2 extraction complete |
| `scripts/extract_offline_sync_bar.py` | Pass 2 extraction complete |
| `scripts/extract_plan_card_metrics.py` | Pass 2 extraction complete |
| `scripts/extract_plan_card_pass2.py` | Pass 2 extraction complete |
| `scripts/extract_planning_pass2.py` | Pass 2 extraction complete |
| `scripts/extract_planning_tail.py` | Pass 2 extraction complete |
| `scripts/extract_profile_sections.py` | Pass 2 extraction complete |
| `scripts/extract_shared_widgets.py` | Pass 2 extraction complete |
| `scripts/pass3_extract_app_shell.py` | Pass 3 extraction complete |
| `scripts/pass3_extract_lists.py` | Pass 3 extraction complete |
| `scripts/pass3_extract_plan_card.py` | Pass 3 extraction complete |
| `scripts/pass3_extract_planning_time_view.py` | Pass 3 extraction complete |
| `scripts/pass3_extract_timeline.py` | Pass 3 extraction complete |
| `scripts/pass3_normalize_plan_card.py` | Pass 3 extraction complete |
| `scripts/pass3b_patch_lists_view.py` | Pass 3B complete |
| `scripts/split_planning_page.py` | Planning split complete |

---

## Decomposition acceptance summary (consolidated from removed pass reports)

| Pass | Scope | Outcome |
| :--- | :--- | :--- |
| **3** | Shell, planning, timeline, shared widgets, plan card | UI modules extracted under `lib/features/` |
| **3B** | Lists view patch | Lists decomposition aligned with Pass 3 |
| **4A** | `plan_service.dart` | Coordinator + `lib/data/plans/*` parts |
| **4B** | `record_service.dart` | Coordinator + `lib/data/records/*` parts |
| **4C** | `category_service.dart` | Coordinator + `lib/data/categories/*` parts |
| **4D** | `profile_service.dart` | Coordinator + `lib/data/profile/*` parts |

All passes: strict guard green, analyze 0 errors, tests 248/248 at ship time. Details preserved in `CHANGELOG.md` dated entries.

---

## Canonical docs kept

| Doc | Topic |
| :--- | :--- |
| `docs/APP_STRUCTURE.md` | Concise structure map |
| `docs/APP_STRUCTURE_DETAILED.md` | Bilingual per-file guide (regenerated) |
| `docs/APP_STRUCTURE_EXPLAINED_RU.md` | Russian short guide |
| `docs/ARCHITECTURE.md` | Iron Laws, data flow |
| `docs/UX_CONTRACT.md` | Interaction behavior |
| `docs/DATA_MAP.md` | Field names, business IDs |
| `docs/POCKETBASE_MANIFEST.md` | PB collections, relations |
| `docs/DESIGN_SYSTEM.md` | Design system contract |
| `docs/DEPLOY.md` | Deploy workflow |
| `docs/ROADMAP.md` | Status and priorities |
| `CHANGELOG.md` | Shipped history |
| `AGENTS.md` | Codex / agent instructions |
| `CLAUDE.md` | AI navigation map |
| `docs/AI_CONTEXT.md` | Pointer to governing docs |

### Reports kept

| Report | Reason |
| :--- | :--- |
| `docs/reports/AUDIT_NOTES.md` | Referenced by `ROADMAP.md`; unique April 2026 audit findings |
| `docs/reports/DESIGN_SYSTEM_INVENTORY.md` | Component inventory for V7 migration |
| `docs/reports/FILE_STRUCTURE_SCAN_2026-07-03.md` | Scan methodology snapshot |
| `docs/reports/REPO_CLEANUP_NON_PROJECT_FILES_2026-07-03.md` | Junk cleanup record |
| `docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md` | This file |

### Other docs kept

| Path | Reason |
| :--- | :--- |
| `docs/website/*` | Product/marketing copy for web deploy |
| Root `README.md`, `CHATGPT_PROMPT_WRITING_RULES_FOR_COUNTER.md` | Project readme / meta prompt rules |

---

## Needs human decision

**None blocking.** All delete candidates had clear supersession or non-project classification.

---

## APP_STRUCTURE parity result

| Check | Result |
| :--- | :--- |
| Every tracked `lib/**/*.dart` in `APP_STRUCTURE_DETAILED.md` | ✅ Regenerated from `git ls-files` |
| Every major folder in `APP_STRUCTURE.md` | ✅ Verified |
| Every documented path exists | ✅ Stale paths removed from docs |
| No deleted path documented as current | ✅ References updated |
| Generated/ignored folders documented as excluded | ✅ `APP_STRUCTURE.md` §4, `.gitignore` |
| Kept `scripts/**` documented or used | ✅ Regen + audit + deploy scripts only |
| Kept `docs/reports/**` has reason | ✅ See tables above |

---

## Broken reference check

Searched tracked files for deleted report/script stems. Fixed in:

- `AGENTS.md`
- `CLAUDE.md`
- `docs/ROADMAP.md`
- `docs/APP_STRUCTURE.md`
- `docs/AI_CONTEXT.md`
- `docs/reports/DESIGN_SYSTEM_INVENTORY.md`
- `docs/reports/FILE_STRUCTURE_SCAN_2026-07-03.md`
- `docs/reports/REPO_CLEANUP_NON_PROJECT_FILES_2026-07-03.md`

`CHANGELOG.md` retains historical mentions of deleted reports (journal entries — intentional).

`docs/APP_STRUCTURE_DETAILED.md` regenerated — no entries for deleted files.

---

## Verification (recorded 2026-07-03)

| Check | Result |
| :--- | :--- |
| `architecture_guard.ps1` | ✅ 0 violations, 6 warnings (LARGE_FILE + RAW_UI — pre-existing) |
| `architecture_guard.ps1 -Strict` | ✅ exit 0 |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | ✅ 0 errors |
| `flutter test` | ✅ 248/248 passed |

Web/APK build: **skipped** (docs/cleanup-only pass).

`update.ps1`: **not run** (docs-only commit; not required by project policy).

---

## Confirmations

- ✅ No production Dart behavior changed
- ✅ No app source files moved or renamed
- ✅ Actual file tree matches `APP_STRUCTURE.md` and regenerated `APP_STRUCTURE_DETAILED.md`
- ✅ Redundant intermediate docs removed; one canonical source per topic (see policy in user pass spec)
