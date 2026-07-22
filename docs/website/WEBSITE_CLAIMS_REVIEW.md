# Website Claims Review — Editorial Validation

**Pass:** 2 (editorial / v1)  
**Date:** 2026-06-24  
**Method:** Each public claim from `docs/website/*` cross-checked against `lib/`, governing docs, and `CHANGELOG.md`.

**Classification legend**

| Class | Action on v1 site |
| :--- | :--- |
| **safe public claim** | May state plainly |
| **needs softer wording** | Mention with qualifiers or secondary placement |
| **internal only** | Never on marketing site |
| **do not mention yet** | Omit from v1 |
| **needs human decision** | Block copy until owner decides |

---

## File reference audit

| Referenced path | Exists? | Note |
| :--- | :--- | :--- |
| `lib/shared/diagnostics/performance/runtime_flags.dart` | ✅ Yes | Correct anchor for kill switches (`kDesktopVoiceCommandEnabled`, etc.) |
| `lib/shared/diagnostics/performance/shell_flags.dart` | ✅ Yes | Shell bisect flags |
| `lib/core/perf_flags.dart` | ❌ No | Cited in `docs/ROADMAP.md` / `ARCHITECTURE.md` — migrated/removed June 2026 cleanup |
| `lib/core/p0u_feature_flags.dart` | ❌ No | Same — flags moved to `runtime_flags.dart` per CHANGELOG 2026-06-23 |
| `lib/core/p0u_diag.dart` | ❌ Not verified in this pass | Treat as internal if present; not for website |
| `Моё Время` as product name | ❌ Not in repo | Zero matches in codebase or l10n; **positioning option only** — not shipped brand |

**Website package:** First pass correctly used `runtime_flags.dart`. No correction required in website docs for that path.

---

## Core product claims

| Claim | Evidence | Class | v1 guidance |
| :--- | :--- | :--- | :--- |
| Instant / ~100ms UI on start/stop/edit | `UX_CONTRACT.md`, `ARCHITECTURE.md` Iron Laws, O1 shipped | **safe public claim** | OK as “feels instant”; avoid literal “100ms” in hero |
| Offline-first for records + plans/lists | `ROADMAP.md` O1 ✅, `local_sync/*` | **safe public claim** | Lead differentiator |
| Timeline day swipe | `timeline_view.dart` `TimelineSwipeWrapper` | **safe public claim** | OK |
| Plan vs Fact | `plan_vs_fact_tab.dart`, `plan_service.dart` | **safe public claim** | OK — say “basic comparison for the day” |
| Time View with now-line, 5-min snap | `UX_CONTRACT.md` § Planning Time Mode | **safe public claim** | OK |
| Time View drag & resize | Code exists; CHANGELOG many `[wip]` entries | **needs softer wording** | “Schedule blocks on a timeline” — not “precision drag-and-drop” |
| Extended day window (−3..27h) | `plan_time_visible_window.dart`, CHANGELOG `[wip]` | **needs softer wording** | Omit from v1 hero; optional FAQ |
| Unified shell (5 tabs) | `APP_STRUCTURE.md` §3.1 | **safe public claim** | OK |
| Profile timezone drives wall days | `profile_service.dart`, `DATA_MAP.md` | **safe public claim** | OK |
| Singleton timer / no overlapping primaries | `DATA_MAP.md`, `pb_hooks/records.interval_sanitize.pb.js` | **safe public claim** | FAQ only — explain honestly |
| EN + RU full UI | `l10n/langs/en.dart`, `ru.dart` | **safe public claim** | OK |
| Partial locales (DE, ES, …) | `app_locales.dart` | **needs softer wording** | “More languages in progress” if mentioned at all |
| Web app live at GitHub Pages | `DEPLOY.md`, `web/index.html` title “Life OS” | **safe public claim** | Primary CTA |

---

## Sensitive / flagged areas

### Wear OS companion

| | |
| :--- | :--- |
| **Claim in pass-1 docs** | Companion timer on watch |
| **Evidence** | `wear_timer_screen.dart`, `main.dart` `appWearHost` → `WearTimerScreen`, `loadInitialDataWearLite` |
| **Gaps** | No Play Store listing, no QA sign-off in docs, watch-only subset (no full Planning UI) |
| **Class** | **do not mention yet** on v1 |
| **v1 guidance** | Exclude from homepage, FAQ, and screenshots |

---

### AI Smart Plan / free–pro tier

| | |
| :--- | :--- |
| **Claim in pass-1 docs** | Smart Plan sheet; tier may gate AI |
| **Evidence** | `smart_plan_sheet.dart` → `parsePlanningItemsViaAiBackend`; `POST /api/ai/parse-task` in `plan_service.dart` |
| **Gaps** | `profiles.tier` in `DATA_MAP.md` but **not parsed** in `profile.dart` / `profile_service.dart` in current client; `pro_badge_*` strings in l10n **unused** in `lib/`; server-side tier enforcement not verified in repo |
| **Class** | **do not mention yet** on v1 |
| **v1 guidance** | No “AI planning” on landing. If FAQ asked: “Some advanced parsing may require account tier — check in app.” only after human decision |

---

### OAuth providers (Google / Yandex)

| | |
| :--- | :--- |
| **Evidence** | `auth_view.dart`, `AuthBridge.availableOAuthProviderNames()`, `DEPLOY.md` |
| **Class** | **needs softer wording** |
| **v1 guidance** | “Sign in with email. Google or Yandex when available on your server.” — not “Sign in with Google” as guaranteed |

---

### Biometrics

| | |
| :--- | :--- |
| **Evidence** | `auth_bridge.dart` `canUseBiometricAuth()` excludes web; `profile_view.dart` lock toggle; l10n `auth_biometric_*` |
| **Class** | **needs softer wording** |
| **v1 guidance** | “On supported phones: optional biometric unlock.” Omit from v1 hero. Web site must not imply Face ID on web |

---

### Android / iOS / desktop download CTAs

| | |
| :--- | :--- |
| **Evidence** | `ROADMAP.md` lists targets; `pubspec.yaml` platforms; **no** store URL or APK in `DEPLOY.md` |
| **Class** | **needs human decision** |
| **v1 guidance** | Single CTA: **Open web app**. Download section = placeholder or “native apps in development” — owner chooses |

---

### Time View drag/drop polish

| | |
| :--- | :--- |
| **Evidence** | 15+ CHANGELOG `[wip]` entries Jun 2026 on drop resolver, cascade, rubber scale |
| **Class** | **needs softer wording** |
| **v1 guidance** | Show **static screenshots** of scheduled blocks. Copy: “see your day on a clock” — not “drag to perfection” |

---

### Header timezone quick picker

| | |
| :--- | :--- |
| **Evidence** | `timezone_quick_picker.dart` wired in `global_app_header.dart`; CHANGELOG **2026-06-15 `[wip]`** |
| **Class** | **needs softer wording** |
| **v1 guidance** | v1: market **Profile timezone settings** only. Header quick switch: omit until owner marks shipped |

---

### Public brand name

| Option | In product today? | Class |
| :--- | :--- | :--- |
| **Life OS** | `app_title`, `web/index.html` `<title>`, auth headline in all locales | **safe** as in-app name |
| **Counter** | Repo name, GitHub Pages path `/Counter/` | **safe** as technical/deploy name |
| **Моё Время** | Not in codebase | **needs human decision** — positioning only |

**v1 guidance:** Do not auto-pick. See `POSITIONING_V1.md`.

---

## Claims to remove or soften from pass-1 copy

| Original (where) | Issue | Replacement |
| :--- | :--- | :--- |
| “AI-assisted plan parsing” in FAQ (`PUBLIC_COPY_DRAFTS.md`) | Tier/server unclear | Omit from v1 FAQ |
| “Native download links should be added…” as near-term (`PUBLIC_COPY_DRAFTS.md`) | No links exist | “Web available now” |
| Tier B “Biometrics (mobile)” as equal feature (`WEBSITE_TZ.md`) | Minor feature | v1 FAQ footnote only |
| 12 must-have screenshots (`SCREENSHOT_SHOTLIST.md`) | Too many for v1 landing | **6-shot v1 minimum** in `WEBSITE_V1_SCOPE.md` |
| “Smart add sheet” in planning inventory without AI label | Could imply AI | Clarify: **Smart Plan** uses server AI — **exclude from v1** |
| “responds before the network does” (hero option #2) | Slightly technical | OK if softened to “UI updates first, sync follows” |

---

## internal only (never v1)

- Component Lab, `is_admin`, kill switches, P0/P0U diagnostics  
- Desktop Price Reporter voice (`kDesktopVoiceCommandEnabled` default false)  
- Export scripts / `exports/*.csv`  
- PocketBase host, OAuth secrets, `pb_hooks/` filenames  
- `kPlanStreamLifecycleDiag`, perf diag defines  
- Lists pin (`plans.is_pinned` schema gap)  
- F3 auto-save, F2B category filter  

---

## needs human decision (blocking v1 copy)

1. **Primary public brand:** Life OS vs Counter vs Моё Время vs hybrid  
2. **Download CTA:** web-only vs waitlist vs APK link  
3. **AI Smart Plan:** hide completely vs mention under Pro  
4. **Wear OS:** omit (recommended) vs “works on Wear OS”  
5. **Header TZ quick picker:** ship in marketing or not  
6. **Pricing:** “free” only vs Pro waitlist  
7. **OAuth:** list providers as guaranteed or conditional  

---

## Pass-1 package verdict

| Doc | Verdict |
| :--- | :--- |
| `PRODUCT_INVENTORY.md` | Accurate; minor updates on AI/tier and v1 scope pointer |
| `FEATURE_MATRIX.md` | Accurate; use as traceability, not v1 page list |
| `WEBSITE_TZ.md` | Slightly broad; superseded for implementation by `WEBSITE_V1_SCOPE.md` |
| `WEBSITE_PAGE_STRUCTURE.md` | Good v2 map; **too large for v1** |
| `CONTENT_LIBRARY.md` | Reusable; soften Time View drag line |
| `PUBLIC_COPY_DRAFTS.md` | Good raw material; v1 copy in `HOMEPAGE_WIREFRAME_V1.md` |
| `SCREENSHOT_SHOTLIST.md` | Valid; add v1 subset |
| `INTERNAL_NOTES_NOT_FOR_SITE.md` | Correct; keep private |

**No fabricated features found.** Main risks were **scope creep** (too many pages/shots) and **AI/tier/Wear** appearing in matrix without v1 exclusion.
