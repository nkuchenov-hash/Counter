# LIFE OS

LIFE OS is a Flutter application for planning, time tracking, project execution, routines, lists, and personal operating data. The app uses PocketBase as its primary backend and follows an offline-first, optimistic-UI architecture.

## Repository entry points

- `lib/main.dart` — application bootstrap and auth/session entry.
- `lib/app/shell/app_shell.dart` — canonical responsive app shell.
- `lib/features/` — user-facing feature modules.
- `lib/data/` — PocketBase I/O, caches, offline queues, and domain logic.
- `lib/shared/` — reusable cross-feature contracts and infrastructure.
- `docs/APP_STRUCTURE.md` — canonical physical ownership map.
- `docs/ARCHITECTURE.md` — architecture laws and runtime contracts.
- `docs/ROADMAP.md` — current execution priorities.
- `AGENT_NAVIGATION.md` — navigation map for AI/code agents.

The repository also contains separately scoped project material such as `igropoisk/`. Do not treat another project subtree as LIFE OS cleanup material unless that project is explicitly in scope.

## Development checks

Structural changes must pass:

```powershell
pwsh -NoProfile -NonInteractive -File ./scripts/audit/architecture_guard.ps1 -Strict
```

Flutter changes should also pass formatting, static analysis, and the relevant tests before merge.

## Architecture rules

1. Shell owns navigation and cross-feature wiring, not feature business logic.
2. UI belongs under `lib/features/`.
3. PocketBase/network/domain state belongs under `lib/data/`.
4. Shared reusable infrastructure belongs under `lib/shared/` or `lib/core/` according to `docs/APP_STRUCTURE.md`.
5. User actions remain optimistic/offline-first; network round trips must not block immediate UI feedback.
6. New functionality extends the canonical subsystem instead of creating parallel implementations.

## Paths

Paths is a first-class LIFE OS product area for turning project goals into executable stages and actions. The current compatibility format still reads existing plan-backed Path records while the domain is migrated toward explicit draft/reviewed/active/versioned Paths. Only an active/published Path should feed Planner automation.

See GitHub issue #93 and the canonical docs for the current migration scope.
