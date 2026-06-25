# Life OS / Counter — Screenshot Shotlist

**Audit date:** 2026-06-24  
**Rules:** Use synthetic/demo data only. No real client names (especially Price Reporter). No admin Component Lab. Prefer dark theme for consistency with main tabs.

---

## Must-have shots

### 1. Timeline — running activity

| Field | Detail |
| :--- | :--- |
| **Screen** | Timeline tab, List mode |
| **App state** | Today selected; one record `status: running` with elapsed indicator; 2–3 stopped records same day; varied categories |
| **Demonstrates** | Core time tracking, running state, category colors |
| **Platform** | Mobile + desktop/web |
| **Data setup** | Demo account; categories Work, Health, Learning; running title e.g. “Deep work — website spec” |
| **Priority** | must-have |

### 2. Timeline — Stats tree

| Field | Detail |
| :--- | :--- |
| **Screen** | Timeline → Stats segment |
| **App state** | Stats tree partially expanded; non-zero durations |
| **Demonstrates** | Category breakdown for the day |
| **Platform** | Mobile |
| **Data setup** | Same day as shot 1 with 4+ stopped records |
| **Priority** | must-have |

### 3. Plan vs Fact

| Field | Detail |
| :--- | :--- |
| **Screen** | Timeline → Stats → Plan vs Fact tab |
| **App state** | At least one planned task and one matching/mismatching record |
| **Demonstrates** | Differentiator feature |
| **Platform** | Mobile + desktop |
| **Data setup** | Plan “Write documentation” + record “Write documentation” partial overlap |
| **Priority** | must-have |

### 4. Planning — list mode

| Field | Detail |
| :--- | :--- |
| **Screen** | Plans tab, list view (not Time View) |
| **App state** | 5–7 cards; mix done/undone; one with repeat icon; tags visible |
| **Demonstrates** | Daily plan cards, recurring, tags |
| **Platform** | Mobile |
| **Data setup** | Include `rrule` weekly task |
| **Priority** | must-have |

### 5. Planning — Time View

| Field | Detail |
| :--- | :--- |
| **Screen** | Plans tab, Time View mode |
| **App state** | 3–5 blocks at different heights; now-line visible; mix micro/compact/medium |
| **Demonstrates** | Scheduled day, density tiers, now-line |
| **Platform** | Mobile + desktop (wide) |
| **Data setup** | Blocks 9:00–12:00, 12:30–13:00, 14:00–16:00; current time between two blocks |
| **Priority** | must-have |

### 6. Calendar — month

| Field | Detail |
| :--- | :--- |
| **Screen** | Calendar tab, month mode |
| **App state** | Current month; dots/indicators on days with plans |
| **Demonstrates** | Month-at-a-glance |
| **Platform** | Mobile |
| **Data setup** | Plans on 5+ days in month |
| **Priority** | must-have |

### 7. Lists / backlog

| Field | Detail |
| :--- | :--- |
| **Screen** | Lists tab |
| **App state** | Filter chips visible; list-tag on cards; one done item |
| **Demonstrates** | Inbox, list-domain tags |
| **Platform** | Mobile |
| **Data setup** | 6+ backlog items, 2 list tags |
| **Priority** | must-have |

### 8. Categories — nested grid

| Field | Detail |
| :--- | :--- |
| **Screen** | More → Categories |
| **App state** | Parent + child categories; colors/icons; depth stripe visible |
| **Demonstrates** | Nested taxonomy |
| **Platform** | Mobile |
| **Data setup** | 3-level tree minimum |
| **Priority** | must-have |

### 9. Tags — manager or settings

| Field | Detail |
| :--- | :--- |
| **Screen** | Profile → Tag manager (plan domain) |
| **App state** | List of tags with colors; or tag display mode settings |
| **Demonstrates** | Tag customization |
| **Platform** | Mobile |
| **Data setup** | 8+ tags |
| **Priority** | must-have |

### 10. Voice input sheet

| Field | Detail |
| :--- | :--- |
| **Screen** | Voice sheet open over Timeline or Plans |
| **App state** | Listening or transcript filled; bilingual toggle visible if EN/RU locale |
| **Demonstrates** | Voice capture |
| **Platform** | Mobile (required); desktop optional |
| **Data setup** | Partial transcript “Team standup at ten” |
| **Priority** | must-have |

### 11. Offline / pending sync banner

| Field | Detail |
| :--- | :--- |
| **Screen** | Any main tab with banner |
| **App state** | “Offline · N pending” or “N pending sync” |
| **Demonstrates** | Offline-first UX |
| **Platform** | Mobile |
| **Data setup** | Airplane mode + 1–2 queued actions; **staging only** |
| **Priority** | must-have |

### 12. Shell navigation

| Field | Detail |
| :--- | :--- |
| **Screen** | Any tab showing bottom nav (mobile) or side nav (desktop) |
| **App state** | Timeline selected; `GlobalAppHeader` with date + timezone label |
| **Demonstrates** | App structure |
| **Platform** | Both |
| **Data setup** | Default |
| **Priority** | must-have |

---

## Nice-to-have shots

### 13. Calendar — week view

| Field | Week mode with selected day column |
| **Priority** | nice-to-have |

### 14. Profile — timezone settings

| Field | `timezone_settings.dart` screen or header quick picker open |
| **Priority** | nice-to-have |
| **Note** | Quick picker is CHANGELOG `[wip]` — confirm before hero use |

### 15. Planning — play button / start from plan

| Field | Plan card with play visible; optional transition to running timeline |
| **Priority** | nice-to-have |

### 16. Record / plan edit sheet

| Field | `ActivityDetailSheet` with checklist + tags + omni datetime |
| **Priority** | nice-to-have |

### 17. Biometric lock toggle

| Field | Profile security section |
| **Priority** | nice-to-have |
| **Platform** | Mobile only |

### 18. Auth screen

| Field | Login with OAuth buttons (no credentials) |
| **Priority** | nice-to-have |

### 19. Recurring plan edit

| Field | Repeat tab in plan edit sheet |
| **Priority** | nice-to-have |

### 20. Lists — export snackbar

| Field | After “Export as text” success snack |
| **Priority** | nice-to-have |

### 21. Wear OS

| Field | `WearTimerScreen` running + category |
| **Priority** | nice-to-have |
| **Note** | needs human review before public use |

### 22. Desktop wide — Time View + side nav

| Field | `shell_adaptive.dart` breakpoint |
| **Priority** | nice-to-have |

### 23. Light theme variant

| Field | One hero screen in light mode for accessibility story |
| **Priority** | nice-to-have |

---

## Do not capture for public site

| Item | Reason |
| :--- | :--- |
| Component Lab | Admin-only |
| Desktop Price Reporter voice panel | Kill switch off; niche |
| Debug perf overlays | Internal |
| More menu admin flag text | Internal |
| Real Price Reporter / client export data | Privacy |
| PocketBase Admin UI | Infrastructure |
| `lists_pin_item_todo` UI | Not shipped |

---

## Production notes

- **Resolution:** Export at 2×; web hero ~1440×900 crop from mobile 390×844 or desktop 1280×800.
- **Locale:** Capture EN set primary; duplicate RU for 3–4 hero screens if bilingual site.
- **Theme:** Dark default; `GlobalAppHeader` readable per F2A.
- **Anonymize:** Fake names, generic project titles.
- **Consistency:** Same demo account across all shots for color/category continuity.

---

## v1 minimum (6 shots — implement site only after these exist)

Per `WEBSITE_V1_SCOPE.md`:

1. Timeline running (#1)  
2. Planning list (#4)  
3. Time View + now-line (#5)  
4. Plan vs Fact (#3)  
5. Shell / nav (#12)  
6. Lists (#7) **or** Calendar month (#6)

All other shots in this file are **v2**.

---

## Shot → page mapping

| Shot | Primary page |
| :--- | :--- |
| 1, 2 | Time tracking |
| 3 | Stats |
| 4, 5, 15 | Planning |
| 6, 13 | Calendar |
| 7, 20 | Lists |
| 8 | Categories (features + tour) |
| 9 | Tags |
| 10 | Voice |
| 11 | Offline |
| 12 | Home, Features overview |
| 17, 18 | Security |
