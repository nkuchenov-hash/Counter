# Paths first-class architecture + repository audit — 2026-08-17

## Scope

This pass implements the first safe architecture boundary for Paths and audits the surrounding Life OS repository for structural debt that can be removed without risking user data or runtime behavior.

The pass intentionally does **not** migrate or delete existing Path data, change PocketBase schema, replace Planner semantics, or add direct model-provider access to Flutter.

## Findings

### P0 — Paths was structurally owned by the shell

Before this pass:

- `ProjectPathsV3Page` lived inside `lib/app/shell/shared/shell_more_menu.dart`;
- desktop Paths used navigation index `6` as a special case and pushed a second `DesktopShellFrame`;
- mobile opened Paths as a pushed route from More;
- the main shell `pages` list had no Paths destination;
- opening Paths could run legacy migration/bootstrap, Path governance and Planner generation side effects;
- the current Path itself was stored as a completed/undated `plans` row marked by `LIFEOS_PATH::V2`.

This made Paths visually and behaviorally detached from the main application and prevented a safe Draft → Review → Publish → Planner AI workflow.

### P0 — page-open side effects

The legacy page initialization called project bootstrap / upgrade / governance / planning routines. Merely viewing Paths could therefore mutate planning state.

**New contract:** opening the first-class Paths page is a read operation. Migration, repair, canonicalization, publish and Planner generation must be explicit services/actions, never implicit page-open behavior.

### P1 — hard-coded project governance

`lib/app/shell/shared/shell_path_governance.dart` currently includes specific project profiles/aliases and required-topic policy for projects such as KADR, GOLOS, Igropoisk, Life OS and others.

This remains compatibility debt. It must not be copied into the new Paths domain. Project-specific knowledge belongs in stored Path / Project Memory data, not in Dart governance code.

### P1 — duplicate active legacy roots

Existing plan-backed storage can contain multiple rows marked as active roots for the same category/project. The new repository detects and reports this state, but deliberately does not delete or retire rows during reads.

Canonical repair must be a separate idempotent migration with data-preservation coverage.

### Cleanup — completed one-off workflow

`.github/workflows/temp-fix-category-default-time.yml` was a temporary self-patching workflow for category default time precedence. The target scheduling logic is already present in `lib/data/plans/plan_time_cascade_helpers.dart`, so retaining a workflow that can patch and push `main` no longer has product value. The workflow is removed in this pass.

## Implemented architecture

### `lib/data/paths/path_repository.dart`

Introduces the first Paths domain boundary while preserving current storage:

- `PathRepository` is a compatibility adapter over current plan-backed `LIFEOS_PATH::V2` rows;
- feature code no longer needs to know how marker-backed rows are discovered;
- active roots are grouped per project/category;
- duplicate active roots are surfaced, not mutated during reads;
- legacy rows are parsed into explicit `ProjectPathSnapshot`, `PathStageSnapshot` and `PathActionSnapshot` structures;
- `PathStatus` establishes the domain vocabulary `draft`, `reviewed`, `active`, `archived` for the next storage phase;
- generic structure validation checks goal/stages/completion criteria/action output/action duration without project-specific profiles;
- writes continue through existing `DatabaseService.updatePlanningTask` so current PocketBase, ownership, optimistic and compatibility behavior remains the source of truth.

### `lib/features/paths/paths_page.dart`

Introduces a dedicated Paths feature page:

- first-class responsive Paths list/detail UI;
- read-only load on screen open;
- no bootstrap, migration, project-specific upgrade, Planner generation, or automatic canonicalization;
- goal/stage/action state edits go through `PathRepository`;
- user edits are reflected locally first and rolled back if the existing save path rejects them;
- duplicate legacy roots are visibly reported instead of silently deleted;
- validation is generic and project-agnostic.

### `lib/app/shell/app_shell.dart`

Paths is now index `6` in the main shell content stack:

- the main `pages` list contains `PathsPage`;
- desktop navigation selects the real Paths destination rather than pushing another shell;
- the More entry routes to the same shell destination;
- opening Paths is navigation only;
- the general voice FAB is hidden on Paths because the current voice action belongs to Timeline/Planning/List workflows, not Path editing.

## Compatibility preserved

The following are intentionally retained until the migration phase has explicit coverage:

- `LIFEOS_PATH::V2` interpretation;
- old Path rows and retired markers;
- existing Planner/Path bridge behavior outside the new read-only page;
- existing user Path data;
- current PocketBase `plans` schema;
- legacy governance/bootstrap source files, although new Paths code does not depend on their project-specific policy.

## Not completed in this pass

Issue #93 remains open. The following are subsequent architecture phases, not safe cleanup deletions:

1. move legacy migration/bootstrap into an idempotent `data/paths` migration service;
2. move Planner bridge/governance out of shell and make it consume only published/active Paths;
3. add durable draft/reviewed/active/archived + version/revision storage;
4. store generic project constraints, assumptions, dependencies, risks, decisions and open questions;
5. move hard-coded personal project knowledge into Path / Project Memory records;
6. add provider-neutral AI Path proposal contracts behind `/api/ai/...`;
7. expose only whitelisted Path/Planner application tools to AI, with validation, permissions, audit and undo;
8. migrate live legacy roots idempotently;
9. only after migration verification, remove legacy V1/V2/V3/KADR page/bootstrap/marker implementation from shell files.

## Documentation impact

Relevant governing contracts should reflect the new boundary:

- `APP_STRUCTURE.md`: Paths feature/data ownership and shell destination;
- `ARCHITECTURE.md`: Path domain + active-only Planner contract + no page-open mutation;
- `UX_CONTRACT.md`: Paths navigation/read/open behavior and local-first explicit edits;
- `AGENTS.md` / agent navigation: where future Paths work starts;
- `ROADMAP.md`: issue #93 phased migration state;
- `CHANGELOG.md`: shipped branch changes.

No schema contract changed, so `DATA_MAP.md` and `POCKETBASE_MANIFEST.md` must not be rewritten to pretend a new Path collection already exists. No deploy contract changed, so `DEPLOY.md` does not require a behavioral change.

## Verification required before merge

Minimum proportional checks:

1. strict architecture guard;
2. `git diff --check`;
3. `flutter analyze --no-fatal-infos --no-fatal-warnings`;
4. focused Paths tests / smoke checks;
5. web build because shared shell/navigation changed;
6. Android build/smoke because shared Flutter shell/UI changed.

Performance kill switch remains in force: if first-frame startup, tab navigation, Timeline/Planning swipe, optimistic UI, or memory behavior regresses, disable/revert the risky Paths integration before continuing feature work.
