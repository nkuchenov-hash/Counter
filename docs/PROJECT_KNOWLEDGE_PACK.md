# Project Knowledge pack (upload checklist)

**Not architecture law.** This file lists which repo docs to upload into Project Knowledge (max 25). Current governing docs live in git; use this as the upload manifest only.

**Pack count:** 14 documents (≤25 limit)

---

## Upload these 14 files

| # | Path | Topic |
| :---: | :--- | :--- |
| 1 | `AGENTS.md` | Codex / agent routing |
| 2 | `CLAUDE.md` | AI navigation map, symbols |
| 3 | `CHANGELOG.md` | Shipped history |
| 4 | `docs/APP_STRUCTURE.md` | Concise structure map |
| 5 | `docs/APP_STRUCTURE_DETAILED.md` | Bilingual per-file guide |
| 6 | `docs/ARCHITECTURE.md` | Iron Laws, data flow |
| 7 | `docs/UX_CONTRACT.md` | Interaction behavior |
| 8 | `docs/DATA_MAP.md` | Field names, business IDs |
| 9 | `docs/POCKETBASE_MANIFEST.md` | PB collections, relations |
| 10 | `docs/DESIGN_SYSTEM.md` | Design system contract |
| 11 | `docs/reports/DESIGN_SYSTEM_INVENTORY.md` | Component inventory / V7 debt |
| 12 | `docs/DEPLOY.md` | Web deploy, auth admin, Windows installer |
| 13 | `docs/ROADMAP.md` | Current priority / status |
| 14 | `docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md` | Structure parity proof, removed-docs log |

---

## Repo-only (do not upload)

| Path | Why excluded |
| :--- | :--- |
| `README.md` | GitHub intro; duplicates pack pointers |
| `docs/PROJECT_KNOWLEDGE_PACK.md` | This checklist only |
| `docs/website/*` | Marketing / website copy — not app architecture law |
| `.github/copilot-instructions.md` | GitHub Copilot scope, not Life OS law |

---

## Removed 2026-07-03 (merged or superseded)

| Removed | Merge target / reason |
| :--- | :--- |
| `docs/AI_CONTEXT.md` | Pointer + laws already in `ARCHITECTURE.md`, `UX_CONTRACT.md`, `CLAUDE.md`, `DEPLOY.md` |
| `docs/APP_STRUCTURE_EXPLAINED_RU.md` | Covered by `APP_STRUCTURE_DETAILED.md` (bilingual) |
| `docs/DESKTOP_WINDOWS_ARTIFACT.md` | Merged into `docs/DEPLOY.md` § Windows desktop release |
| `docs/WINDOWS_INSTALLER.md` | Merged into `docs/DEPLOY.md` § Windows desktop release |
| `docs/reports/AUDIT_NOTES.md` | April 2026 audit; decisions captured in `ROADMAP.md` + `CHANGELOG.md` |
| `docs/reports/FILE_STRUCTURE_SCAN_2026-07-03.md` | Superseded by final parity report |
| `docs/reports/REPO_CLEANUP_NON_PROJECT_FILES_2026-07-03.md` | Superseded by final parity report |

Earlier parity pass already removed intermediate Pass 3–4D reports, lockdown audits, blueprints, and `docs/archive/*` scratch — see final parity report § Files deleted.

---

## Confirmation

- One source of truth per topic in the 14-doc pack
- No duplicate Russian structure guide
- No external sync / re-upload instructions
- Architecture decomposition complete; pack is docs-only hygiene
