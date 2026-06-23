# Repository Structure Lockdown — Final Release Pass (2026-06-23)

**Pass type:** Final release structure cleanup — delete/migrate non-release files, rewrite `APP_STRUCTURE`, strict architecture guard, Russian structure guide.  
**Product behavior:** Unchanged (import moves, shell injection, l10n assembler only).

---

## 1. Baseline → final

| Metric | Baseline | Final |
|--------|----------|-------|
| **SHA** | `7a47f88` | uncommitted working tree (post-cleanup) |
| **architecture_guard** | 6 known-debt violations | **0 violations** (warning mode) |
| **architecture_guard -Strict** | N/A (debt bucket) | **exit 0** |
| **flutter analyze** | 0 errors | **0 errors** |
| **flutter test** | 57 pass / 3 fail | **57 pass / 3 fail** (unchanged runtime harness) |
| **flutter build web** | Green | **Green** |

### Pre-existing test failures (not introduced by structure pass)

| Test | Notes |
|------|-------|
| `test/perf_shell_date_settle_test.dart` | Rebuild fan-out assertion |
| `test/widget_test.dart` | `pumpAndSettle` timeout |
| Related perf harness | Same category |

---

## 2. Deleted

| Path | Reason |
|------|--------|
| `Archive/` (30 tracked files) | Historical backups/tools — not release structure |
| `lib/data/base_database.dart` | Unused legacy stub |
| `lib/core/subscription/app_tier.dart` | Unused paywall stub |
| `lib/database_service.dart` | Root barrel → `lib/data/database_service.dart` |
| `lib/models.dart` | Root barrel → `lib/data/models.dart` |
| `lib/auth_screen.dart` | Root re-export → `features/auth/auth_screen.dart` |
| `lib/auth_service.dart` | → `features/auth/oauth_session.dart` |
| All `lib/core/p0u_*`, `perf_diag`, `perf_flags`, `plan_dup_trace` (old paths) | Renamed to permanent modules |

---

## 3. Moved / renamed (permanent names)

| From | To |
|------|-----|
| `features/planning/smart_input_parser.dart` | `data/smart_input_parser.dart` |
| `features/profile/wall_clock.dart` | `core/time/wall_clock.dart` |
| `features/shared/tag_contrast.dart` | `core/tag_contrast.dart` |
| `features/shared/chip_component.dart` | `core/widgets/chip_component.dart` |
| `core/p0u_*.dart`, `perf_*.dart`, `plan_dup_trace.dart` | `core/diagnostics/*`, `core/performance/*` |
| `data/warm_day_window.dart`, `p0t_render_snapshot.dart`, `rendered_day_body_cache.dart` | `data/cache/*` |
| `core/widgets/eager_day_content_strip.dart`, `mounted_day_window.dart` | `day_content_strip.dart`, `day_window.dart` |

---

## 4. New permanent modules

| File | Role |
|------|------|
| `core/time/app_clock.dart` | Header clock injection |
| `core/plan_category_lookup.dart` | Plan card category injection |
| `core/widgets/tag_display_mode_scope.dart` | Tag chip display mode |
| `core/web_redirect.dart` | Web OAuth redirect URI |
| `core/time/category_timezone_options.dart` | Category TZ options (Brain-safe) |
| `core/time/plan_time_labels.dart` | Plan wall-time label helpers |
| `docs/APP_STRUCTURE_EXPLAINED_RU.md` | Nick-facing Russian guide |

---

## 5. Import boundaries (enforced)

| Rule | Status |
|------|--------|
| `lib/data` ↛ `lib/features` | **Clean** |
| `lib/core` ↛ `lib/features` | **Clean** |
| `lib/core` ↛ `database_service.dart` | **Clean** (models.dart OK for DNA) |
| Root `lib/*.dart` | **Only** `main.dart`, `app_shell.dart` |

---

## 6. l10n single source

- **Canonical EN/RU:** `lib/l10n/langs/en.dart` (`kEnL10n`), `lib/l10n/langs/ru.dart` (`kRuL10n`)
- **Assembler:** `lib/l10n/dictionary.dart` imports langs; no inline duplicate maps
- **Sync script:** `scripts/sync_locales.dart` still uses `en.dart` as SSOT for regional langs

---

## 7. Verification commands (all run)

```powershell
.\scripts\audit\architecture_guard.ps1
.\scripts\audit\architecture_guard.ps1 -Strict
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build web --release --base-href="/Counter/" --no-tree-shake-icons --no-wasm-dry-run
```

`update.ps1` — run after commit if deploying web (production Dart changed).

---

## 8. Governing docs updated this pass

- `docs/APP_STRUCTURE.md`
- `docs/APP_STRUCTURE_EXPLAINED_RU.md`
- `CLAUDE.md`
- `docs/ROADMAP.md`
- `CHANGELOG.md`
- This report

Not changed: `DATA_MAP.md`, `POCKETBASE_MANIFEST.md`, `UX_CONTRACT.md`, `DESIGN_SYSTEM.md` (no schema/behavior/UI contract changes).
