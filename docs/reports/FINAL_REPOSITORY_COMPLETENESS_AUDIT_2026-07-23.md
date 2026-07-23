# Final repository completeness audit (2026-07-23)

Phase 2G — evidence-only closure of ordinary repository-structure cleanup after Phases 1–2F.

**Baseline:** `origin/main` @ `4971a011ad451473c1a86b012ceb78b0d656745f`  
**Branch:** `audit/final-repository-completeness`  
**Starting HEAD:** `4971a011ad451473c1a86b012ceb78b0d656745f`  
**Preflight:** clean working tree; `architecture_guard.ps1 -Strict` → exit 0 (0 violations, 4 RAW_UI warnings)

**Result:** **A — documentation-only closure.** No production Dart changes.

---

## 1. Baseline

| Item | Value |
| :--- | :--- |
| Expected main | `4971a011ad451473c1a86b012ceb78b0d656745f` |
| Confirmed `origin/main` / local `main` | Same SHA (fast-forward from prior local) |
| Tracked files | **739** |
| Production Dart (`lib/**/*.dart`) | **393** |
| Root `lib/*.dart` | `main.dart`, `app_shell.dart` only |
| Strict guard | 0 violations |
| LARGE_FILE (Measure-Object >1800) | **0** |

Prior structure work already closed: Pass 3–4D, hygiene audit (2026-07-21), Phases 2A–2F (time/diagnostics/voice/categories/CI guard/Stage B).

---

## 2. Audit method

1. Fetch/checkout `main`; confirm SHA; strict architecture guard; branch from that HEAD.
2. Read governing docs (`AGENTS.md`, `AGENT_NAVIGATION.md`, `ROADMAP`, `APP_STRUCTURE*`, `ARCHITECTURE`, Project Knowledge pack, prior structure reports, `CHANGELOG`, `architecture_guard.ps1`).
3. Inventory from `git ls-files` (not ignored build output):
   - production Dart line counts (Measure-Object);
   - filename heuristics (`old|backup|copy|temp|tmp|debug|diag|probe|benchmark|legacy|unused|archive`);
   - tracked binaries/images/archives;
   - scripts under `scripts/`, `installer/`, root;
   - zero-ish package-import graph for `lib/**/*.dart`;
   - layer-boundary greps (`data`→`features`, `shared`→`features` / `database_service` / `data/voice`, relative imports).
4. Classify serious candidates only; execute **nothing** unless extremely high-confidence.
5. Docs-only: report + Roadmap + Changelog; re-run strict guard + `git diff --check`.

Code, imports, CI, and runtime wiring override filename heuristics.

---

## 3. Large-file inventory

Measure-Object non-blank lines under `lib/` (same metric as `architecture_guard` LARGE_FILE):

| Threshold | Count |
| :--- | ---: |
| ≥1200 | **9** |
| ≥1800 | **0** |
| ≥2500 | **0** |

| Path | Lines | Responsibilities | Classification | Split? |
| :--- | ---: | :--- | :--- | :--- |
| `lib/features/planning/planning_page.dart` | 1794 | Planning day page + state; Time/Lists seams already extracted | **KEEP** | No — coherent page; Stage E paused |
| `lib/data/plan_service.dart` | 1775 | Brain plan coordinator (`part of`); helpers already extracted | **KEEP** | No — Brain; further splits need product scope |
| `lib/features/shared/planning_task_edit_sheet.dart` | 1719 | Plan/list edit sheet surface | **KEEP** | No — single sheet; Notes/edit out of scope |
| `lib/shared/voice/platforms/desktop/desktop_stt_helper_service.dart` | 1715 | Desktop STT helper; already uses `part` diagnostics/lifecycle | **KEEP** | No — platform adapter |
| `lib/data/records/record_crud.dart` | 1486 | Record CRUD cluster (`part of` Brain) | **KEEP** | No — Brain |
| `lib/features/voice/desktop_voice_widget.dart` | 1401 | Desktop Flutter Voice overlay UI | **KEEP** | No — voice UI path |
| `lib/features/lists/lists_view.dart` | 1339 | Lists tab | **KEEP** | No — cohesive feature screen |
| `lib/features/notes/note_editor_page.dart` | 1294 | Notes editor | **KEEP** | No — Notes editor excluded |
| `lib/data/voice/voice_command_parser.dart` | 1292 | Voice command parser | **KEEP** | No — voice parser excluded |

**SPLIT criteria not met** for any file in this phase (no clear independent seam + narrow import change + practical verification without behavior risk). Maximum implementation budget unused.

---

## 4. Zero-reference inventory

Automated scan (no `package:counter/…` import of the file path, no `part` parent, no basename hit in other Dart) returned **14** candidates. Manual verification:

| Path | Apparent refs | Real role | Classification |
| :--- | :--- | :--- | :--- |
| `lib/core/widgets/life_card.dart` | 0 production imports | Canonical V7 card foundation; Component Lab / DESIGN_SYSTEM | **KEEP** / **DEFER** (V7 migration) |
| `lib/core/widgets/confirm_dialog.dart` | 0 production call sites | Canonical `showConfirmDialog`; inventory dead-candidate for focused V7 | **KEEP** / **DEFER** (V7) |
| `lib/core/widgets/plan_card/plan_time_card_density.dart` | Re-export only | Compat forward to `plan_time_task_card/plan_card_density.dart` | **KEEP** (compat shim) |
| `lib/data/local_sync/plan_create_outbox.dart` | 0 Dart imports | One-line legacy export of `plan_mutation_outbox.dart`; documented in AGENT_NAVIGATION | **KEEP** (compat) |
| `lib/features/profile/settings/settings_page.dart` | 0 imports | Compat re-export → `app/shell/shared/settings_page.dart` | **KEEP** (compat) |
| `lib/features/lists/category_filter_tree_field.dart` | 0 callers | Phase 2D Lists ownership home; Lists still uses inline tree tiles | **DEFER** (wire or delete under Categories/Lists product scope) |
| `lib/features/settings/categories/category_recursive_browse_panel.dart` | 0 callers | Phase 2D manager browse panel; not yet adopted by `category_list_view` | **DEFER** (same) |
| `lib/features/lists/lists_inline_add.dart` | 0 callers | Hygiene watchlist — named Lists surface | **DEFER** |
| `lib/features/notes/notes_library_page.dart` | 0 callers | Hygiene watchlist — Notes library surface | **DEFER** |
| `lib/features/shared/notes_editor/notes_editor_launcher.dart` | 0 callers | Hygiene watchlist — Notes sheet stack | **DEFER** |
| `lib/features/voice/desktop_voice_command_panel.dart` | 0 callers | Hygiene watchlist — Voice UI | **DEFER** |
| `lib/shared/voice/platforms/desktop/desktop_voice_benchmark_service.dart` | Tooling/bench | Manual/bench path | **GENERATED_OR_TOOLING** |
| `lib/shared/voice/platforms/desktop/desktop_voice_window_flags.dart` | Conditional/platform | Platform flag helper | **KEEP** / **DEFER** |
| `lib/shared/voice/recognition/desktop_voice_error_classification.dart` | Shared recognition | Error classification types | **KEEP** (library surface; may be imported via related modules) |

**DELETE:** none. Zero normal imports ≠ unused when the file is design-system foundation, documented compat, bench tooling, or unfinished Phase 2D adoption.

False positives from filename heuristics: `android/.../debug/`, Flutter `Debug.xcconfig`, `diagnostics/` runtime logs, `PUBLIC_COPY_DRAFTS.md` — **FALSE_POSITIVE**.

---

## 5. Tooling and scripts

| Area | Verdict |
| :--- | :--- |
| `update.ps1` | **KEEP** — deploy |
| `scripts/manual/td.ps1` / `td` | **KEEP** — manual |
| `scripts/audit/architecture_guard.ps1` | **KEEP** — CI + local |
| `scripts/sync_locales.dart` (if present) / structure generators | **KEEP** — documented regen |
| Desktop Voice smoke/benchmark/compare scripts | **GENERATED_OR_TOOLING** — retain |
| Installer / STT helper scripts | **KEEP** — `docs/DEPLOY.md` |
| `.github/workflows/architecture-guard.yml` | **KEEP** — Phase 2E |
| Abandoned one-off extract scripts | **Already gone** (parity 2026-07-03) |

No script deleted. Builds/deploy not executed.

---

## 6. Tracked artifact audit

| Finding | Classification |
| :--- | :--- |
| `build/`, `.dart_tool/` tracked | **None** |
| `installer/windows/stt_helper_build/counter_stt_helper.exe` (~33 MB) | **KEEP** — intentional installer/bench payload |
| Platform launcher icons / web favicons | **KEEP** — branding |
| `test/fixtures/desktop_voice_wav/*` WAV + diag txt | **KEEP** — STT fixtures/tests |
| `test/fixtures/.../real_helper_latency_latest.json` | **KEEP** — canonical bench artifact |
| Timestamped latency JSON | **Already removed** (hygiene 2026-07-21); `.gitignore` covers regenerations |
| Accidental APK/ZIP/DB/log in git | **None found** |

`.gitignore` not expanded (no new accidental artifact class).

---

## 7. Architecture drift

| Check | Result |
| :--- | :--- |
| `lib/data` → `package:counter/features/` | **0** |
| `lib/shared` → `features/` | **0** |
| `lib/shared` → `database_service.dart` | **0** |
| `lib/shared` → `data/voice/` | **0** |
| `lib/core` → `features/` | **0** |
| Relative `../` imports in `lib/` | **0** |
| Tracked `Archive/` | **0** (guard `deletedMustStayGone`) |
| Root barrels beyond `main` / `app_shell` | **0** |
| Strict guard violations | **0** |

No new guard rules added (no new prohibited pattern requiring a precise rule).

`lib/app_shell.dart` retained per Phase 2F (used by `main.dart`).

---

## 8. Classification table

Serious candidates only:

| Candidate | Classification | Action | Risk if forced |
| :--- | :--- | :--- | :--- |
| 9 large Dart files (≥1200) | **KEEP** | None | High if split by line count |
| `lib/app_shell.dart` | **KEEP** | None (Phase 2F) | Import churn |
| `plan_create_outbox.dart` compat | **KEEP** | None | Low; still documented |
| Profile/settings + plan_card density re-exports | **KEEP** | None | Low |
| `LifeCard` / `confirm_dialog` | **KEEP** / **DEFER** | V7 adoption | Feature/design |
| Phase 2D unreferenced wrappers (`category_filter_tree_field`, `category_recursive_browse_panel`) | **DEFER** | Wire or approve delete separately | Product UX |
| Hygiene watchlist Notes/Lists/Voice orphans | **DEFER** | Product/UI decision | Feature surface |
| Voice bench/diag scripts + fixtures | **GENERATED_OR_TOOLING** | Retain | Breaks STT QA |
| `counter_stt_helper.exe` | **KEEP** | Retain | Breaks installer |
| Filename `debug`/`diag`/`archive` hits | **FALSE_POSITIVE** | None | — |
| Stage E further splits | **DEFER** | Never by line count alone | Architecture churn |
| Notifications / alarm scheduler / autosave / visual redesign | **DEFER** | **Not repository cleanup** | Feature work |

---

## 9. Changes executed

| Kind | Count |
| :--- | ---: |
| Production Dart deleted | **0** |
| Production Dart moved/split | **0** |
| Imports changed | **0** |
| Scripts deleted | **0** |
| Guard rules changed | **0** |
| `.gitignore` changed | **0** |

Documentation only:

- This report.
- `docs/ROADMAP.md` — ordinary repository cleanup formally closed.
- `CHANGELOG.md` — Phase 2G entry.

---

## 10. Items intentionally kept

- Root `lib/app_shell.dart` compatibility re-export.
- All large planning/Brain/voice/notes files above (cohesive or excluded domains).
- Design-system foundations with zero production callers (`LifeCard`, `confirm_dialog`).
- Legacy one-line outbox / settings / plan-card density re-exports.
- Installer STT helper binary and Voice benchmark fixtures/scripts.
- Entire current `lib/l10n/` layout (Stage B).
- Architecture guard allowlists and `Archive` deleted-path regression.

---

## 11. Deferred separate scopes

These are **not** ordinary repository-structure cleanup:

1. **V7 / design system:** migrate feature cards to `LifeCard`/`AppTaskCard`; wire or retire `showConfirmDialog`.
2. **Phase 2D adoption:** wire `CategoryFilterTreeField` / `CategoryRecursiveBrowsePanel` or explicitly delete unused wrappers.
3. **Hygiene watchlist UI orphans:** Notes library/launcher, Lists inline add, Voice command panel — product decision.
4. **Optional:** migrate `main.dart` off root `app_shell` re-export (explicit choice only).
5. **Stage E:** further large-file splits only with a real ownership seam (never line count alone).
6. **Product features:** notifications, alarm scheduler, autosave, visual redesign — out of cleanup.
7. **Test debt:** 3 known runtime test failures noted in Roadmap (not structure).

---

## 12. Verification

| Check | Result |
| :--- | :--- |
| Preflight `architecture_guard.ps1 -Strict` | Exit 0 |
| Post-edit `architecture_guard.ps1 -Strict` | Exit 0 (expected) |
| `git diff --check origin/main...HEAD` | Exit 0 (expected) |
| `flutter analyze` | **Skipped** (docs-only) |
| Tests | **None** (docs-only) |

---

## 13. Final repository-cleanup conclusion

**Ordinary repository-structure cleanup is formally complete**, with explicitly deferred feature / design / adoption work listed in §11.

Evidence:

- Strict architecture boundaries are green.
- LARGE_FILE count is 0.
- No tracked build junk or accidental release artifacts remain beyond intentional installer/fixture binaries.
- Stage B and hygiene audits already removed obsolete barrels, extract scripts, and timestamped bench outputs.
- Remaining “orphans” are either intentional foundations, compat shims, tooling, or unfinished product wiring — not high-confidence structure deletes.
- No justified production split or deletion met Phase 2G confidence bar.

Further structure work requires a **separately approved** product or design scope — not another generic cleanup pass.
