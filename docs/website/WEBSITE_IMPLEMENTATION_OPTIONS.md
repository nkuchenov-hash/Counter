# Website Implementation Options v1

**Date:** 2026-06-24  
**Constraint:** Do not break Flutter web app at `https://nkuchenov-hash.github.io/Counter/` (`--base-href="/Counter/"`).  
**Do not change:** `update.ps1`, `.github/workflows/deploy.yml`, or `web/` until a deliberate deploy plan exists.

---

## Options compared

| Option | Description | Pros | Cons |
| :--- | :--- | :--- | :--- |
| **A. Static HTML/CSS in repo** | `marketing/` or `site/` folder with hand-written or templated HTML | Zero JS framework; fast; easy GitHub Pages; no Flutter coupling | Manual EN/RU duplication; no component reuse |
| **B. Flutter web marketing route** | New route inside existing Flutter app | Shared theme/fonts | Bloats app bundle; same `/Counter/` base-href; wrong tool for SEO landing; violates “don’t touch app” for v1 |
| **C. Vite + React/Vue/Svelte static** | `marketing-site/` subproject → `npm run build` → static `dist/` | Good DX, components, i18n plugins | Extra toolchain; CI step; team must maintain Node |
| **D. Astro / Eleventy** | Static site generator in subfolder | Content in markdown; partial hydration optional; excellent for landing + FAQ | New dependency; learn one generator |
| **E. GitHub Pages subpath** | e.g. `https://user.github.io/counter-site/` or `https://user.github.io/Counter/marketing/` | Same hosting account | **Risk:** `/Counter/marketing/` shares deploy with Flutter if same `gh-pages` branch — easy to break app |
| **F. Separate repo / subdomain** | `lifeos.app` or `counter-site` repo → Pages root `/` | Clean separation; marketing at `/`, app at `app.` subdomain | Two repos; DNS; more ops |
| **G. External builder later** | Webflow, Framer, Notion site | Fast for designer | Lock-in; harder to version with product docs |

---

## GitHub Pages layout risks

Current deploy (from `DEPLOY.md`):

- Push `main` → Actions builds Flutter `build/web` → publishes to **`gh-pages`** branch root (served as `/Counter/` on `nkuchenov-hash.github.io`).

| Approach | Safe? | Notes |
| :--- | :--- | :--- |
| Marketing at repo root `docs/` folder (Pages from `/docs`) | ✅ | Enable “GitHub Pages from `/docs`” on `main` — **separate** from `gh-pages` Flutter artifact |
| Marketing in `marketing/` built to `docs/` on CI | ✅ | Workflow copies static build → `docs/`; never touch `gh-pages` |
| Marketing on same `gh-pages` as Flutter | ⚠️ | Must live in subfolder **without** overwriting Flutter `index.html` at `/Counter/` — fragile |
| Replace `gh-pages` with marketing | ❌ | Breaks app |

---

## Recommended v1 approach

### **Primary recommendation: D + A hybrid — Astro (or Eleventy) in `marketing/`, output to `docs/` for GitHub Pages**

**Why:**

1. **Isolation** — No changes to Flutter `lib/`, `web/`, or `update.ps1`.  
2. **Content fit** — Homepage wireframe + FAQ map cleanly to markdown/HTML partials.  
3. **Deploy** — Second Pages source (`/docs` on `main`) or separate workflow publishing only `marketing/dist` to `gh-pages:/site/` **without** touching `/Counter/` paths.  
4. **i18n** — Astro i18n or duplicate `src/pages/ru/` for partial RU (matches v1 scope).  
5. **Performance** — Static HTML, no Flutter load for marketing.

**Concrete v1 steps (when implementing — not now):**

1. Create `marketing/` at repo root (sibling to `lib/`, not inside `web/`).  
2. `npm create astro@latest` (or Eleventy) with `base: '/counter-marketing/'` **or** use custom domain later.  
3. Build outputs to `docs/` **or** artifact uploaded by separate GitHub Action.  
4. Configure repo Pages: **Source = Deploy from branch `main` /docs folder** (simplest) OR new workflow.  
5. CTA links absolute to `https://nkuchenov-hash.github.io/Counter/`.  
6. Add `marketing/README.md` with build instructions only.

**Alternative if zero Node policy:** **Option A** — plain `docs/index.html` + `docs/css/site.css` hand-maintained (~5 pages). Acceptable for v1 if owner wants minimal tooling.

---

## Not recommended for v1

| Option | Reason |
| :--- | :--- |
| **B Flutter route** | Couples marketing to app release; SEO poor; scope creep |
| **Same gh-pages root as app** | High risk of breaking `/Counter/` |
| **Framer/Webflow first** | Docs in repo won't match live site |

---

## CI / deploy sketch (future)

```text
# Separate workflow: .github/workflows/marketing.yml (NOT created in this pass)
on:
  push:
    paths: ['marketing/**', 'docs/website/**']
jobs:
  build-marketing:
    - npm ci && npm run build   # in marketing/
    - output to docs/ OR peaceiris/pages-action with destination_dir: marketing
```

**Do not** modify existing `deploy.yml` until owner approves dual-deploy strategy.

---

## Assets

- Store screenshots in `marketing/public/images/` or `docs/images/` (when implementing).  
- Do not commit large binaries to `web/` Flutter folder.  
- Use WebP + lazy loading on tour page.

---

## Decision record (fill in at implementation)

| Field | Choice |
| :--- | :--- |
| Generator | _Astro / plain HTML / other_ |
| Pages source | _/docs on main / separate gh-pages dir / external_ |
| Public URL | _TBD_ |
| Owner approved dual deploy | _yes / no_ |
