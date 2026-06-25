# Life OS / Counter — Website Technical Brief (ТЗ)

**Document type:** Technical specification / content brief for public marketing website  
**Product name options:** Life OS (internal), Counter (repo/deploy name)  
**Audit date:** 2026-06-24 (pass 1) · **v1 scope:** see `WEBSITE_V1_SCOPE.md` (pass 2, 2026-06-24)  
**Scope:** Documentation only — no website implementation in this repo yet.

---

## 1. Project goal

Build a **public marketing website** that accurately represents Life OS / Counter as a **personal Life OS**: fast time tracking, planning, lists, calendar, and plan-vs-fact — with offline-first behavior and timezone-aware scheduling.

The site must **not** overpromise WIP features, expose infrastructure secrets, or market developer-only tools.

---

## 2. Target audiences

| Audience | Primary message |
| :--- | :--- |
| **Solo knowledge workers / freelancers** | Track time honestly; plan the day visually; close the loop with stats |
| **Bilingual EN/RU users** | Full Russian and English UI in the app |
| **Travelers / multi-timezone users** | Profile timezone drives timeline and planning — not device clock |
| **Mobile + web users** | Use in browser today; native apps where available |
| **Not primary (yet)** | Enterprise teams, billing agencies (except internal Price Reporter workflow) |

---

## 3. Product positioning (draft — human picks in `POSITIONING_V1.md`)

**One-liner (EN):**  
Life OS is a fast, offline-first personal system for planning your day, tracking time on real cards, and seeing what you planned versus what you actually did.

**One-liner (RU):**  
Life OS — быстрая офлайн-система для планирования дня, учёта времени на «живых» карточках и сравнения плана с фактом.

**Differentiators (verified in code/docs):**

1. **Optimistic / instant UI** — actions reflect locally in ~100ms; sync is background (O1 shipped).
2. **Unified shell** — Timeline, Plans, Calendar, Lists, Categories in one app.
3. **Time View** — plans as scheduled blocks with now-line and timezone projection.
4. **Plan vs Fact** — built-in comparison for the selected day.
5. **Offline-first** — queue mutations; global sync banner; tap to retry.
6. **Timezone-aware** — profile offset for wall-clock days across Timeline, Planning, Stats.
7. **Voice capture** — mic FAB routes to timeline, plan, or list by tab.
8. **Real cards** — categories, tags, checklists, rich notes on tasks and records.

**Do not claim:**

- Unlimited parallel primary timers (singleton / server sanitize).
- Full Google Calendar replacement.
- Team collaboration / shared workspaces (single-user model).
- Free unlimited AI parsing (tier gate — needs product decision).
- List item pinning (schema not shipped).
- Desktop Price Reporter voice (kill switch off).
- PocketBase/VPS host details or OAuth secrets.

---

## 4. Primary CTA strategy

| CTA | URL / action | Priority |
| :--- | :--- | :--- |
| **Open web app** | `https://nkuchenov-hash.github.io/Counter/` | Primary |
| **Create account** | Same — auth inside app | Primary |
| **Download Android APK** | TBD — **needs human review** | Secondary / waitlist |
| **iOS / desktop** | TBD — mention “available on” only if store links exist | Tertiary |

---

## 5. Site requirements

### 5.1 Content

- Pull feature copy from `CONTENT_LIBRARY.md` and `PUBLIC_COPY_DRAFTS.md`.
- Map pages per `WEBSITE_PAGE_STRUCTURE.md`.
- Use `SCREENSHOT_SHOTLIST.md` for visual production.
- Keep `INTERNAL_NOTES_NOT_FOR_SITE.md` out of CMS/public repo.

### 5.2 Languages

- Website: **English primary**, **Russian secondary** for key pages (home, features, FAQ).
- Partial app locales (DE, ES, …) — do not list as “fully supported” on site.

### 5.3 Tone

- Clear, product-focused, confident but precise.
- Avoid generic SaaS (“supercharge productivity,” “AI-powered everything”).
- Acknowledge personal / single-user scope honestly.

### 5.4 Legal / privacy (brief pointers — not legal advice)

- Account data stored via self-hosted backend (describe as “secure account sync” without host).
- OAuth optional (Google, Yandex) when enabled on server.
- No marketing of real user data; screenshots must use demo accounts / synthetic data.

### 5.5 Technical stack (website itself — proposal only)

Not implemented yet. Suggestions for implementer:

- Static site (Astro, Next static, or plain HTML) on same GitHub Pages org OR separate subdomain.
- Separate from Flutter `/Counter/` app path to avoid base-href collision.
- Lightweight analytics optional; no PocketBase calls from marketing site.

---

## 6. Feature tiers for messaging

### Tier A — Hero / above the fold

- Timeline time tracking (instant start/stop)
- Planning + Time View
- Plan vs Fact
- Offline-first
- Web app link

### Tier B — Features overview body

- Lists/backlog, Calendar, Categories, Tags, Voice, Timezone, Stats tree, Recurring plans, Reminders, Biometrics (mobile)

### Tier C — Mention with care

- Wear OS (after QA)
- AI Smart Plan (after tier policy)
- Header timezone quick picker (if marked shipped)
- Time View drag polish (as “actively improving” only if needed)

### Tier D — Exclude from public site

- Component Lab, admin flags, P0 diagnostics, kill switches
- Desktop Price Reporter voice
- Export scripts, pb_hooks paths, VPS URLs
- WIP pin items, F3 auto-save, F2B filter

---

## 7. Screenshot & media requirements

See `SCREENSHOT_SHOTLIST.md`. Minimum set: 8–10 must-have shots (Timeline running, Planning list, Time View, Calendar, Lists, Plan vs Fact, Categories, Tags, Voice sheet, Offline banner).

Use **synthetic demo data** — no real client names from Price Reporter exports.

---

## 8. Success criteria for website v1

- [ ] Every claimed feature maps to a row in `FEATURE_MATRIX.md` with status public-ready.
- [ ] WIP items labeled or omitted.
- [ ] Primary CTA opens live web app.
- [ ] EN + RU for home and FAQ minimum.
- [ ] No secrets, IPs, or hook filenames in public HTML.
- [ ] FAQ addresses offline, timezone, auth, and “is it free?” honestly.

---

## 9. Open questions for product owner

1. **Public name:** Life OS vs Counter vs both?
2. **Android APK / Play Store:** public link or waitlist?
3. **Pro tier / AI:** market or hide?
4. **Wear OS:** ship on website or hold?
5. **Header timezone quick picker:** treat as shipped for marketing?
6. **Pricing page:** free only today, or Pro waitlist?

---

## 10. Related docs in this package

| File | Role |
| :--- | :--- |
| `PRODUCT_INVENTORY.md` | Capability deep dive |
| `FEATURE_MATRIX.md` | Traceability table |
| `WEBSITE_PAGE_STRUCTURE.md` | Sitemap and page briefs |
| `CONTENT_LIBRARY.md` | Reusable copy blocks |
| `PUBLIC_COPY_DRAFTS.md` | Hero/FAQ drafts EN+RU |
| `SCREENSHOT_SHOTLIST.md` | Capture checklist |
| `INTERNAL_NOTES_NOT_FOR_SITE.md` | Debt, risks, exclusions |
| `WEBSITE_CLAIMS_REVIEW.md` | Pass-2 claim validation |
| `WEBSITE_V1_SCOPE.md` | **Implementation scope for v1** |
| `POSITIONING_V1.md` | Brand options A/B/C |
| `HOMEPAGE_WIREFRAME_V1.md` | v1 homepage copy structure |
| `WEBSITE_IMPLEMENTATION_OPTIONS.md` | Static site tech recommendation |
