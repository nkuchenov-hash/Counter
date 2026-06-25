# Life OS / Counter — Website Page Structure

**Audit date:** 2026-06-24  
**Purpose:** Full sitemap and per-page brief — **v2 expansion reference**.  
**v1 implementation scope:** `WEBSITE_V1_SCOPE.md` (5 pages max, single Features page).

---

## Sitemap overview

```
/                          Home
/features                  Features overview
/features/time-tracking    Timeline
/features/planning         Planning + Time View
/features/lists            Lists / backlog
/features/calendar         Calendar
/features/stats            Stats & Plan vs Fact
/features/voice            Voice input
/features/offline          Offline-first sync
/features/security         Account & security
/tour                      Product tour / screenshots
/faq                       FAQ
/download                  Web app & apps
/changelog                 Release notes (optional)
```

---

## Home `/`

| Item | Content |
| :--- | :--- |
| **Purpose** | Position product; drive web app CTA |
| **Target question** | “What is Life OS and why should I try it?” |
| **Sections** | Hero · 3–4 value pillars · Feature strip (Timeline, Planning, Plan vs Fact, Offline) · Screenshot carousel · Social proof placeholder · CTA band |
| **Key copy** | Fast local UI · Plan + track + compare · Works offline · Timezone-aware |
| **Screenshots** | Hero: Timeline with running activity OR Time View with now-line |
| **CTA** | “Open web app” → `https://nkuchenov-hash.github.io/Counter/` |
| **Must NOT show** | Component Lab, admin UI, Price Reporter voice, PocketBase admin, real VPS URL, export CSVs |

---

## Features overview `/features`

| Item | Content |
| :--- | :--- |
| **Purpose** | Scannable map of the whole product |
| **Target question** | “What can this app do?” |
| **Sections** | Grid of feature cards linking to detail pages · “Built as one shell” diagram · Platforms strip |
| **Key copy** | Five tabs: Timeline, Plans, Calendar, Lists, More (Categories & Profile) |
| **Screenshots** | Shell with bottom nav (mobile) or side nav (desktop) |
| **CTA** | Open web app · Explore tour |
| **Must NOT show** | Internal perf flags, kill switches, tier internals |

---

## Time tracking `/features/time-tracking`

| Item | Content |
| :--- | :--- |
| **Purpose** | Explain timeline / time tracking |
| **Target question** | “How do I track what I’m doing?” |
| **Sections** | Start/stop · Day swipe · Categories on records · Edit sheet · Stats toggle intro |
| **Key copy** | Instant start · Running state · Traveler-safe days |
| **Screenshots** | Timeline list with one running card; edit sheet |
| **CTA** | Try it in the browser |
| **Must NOT show** | Promise of unlimited overlapping primary timers |

---

## Planning & Time View `/features/planning`

| Item | Content |
| :--- | :--- |
| **Purpose** | Plans as cards + scheduled blocks |
| **Target question** | “How do I plan my day and schedule time?” |
| **Sections** | List mode · Play to track · Time View · Recurring · Tags/categories · Reminders |
| **Key copy** | Cards not rows · Time View with now-line · 5-minute scheduling |
| **Screenshots** | Planning list; Time View with 3–4 blocks; recurring icon |
| **CTA** | Open web app |
| **Must NOT show** | AI Smart Plan as headline unless tier approved; perfect DnD claims |

---

## Lists / backlog `/features/lists`

| Item | Content |
| :--- | :--- |
| **Purpose** | Inbox separate from calendar |
| **Target question** | “Where do I put ideas I’m not scheduling yet?” |
| **Sections** | List items · List tags · Filters · Export as text · Done behavior |
| **Key copy** | Inbox without a play button — start from Plans |
| **Screenshots** | Lists with tags and filters |
| **CTA** | Open web app |
| **Must NOT show** | Pin/favorite items (not shipped) |

---

## Calendar `/features/calendar`

| Item | Content |
| :--- | :--- |
| **Purpose** | Month/week browsing |
| **Target question** | “Can I see my month at a glance?” |
| **Sections** | Month/week · Day detail · Jump to edit/start |
| **Key copy** | Same plans as elsewhere — one data model |
| **Screenshots** | Month view with indicators; week view |
| **CTA** | Open web app |
| **Must NOT show** | Adjacent-month overflow as “unique feature” |

---

## Stats & Plan vs Fact `/features/stats`

| Item | Content |
| :--- | :--- |
| **Purpose** | Accountability layer |
| **Target question** | “Did I do what I planned?” |
| **Sections** | Stats tree · Plan vs Fact tab · Timezone day scope |
| **Key copy** | Planned vs actual for the same wall day |
| **Screenshots** | Stats tree expanded; Plan vs Fact comparison |
| **CTA** | Open web app |
| **Must NOT show** | Enterprise BI / payroll export |

---

## Voice input `/features/voice`

| Item | Content |
| :--- | :--- |
| **Purpose** | Hands-free capture |
| **Target question** | “Can I speak tasks and time entries?” |
| **Sections** | Mic FAB · Tab routing · Bilingual STT · Edit before submit |
| **Key copy** | Voice becomes a record, plan, or list item |
| **Screenshots** | Voice sheet listening state |
| **CTA** | Open web app |
| **Must NOT show** | Desktop Price Reporter panel |

---

## Offline-first `/features/offline`

| Item | Content |
| :--- | :--- |
| **Purpose** | Reliability story |
| **Target question** | “Does it work without internet?” |
| **Sections** | Optimistic UI · Queue · Banner states · Tap to retry · What syncs when back |
| **Key copy** | Tap first — sync catches up |
| **Screenshots** | “Offline · N pending” banner (staged) |
| **CTA** | Open web app |
| **Must NOT show** | SharedPreferences / outbox implementation details |

---

## Security & account `/features/security`

| Item | Content |
| :--- | :--- |
| **Purpose** | Trust and access |
| **Target question** | “How do I sign in and keep my data safe?” |
| **Sections** | Email/password · OAuth (Google/Yandex) · Password reset · Biometric lock (mobile) · Per-user data |
| **Key copy** | Your account, your rows — multi-tenant isolation |
| **Screenshots** | Auth screen (no real email); Profile security toggle |
| **CTA** | Create account |
| **Must NOT show** | OAuth client secrets, PB admin URL, SMTP config |

---

## Product tour `/tour`

| Item | Content |
| :--- | :--- |
| **Purpose** | Visual walkthrough |
| **Target question** | “Show me the app.” |
| **Sections** | Ordered gallery with captions per `SCREENSHOT_SHOTLIST.md` |
| **Key copy** | Short captions tied to user jobs |
| **Screenshots** | Full shotlist |
| **CTA** | Open web app |
| **Must NOT show** | Admin lab, debug overlays |

---

## FAQ `/faq`

| Item | Content |
| :--- | :--- |
| **Purpose** | Reduce support friction |
| **Target question** | Common objections |
| **Sections** | Product · Offline · Timezone · Platforms · Privacy · Pricing |
| **Key copy** | See `PUBLIC_COPY_DRAFTS.md` |
| **Screenshots** | Optional inline small crops |
| **CTA** | Open web app · Contact placeholder |
| **Must NOT show** | Internal roadmap jargon (P0U, O1) |

---

## Download `/download`

| Item | Content |
| :--- | :--- |
| **Purpose** | Access points |
| **Target question** | “How do I get it?” |
| **Sections** | Web app (live) · Android · iOS · Desktop · Wear OS (conditional) |
| **Key copy** | Web works now; native links when verified |
| **Screenshots** | Device mockups optional |
| **CTA** | Primary: web URL |
| **Must NOT show** | Broken store links; APK without signing policy |

---

## Changelog `/changelog` (optional)

| Item | Content |
| :--- | :--- |
| **Purpose** | Trust for returning visitors |
| **Target question** | “What’s new?” |
| **Sections** | Curated user-facing releases (not dev `[wip]` spam) |
| **Key copy** | Pull from public-safe CHANGELOG entries only |
| **Screenshots** | None required |
| **CTA** | Open web app |
| **Must NOT show** | Internal kill-switch entries, Price Reporter scripts |

---

## Global chrome (all pages)

- **Header:** Logo · Features · FAQ · Download · CTA button “Open app”
- **Footer:** EN/RU language switch · Privacy placeholder · GitHub link (optional) · No backend host
- **SEO title pattern:** `{Page} — Life OS` or `{Page} — Counter`

---

## Navigation priority (mobile menu)

1. Open app (button)
2. Features
3. Tour
4. FAQ
5. Download
