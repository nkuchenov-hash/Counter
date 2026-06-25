# Website v1 Scope — Focused Landing Site

**Date:** 2026-06-24  
**Principle:** One convincing landing experience, not a product encyclopedia.  
**Supersedes for implementation:** page list in `WEBSITE_PAGE_STRUCTURE.md` (keep that doc as v2 reference).

---

## v1 goal

Ship a **static marketing site** (5 pages max) that:

1. Explains what the product is in &lt;30 seconds  
2. Shows **6 curated screenshots**  
3. Drives **one primary CTA** — open the live web app  
4. Answers **6–8 FAQ** items honestly  
5. Does **not** break the Flutter app at `https://nkuchenov-hash.github.io/Counter/`

---

## Pages included in v1

| Page | Route (suggested) | Purpose |
| :--- | :--- | :--- |
| **Home / landing** | `/` or `/index.html` | Hero, promise, feature strips, FAQ teaser, CTA |
| **Features** | `/features` | Single scroll — all v1 features on one page |
| **Tour** | `/tour` | Screenshot gallery with captions (6 images) |
| **FAQ** | `/faq` | Support + trust (offline, timezone, auth, platforms, cost) |
| **Get started** | `/app` or external link | Redirect or button to `/Counter/` web app |

**Total: 4–5 pages.** Home may embed FAQ accordion to avoid a click for casual visitors.

---

## Pages deferred (v2+)

| Page | Reason |
| :--- | :--- |
| Per-feature URLs (`/features/time-tracking`, …) | Split when SEO needs it |
| `/features/security` standalone | Fold into FAQ for v1 |
| `/features/offline` standalone | Section on Home + FAQ |
| `/features/voice` standalone | Small block on Home only |
| `/changelog` | Optional; no user-facing curated log yet |
| `/roadmap` | Internal velocity track — do not publish |
| `/download` with store badges | No verified store/APK links |
| Pricing / Pro | No public tier story |
| Blog | Out of scope |
| Russian duplicate site tree | v1: EN page + RU summary section on Home/FAQ (not full mirror) |

---

## Features — v1 messaging tiers

### Show strongly (hero + above fold)

| Feature | Copy angle |
| :--- | :--- |
| Timeline time tracking | Start/stop; running state; honest day log |
| Planning (list mode) | Cards; play → track |
| Time View | Day on a clock; now-line — **screenshot only, soft drag claims** |
| Plan vs Fact | Planned vs tracked same day |
| Offline-first | UI first; sync banner; tap retry |
| Web app CTA | Live today, no install |

### Show softly (Features page / lower home)

| Feature | Copy angle |
| :--- | :--- |
| Lists / backlog | Inbox without calendar |
| Calendar | Month/week browse |
| Stats tree | Where time went by category |
| Categories & tags | Structure and filter |
| Profile timezone | Traveler-friendly wall clock |
| Voice mic FAB | Speak a task or entry |
| Recurring plans | Repeating habits |
| Plan reminders | Local notifications |
| Rich notes & checklists | On cards — **note: save required (no auto-save)** |

### Excluded from v1 (do not show)

| Feature | Reason |
| :--- | :--- |
| Wear OS | Unverified distribution/QA |
| AI Smart Plan | Server/tier story unclear; UI is power-user |
| Desktop Price Reporter voice | Kill switch off; niche |
| Component Lab | Admin only |
| List pin | Not shipped |
| Pro tier / pricing | No client tier UI; human decision |
| Header TZ quick picker | CHANGELOG `[wip]` |
| Attachments | Out of scope |
| Native app store badges | No links |

### Mention only in FAQ if asked

| Topic | FAQ-style answer |
| :--- | :--- |
| Biometrics | Supported on some mobile devices, not web |
| OAuth | Google/Yandex when configured — email always works |
| Overlapping timers | One primary timeline at a time by design |
| Partial locales | EN + RU complete; others partial |

---

## Screenshots required before implementation

**v1 minimum (6)** — capture before building HTML:

| # | Shot | From shotlist ID |
| :--- | :--- | :--- |
| 1 | Timeline with running activity | #1 |
| 2 | Planning list with cards | #4 |
| 3 | Time View with blocks + now-line | #5 |
| 4 | Plan vs Fact | #3 |
| 5 | Shell / navigation context | #12 |
| 6 | One of: Lists **or** Calendar | #7 or #6 |

**Defer to v2:** Stats tree alone, Tags manager, Voice sheet, Offline banner staging, Auth screen, Wear, Categories tree.

**Rules:** Synthetic demo data; dark theme; no Price Reporter clients; no admin UI.

---

## Brand & CTA decisions still blocking polish

| Decision | Blocks | Default if unresolved |
| :--- | :--- | :--- |
| Public brand name | Logo text, `<title>`, hero | Use **Life OS** in UI copy; “Counter” only in URL/footer |
| RU site depth | Full RU homepage vs section | EN primary + RU hero paragraph on Home |
| Download secondary CTA | Footer buttons | Omit; web only |
| “Free” statement | FAQ | “Free to use with account” — no Pro details |
| Analytics | Privacy copy | None in v1 unless owner adds |

---

## v1 success checklist

- [ ] Owner picks brand option (`POSITIONING_V1.md`)  
- [ ] 6 screenshots captured  
- [ ] Home wireframe copy approved (`HOMEPAGE_WIREFRAME_V1.md`)  
- [ ] Implementation path chosen (`WEBSITE_IMPLEMENTATION_OPTIONS.md`)  
- [ ] Marketing host does not conflict with `/Counter/`  
- [ ] No claims from “excluded” table appear on site  
- [ ] FAQ includes offline + timezone + web-only download  

---

## Relationship to pass-1 docs

| Pass-1 doc | v1 role |
| :--- | :--- |
| `PRODUCT_INVENTORY.md` | Source of truth for what exists |
| `FEATURE_MATRIX.md` | Audit trail — filter by v1 tiers above |
| `WEBSITE_PAGE_STRUCTURE.md` | v2 expansion map |
| `CONTENT_LIBRARY.md` | Pull blocks for Features page |
| `INTERNAL_NOTES_NOT_FOR_SITE.md` | Reviewer-only |
