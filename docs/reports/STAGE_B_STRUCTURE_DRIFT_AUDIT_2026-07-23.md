# Stage B structure drift audit (2026-07-23)

Phase 2F — evidence-only closure of Roadmap Stage B
(“Safe renames/moves: root barrels, Archive/, duplicate l10n”).

**Baseline:** `origin/main` @ `3ffad6e0b7aa6895dd5d40fd414455c25b7b4cfc`
**Branch:** `cleanup/stage-b-structure-drift`
**Preflight:** `architecture_guard.ps1 -Strict` → exit 0 (0 violations)

---

## 1. Baseline and scope

Audited only Stage B themes:

- root `lib/*.dart` entry / compatibility barrels;
- tracked `Archive/` (and similar names);
- localization tree / duplicate sources;
- docs that still claim Stage B is pending.

**Out of scope:** design system, feature ownership, Voice/Categories/Time/Diagnostics/Shell/Brain, PocketBase, platform folders, UI/runtime/string/schema changes.

---

## 2. Root Dart files

Tracked files matching `^lib/[^/]+\.dart$`:

| Path | Role | Imports of this path | Action |
| :--- | :--- | :--- | :--- |
| `lib/main.dart` | App entry | N/A (entry) | **KEEP** |
| `lib/app_shell.dart` | Compatibility re-export → `package:counter/app/shell/app_shell.dart` | `lib/main.dart` only (`package:counter/app_shell.dart`) | **KEEP** |

Evidence:

- Guard allowlist is exactly `main.dart`, `app_shell.dart`.
- Canonical shell lives at `lib/app/shell/app_shell.dart`.
- Root re-export is a one-line `export`; actively used by `main.dart`.
- Migrating that single import would not remove a harmful barrel; prompt default is keep stable re-exports when used.

No other root Dart files exist. Former root barrels (`lib/models.dart`, `lib/database_service.dart`, `lib/auth_*.dart`) are **not** tracked and remain on the guard deleted-path list.

---

## 3. Archive status

| Check | Result |
| :--- | :--- |
| Tracked paths matching `(?i)Archive` / `archive/` | **None** |
| Filesystem `Archive/` / `archive/` at repo root | **Absent** |
| Guard `deletedMustStayGone` includes `'Archive'` | **Yes** (must stay) |

Classification: **ALREADY_GONE** / **STALE_ROADMAP**.

Historical mentions in `CHANGELOG.md` / old reports remain as history (not deleted). Roadmap V6 note that still names `Archive/tool/…` is stale inventory text, not a live tracked path.

---

## 4. Localization paths

| Path | Role |
| :--- | :--- |
| `lib/l10n/dictionary.dart` | Runtime catalog + `t()`; layers partial locales onto EN |
| `lib/l10n/langs/en.dart` | Canonical EN (`kEnL10n`) — SSOT |
| `lib/l10n/langs/ru.dart` | Canonical RU (`kRuL10n`) |
| `lib/l10n/langs/{ar,de,es,fr,it,ko,zh}.dart` | Partial maps layered on English |
| `lib/l10n/app_locales.dart` | Supported locale metadata |
| `lib/l10n/category_db_display.dart` | Category DB name display helper |
| `scripts/sync_locales.dart` | Tooling: append missing keys from EN SSOT |

Also verified:

- No `l10n.yaml`, no tracked `*.arb`, no Flutter gen-l10n config in `pubspec.yaml`.
- `flutter_localizations` is the Flutter SDK package only — not a second string catalog.
- No second EN/RU map outside `langs/en.dart` / `langs/ru.dart`.

Classification: **KEEP** (single intentional system). Partial locale files are not exact duplicates. No safe DELETE/MOVE without a separately approved l10n rewrite.

---

## 5. Classification table

| Item | Tracked? | Refs / purpose | Canonical owner exists? | Action | Risk |
| :--- | :---: | :--- | :---: | :--- | :--- |
| `lib/main.dart` | Yes | App entry | Yes | **KEEP** | None |
| `lib/app_shell.dart` | Yes | Re-export; used by `main.dart` | Yes (`app/shell/`) | **KEEP** | Low if deleted; keep per policy |
| Former root barrels (`models`, `database_service`, `auth_*`) | No | Guard deleted-path list | Yes under `data/` / `features/auth/` | **ALREADY_GONE** | — |
| `Archive/` directory | No | Must stay gone (guard) | N/A | **ALREADY_GONE** / **STALE_ROADMAP** | — |
| `lib/l10n/langs/en.dart` + `ru.dart` | Yes | SSOT strings | Self | **KEEP** | — |
| Other `lib/l10n/langs/*` | Yes | Partial overlays | Layered via `dictionary.dart` | **KEEP** | — |
| Duplicate ARB / gen-l10n trees | No | N/A | N/A | **ALREADY_GONE** | — |
| Roadmap Stage B “⏸ after D” | Doc | Claimed pending renames | Work already done or KEEP | **STALE_ROADMAP** | Doc-only |
| `AGENT_NAVIGATION.md` “Extra at lib/ root: auth_*” | Doc | False — files gone | Auth under `features/auth/` | **STALE_ROADMAP** | Doc-only |
| Mass-rename all `app_shell` imports | N/A | 1 caller only | Canonical path exists | **NEEDS_SEPARATE_SCOPE** if ever desired | Unnecessary churn |
| Flutter gen-l10n / ARB migration | N/A | Would rewrite l10n system | Current system works | **NEEDS_SEPARATE_SCOPE** | High |

---

## 6. Changes executed

**Production Dart:** none (0 files deleted, 0 moved, 0 imports changed).

**Documentation / report:**

- This report.
- `docs/ROADMAP.md` — Stage B marked audited / superseded.
- `AGENT_NAVIGATION.md` — remove false “auth at lib root” drift row; clarify other drift rows that already match guard.
- `CHANGELOG.md` — Phase 2F entry.

Architecture guard script: **unchanged** (allowlist and `Archive` regression list preserved).

---

## 7. Items intentionally kept

- `lib/app_shell.dart` compatibility re-export (used by `main.dart`).
- Entire current `lib/l10n/` layout and `scripts/sync_locales.dart`.
- Guard deleted-path entry for `Archive`.
- Historical changelog/report mentions of `Archive/` and `CLAUDE.md`.

---

## 8. Separate future scopes (not Phase 2F)

- Optional one-line migrate of `main.dart` → canonical `app/shell/app_shell.dart` and delete root re-export (explicit product choice only).
- Flutter gen-l10n / ARB migration.
- Any further large-file splits (Roadmap Stage E — already paused; never by line count alone).

---

## 9. Verification

| Check | Result |
| :--- | :--- |
| Preflight `architecture_guard.ps1 -Strict` | Exit 0 |
| Post-edit `architecture_guard.ps1 -Strict` | (run after docs) |
| `git diff --check origin/main...HEAD` | (run after commit) |
| `flutter analyze` | **Skipped** (docs-only) |
| Tests | **None** (docs-only) |

**Stage B status:** **audited and superseded** — listed drift is already gone or intentionally retained; no remaining Stage B production work.
