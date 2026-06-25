# Positioning Options v1 — Brand & Message

**Date:** 2026-06-24  
**Status:** **Human decision required** — do not auto-select in implementation.

**Evidence baseline**

- In-app / web title today: **Life OS** (`l10n` `app_title`, `web/index.html`)  
- Repo & URL: **Counter** (`github.io/Counter/`)  
- **Моё Время:** not present in codebase — proposed Russian-market name only

---

## Option A — “Life OS”

**Frame:** Personal operating system for time, plans, and reality check.

| Field | EN |
| :--- | :--- |
| **One-line positioning** | Life OS is your personal system to plan the day, track time on real cards, and compare plan with fact. |
| **Homepage hero headline** | Plan your day. Track your time. Know the difference. |
| **Subheadline** | Timeline, planning, lists, and calendar in one fast app — offline-first, timezone-aware, in English or Russian. |
| **Primary CTA** | Open Life OS in browser |
| **Secondary CTA** | See how it works |

| | |
| :--- | :--- |
| **Pros** | Matches shipped UI strings; aspirational “system” story; differentiates from “yet another timer” |
| **Risks** | “Life OS” is broad — SEO competes with Notion/Obsidian vibes; may confuse with repo name Counter |
| **Best audience** | Bilingual knowledge workers who want planning + tracking together |

**RU headline option:** Планируйте день. Учитывайте время. Видьте разницу.

---

## Option B — “Counter”

**Frame:** Powerful time tracker and planner.

| Field | EN |
| :--- | :--- |
| **One-line positioning** | Counter is a fast time tracker with real planning — cards, calendar, lists, and plan-vs-fact in one app. |
| **Homepage hero headline** | Track time instantly. Plan in real hours. |
| **Subheadline** | The Counter web app is live today: start a timer, schedule your day, and see what you actually did. |
| **Primary CTA** | Open Counter |
| **Secondary CTA** | View screenshots |

| | |
| :--- | :--- |
| **Pros** | Matches URL and GitHub; concrete category (time tracker); less pretentious |
| **Risks** | Generic name; understates Planning/Time View; mismatch with in-app “Life OS” title until app rename |
| **Best audience** | Users arriving from GitHub / dev community; time-tracker search intent |

**RU headline option:** Учёт времени без задержек. План по реальным часам.

---

## Option C — “Моё Время” (Russian-first)

**Frame:** Russian-first personal time system.

| Field | RU-first |
| :--- | :--- |
| **One-line positioning** | Моё Время — личная система планирования и учёта времени с офлайн-режимом и сравнением плана с фактом. |
| **Homepage hero headline** | Ваш день. Ваш учёт. Ваша правда о времени. |
| **Subheadline** | Планируйте на карточках, отмечайте время в один тап, сравнивайте план и факт — на русском и английском. |
| **Primary CTA** | Открыть в браузере |
| **Secondary CTA** | Посмотреть приложение |

| EN companion subhead (same page) | My Time — plan, track, and compare your day. Web app available now. |

| | |
| :--- | :--- |
| **Pros** | Strong RU market fit; emotional ownership (“my time”); avoids English “Life OS” abstraction |
| **Risks** | **Not in app today** — requires rename or dual-brand confusion; EN audience may not connect; URL still `/Counter/` |
| **Best audience** | Russian-primary freelancers and creatives if owner commits to brand rollout |

---

## Comparison matrix

| Criterion | A Life OS | B Counter | C Моё Время |
| :--- | :--- | :--- | :--- |
| Matches in-app title | ✅ | ❌ | ❌ |
| Matches URL | Partial | ✅ | ❌ |
| EN SEO clarity | Medium | High | Low |
| RU market resonance | Medium | Low | High |
| Implementation cost | Low | Low | High (rename?) |
| v1 recommended? | **Default if no decision** | Good for technical landing | Only if owner commits |

---

## Recommendation for implementer (not final brand choice)

Until the owner decides:

- **Marketing `<title>` and hero:** Life OS (Option A)  
- **Footer / GitHub link:** “Counter on GitHub”  
- **Do not use Моё Время** in public HTML without explicit approval  

Document the chosen option in the website repo README when implementation starts.

---

## Human decision record (fill in)

| Field | Choice |
| :--- | :--- |
| Selected option | _pending_ |
| Date | |
| RU site strategy | _full mirror / section only / none_ |
| In-app rename needed? | _yes / no_ |
