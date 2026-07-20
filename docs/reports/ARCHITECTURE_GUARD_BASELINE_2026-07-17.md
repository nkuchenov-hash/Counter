# Architecture guard baseline — 2026-07-17

Baseline commit: `c8a78c42e7d744b9a369d47ac6a7e6cf6c7b6317` (`origin/main`).

## Baseline

`.\scripts\audit\architecture_guard.ps1 -Strict` exited 1 with **63 violations** and 8 informational warnings:

- 1 `FORBIDDEN_IMPORT`;
- 62 `UNDOCUMENTED_IN_APP_STRUCTURE`;
- warnings: 4 `LARGE_FILE` and 4 `RAW_UI`.

The 63 diagnostics below are each listed exactly once. Classification totals at baseline are:

| Classification | Count |
| :--- | ---: |
| A. Real architecture violation | 5 |
| B. Legitimate file missing from structure documentation | 58 |
| C. Stale guard rule | 0 |
| D. Explicit legacy exception | 0 |
| E. False positive or parser defect | 0 |
| **Total** | **63** |

## Progress

| Pass | Commit / change | Strict count | Remaining A / B |
| :--- | :--- | ---: | :--- |
| Baseline | `c8a78c42` | 63 | 5 / 58 |
| First cluster (plan-alarm docs) | `2079e072` | 61 | 5 / 56 |
| Core STT cloud boundary | this pass | **60** | **4 / 56** |

## Guard inputs and configuration

The guard consumes only `docs/APP_STRUCTURE.md` as an external manifest. It does **not** consume `docs/APP_STRUCTURE_DETAILED.md`, the structure generator, a baseline count, or an external allowlist.

Its other configuration is inline in `scripts/audit/architecture_guard.ps1`:

- APP_STRUCTURE wording patterns;
- forbidden import rules;
- root `lib/*.dart` allowlist (`main.dart`, `app_shell.dart`);
- experiment/diagnostic filename pattern;
- deleted-file regression list;
- tracked build-artifact patterns;
- large-file and raw-UI warning definitions.

The generated detailed guide records SHA `205c6b8` from 2026-07-06. All 62 undocumented files were introduced from 2026-07-06 through 2026-07-17 and are absent from both that generated snapshot and the concise manifest consumed by the guard.

`CLAUDE.md` is not present. `AGENT_NAVIGATION.md` explicitly records that it replaced the legacy filename on 2026-07-03.

## Violation groups

### 1. Core service imports the Brain — **RESOLVED**

- **Diagnostic:** `FORBIDDEN_IMPORT (core->database_service) lib/core/services/desktop_stt_cloud_service.dart`
- **Count:** 1 (resolved)
- **Affected path:** `lib/core/services/desktop_stt_cloud_service.dart`
- **Why invalid:** `lib/core/` is Foundation and must not import `lib/data/database_service.dart`. The cloud STT adapter directly crossed that boundary.
- **Classification:** **A. Real architecture violation**
- **Resolution:** Brain owns PocketBase readiness, auth token, base URL, route, Authorization, HTTP POST, JSON payload, and 25s timeout in `lib/data/desktop_stt_cloud_backend.dart`. Core keeps WAV read, result mapping, pipeline markers, and `DesktopSttCloudEngine` via injected `DesktopSttCloudBackendHooks` wired from `main.dart` (AppClock-style). Core no longer imports `database_service.dart` or `pb_config.dart`.
- **Risk:** Medium (behavior-preserving transport split; covered by injection unit test + existing STT quality tests).

### 2. Test-only Notes capture code lives under production `lib/`

- **Diagnostic:** `UNDOCUMENTED_IN_APP_STRUCTURE`
- **Count:** 4
- **Affected paths:**
  - `lib/features/notes/debug/capture_notes_glm_main.dart`
  - `lib/features/notes/debug/notes_glm_library_parity_fixture.dart`
  - `lib/features/notes/debug/notes_glm_parity_fixture.dart`
  - `lib/features/notes/debug/notes_production_library_capture.dart`
- **Why invalid:** The files identify themselves as one-off/test-only visual capture fixtures and are imported by tests or a manual capture script. Test tooling has no production Feature UI ownership merely because it renders production widgets.
- **Classification:** **A. Real architecture violation**
- **Proposed resolution:** Move fixtures to `test/` and the capture entrypoint to test/manual tooling, then update the capture script and test imports. Do not document them as production feature modules.
- **Risk:** Medium. Runtime behavior is unaffected, but capture paths and visual tests must move together.

### 3. Desktop voice modules added after the structure snapshot

- **Diagnostic:** `UNDOCUMENTED_IN_APP_STRUCTURE`
- **Count:** 32
- **Affected paths:**
  - `lib/core/services/desktop_main_window.dart`
  - `lib/core/services/desktop_stt_benchmark_harness.dart`
  - `lib/core/services/desktop_stt_cloud_service.dart`
  - `lib/core/services/desktop_stt_engine.dart`
  - `lib/core/services/desktop_stt_orchestrator.dart`
  - `lib/core/services/desktop_stt_quality_evaluation.dart`
  - `lib/core/services/desktop_voice_audio_presentation.dart`
  - `lib/core/services/desktop_voice_capture_endpoint.dart`
  - `lib/core/services/desktop_voice_capture_ready_policy.dart`
  - `lib/core/services/desktop_voice_command_stt_policy.dart`
  - `lib/core/services/desktop_voice_confirmation_timer.dart`
  - `lib/core/services/desktop_voice_contamination_gate.dart`
  - `lib/core/services/desktop_voice_correction_flow.dart`
  - `lib/core/services/desktop_voice_delayed_transcribe.dart`
  - `lib/core/services/desktop_voice_dev_tools.dart`
  - `lib/core/services/desktop_voice_error_classification.dart`
  - `lib/core/services/desktop_voice_glossary.dart`
  - `lib/core/services/desktop_voice_installed_identity.dart`
  - `lib/core/services/desktop_voice_install_smoke_policy.dart`
  - `lib/core/services/desktop_voice_last_attempt_store.dart`
  - `lib/core/services/desktop_voice_overlay_constants.dart`
  - `lib/core/services/desktop_voice_overlay_transparency.dart`
  - `lib/core/services/desktop_voice_ready_cue.dart`
  - `lib/core/services/desktop_voice_real_helper_latency_benchmark.dart`
  - `lib/core/services/desktop_voice_recognition_postprocess.dart`
  - `lib/core/services/desktop_voice_session.dart`
  - `lib/core/services/desktop_voice_stt_processing.dart`
  - `lib/core/services/desktop_voice_transcript_merge.dart`
  - `lib/core/services/desktop_voice_useful_candidate_evaluator.dart`
  - `lib/core/services/desktop_voice_wav_stt_benchmark.dart`
  - `lib/core/services/desktop_voice_windows_audio_diagnostics.dart`
  - `lib/features/shared/desktop_voice_correction_sheet.dart`
- **Why invalid:** The guard requires every `lib/**/*.dart` file to appear in `APP_STRUCTURE.md`; these intentional desktop voice modules were added after the 2026-07-06 structure snapshot.
- **Classification:** **B. Legitimate file missing from structure documentation**
- **Proposed resolution:** Add exact entries grouped by desktop voice responsibility and regenerate the detailed guide. Keep benchmark/dev modules explicit rather than using a wildcard. Cloud import boundary is now fixed; documentation may proceed.
- **Risk:** Medium. Documentation-only once paths are accepted.

### 4. Production Notes modules added after the structure snapshot

- **Diagnostic:** `UNDOCUMENTED_IN_APP_STRUCTURE`
- **Count:** 19
- **Affected paths:**
  - `lib/core/widgets/notes/notes.dart`
  - `lib/core/widgets/notes/notes_context_row.dart`
  - `lib/core/widgets/notes/notes_editor_surface.dart`
  - `lib/core/widgets/notes/notes_markdown.dart`
  - `lib/core/widgets/notes/notes_save_status.dart`
  - `lib/core/widgets/notes/notes_toolbar.dart`
  - `lib/core/widgets/notes/note_preview_card.dart`
  - `lib/data/models/note_document.dart`
  - `lib/data/plans/notes_brain_helpers.dart`
  - `lib/features/notes/drawing_canvas_page.dart`
  - `lib/features/notes/notes_glm_surface.dart`
  - `lib/features/notes/notes_library_page.dart`
  - `lib/features/notes/notes_visual_tokens.dart`
  - `lib/features/notes/note_editor_page.dart`
  - `lib/features/notes/widgets/notes_library_body.dart`
  - `lib/features/notes/widgets/notes_library_production_shell.dart`
  - `lib/features/notes/widgets/note_card.dart`
  - `lib/features/shared/notes_editor/notes_editor_launcher.dart`
  - `lib/features/shared/notes_editor/notes_editor_sheet.dart`
- **Why invalid:** The model, Brain helper, canonical note widgets, feature screens, and shared launch surfaces have valid owners but post-date the canonical structure snapshot.
- **Classification:** **B. Legitimate file missing from structure documentation**
- **Proposed resolution:** Add exact model/Brain/Core/Feature/shared entries and regenerate the detailed guide in one Notes documentation pass. Keep the four test-only capture files out of this valid production group.
- **Risk:** Medium. Documentation-only, but the owner boundaries across four layers require careful descriptions.

### 5. Other valid post-snapshot modules

- **Diagnostic:** `UNDOCUMENTED_IN_APP_STRUCTURE`
- **Count:** 5
- **Affected paths:**
  - `lib/core/widgets/radial_menu_viewport.dart`
  - `lib/data/voice_domain_resolver.dart`
  - `lib/features/categories/create_category_from_picker.dart`
  - `lib/features/shared/edit_sheet/record_edit_save_policy.dart`
  - `lib/shell/shell_bottom_navigation.dart`
- **Why invalid:** Each file has a narrow owner matching the existing layer map, but its exact filename is absent from `APP_STRUCTURE.md`.
- **Classification:** **B. Legitimate file missing from structure documentation**
- **Proposed resolution:** Add exact entries in small responsibility-based documentation clusters; do not add broad folder exclusions.
- **Risk:** Low.

### 6. Selected first cluster: plan reminder scheduling — **RESOLVED**

- **Diagnostic:** `UNDOCUMENTED_IN_APP_STRUCTURE`
- **Count:** 2 (resolved)
- **Affected paths:**
  - `lib/data/plans/plan_alarm_helpers.dart`
  - `lib/services/plan_alarm_schedule.dart`
- **Why invalid:** Both files were added on 2026-07-17 after the structure snapshot. The Brain helper owns hydrated-cache reconciliation; the service file owns UI-free deterministic OS schedule specifications and policy.
- **Classification:** **B. Legitimate file missing from structure documentation**
- **Resolution:** Exact entries added to `APP_STRUCTURE.md` in the first cluster pass.
- **Risk:** Low. Documentation-only, one root cause, no runtime or schema behavior change.

## First-cluster result

The selected plan-reminder cluster removes exactly 2 diagnostics:

- baseline: **63**;
- selected cluster: **2**;
- expected and final remaining count: **61**.

No guard rule, severity, wildcard, or baseline-count suppression is changed.

## Core STT cloud boundary result

The Core → Brain forbidden import is removed without allowlisting:

- previous remaining: **61**;
- this cluster: **1**;
- expected and final remaining count: **60**.

New production file documented: `lib/data/desktop_stt_cloud_backend.dart`.

## Remaining work

Ordered first by architecture risk, then dependency, then expected effort:

| Order | Remaining cluster | Class | Count | Dependency / removal condition | Expected effort |
| ---: | :--- | :---: | ---: | :--- | :--- |
| 1 | Test-only Notes capture code under `lib/features/` | A | 4 | Move fixtures/entrypoint and update visual test + capture script paths | Small–medium |
| 2 | Desktop voice structure documentation | B | 32 | Cloud import boundary resolved; document exact modules | Medium |
| 3 | Production Notes structure documentation | B | 19 | Keep test-only files from order 1 out of the production manifest | Medium |
| 4 | Other valid post-snapshot modules | B | 5 | Split into narrow owner-based documentation updates | Small |
| 5 | Regenerate `APP_STRUCTURE_DETAILED.md` | B follow-up | 0 direct diagnostics | Run the canonical deterministic generator after accepted path classifications | Medium review |

After this pass, remaining classification totals are **A=4, B=56, C=0, D=0, E=0** (60 diagnostics).

## Source documents inspected

- `AGENTS.md`
- `AGENT_NAVIGATION.md` (replacement for absent `CLAUDE.md`)
- `docs/ARCHITECTURE.md`
- `docs/APP_STRUCTURE.md`
- complete generated `docs/APP_STRUCTURE_DETAILED.md`
- `docs/UX_CONTRACT.md`
- `docs/reports/DESIGN_SYSTEM_INVENTORY.md`
- `docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`
- `docs/DATA_MAP.md`
- `docs/POCKETBASE_MANIFEST.md`
- `docs/ROADMAP.md`
- complete `CHANGELOG.md`
- complete `scripts/audit/architecture_guard.ps1`
