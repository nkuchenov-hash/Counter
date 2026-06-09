# AI context — pointer

**Canonical roadmap:** [`docs/ROADMAP.md`](ROADMAP.md) — phases, bugs, execution order, and future work. Do not duplicate roadmap content in this file.

---

## Repo root (June 2026)

`C:\Users\nkuch\Development\Apps\counter` — git root, `pubspec.yaml`, `.github/`, `lib/`.

The nested `counter/counter/` layout was flattened in June 2026. The old outer Flutter skeleton was backed up to `C:\Users\nkuch\Development\Apps\counter_WRAPPER_BACKUP` (sibling folder, not in git).

---

## Governing docs

| File | Purpose |
| :--- | :--- |
| `docs/ROADMAP.md` | **Current plan** — read first for structural work |
| `docs/ARCHITECTURE.md` | Iron Laws, data flow |
| `docs/APP_STRUCTURE.md` | Directory map |
| `docs/DATA_MAP.md` | Field names, business IDs |
| `docs/POCKETBASE_MANIFEST.md` | PB collections, relations |
| `docs/DEPLOY.md` | Website update / GitHub Pages |
| `CLAUDE.md` | AI navigation map, symbols, drift notes |
| `docs/reports/` | Archived audit and one-off reports |
| `docs/archive/` | Archived prompts and legacy planning notes |

---

## Deploy website

From repo root:

```powershell
.\update.ps1
```

Implementation: `scripts/manual/td.ps1` (`flutter analyze --no-fatal-infos --no-fatal-warnings`, then `flutter build web` with `--no-tree-shake-icons`). Push to `main` triggers GitHub Actions → `gh-pages`.

---

## Note on history

A full copy of the May 2026 roadmap previously lived in this file and duplicated `docs/ROADMAP.md`. That duplicate was removed 2026-06-09. Audit source material remains in `docs/reports/AUDIT_NOTES.md`.
