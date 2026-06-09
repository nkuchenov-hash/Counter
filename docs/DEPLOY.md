# Deploy (GitHub Pages)

One command from the **git repository root** (the folder that contains `.github/workflows/deploy.yml` and `pubspec.yaml`).

`…/Apps/counter/` ← git root (`nkuchenov-hash/Counter`)

## Commands

Deploy scripts live in [`scripts/manual/`](../scripts/manual/).

| Shell | Command |
| :--- | :--- |
| PowerShell | `.\scripts\manual\td.ps1` |
| macOS / Linux / Git Bash | `./scripts/manual/td` |

First time on Unix, if needed: `chmod +x scripts/manual/td`

## What it does

1. Ensures `lib/core/env/env.dart` exists (copies from `env.dart.example` if missing; file is gitignored).
2. `flutter analyze`
3. `flutter build web --release --base-href="/Counter/"` (local sanity check; not committed)
4. If the working tree has changes: `git add -A` and commit `Deploy: <timestamp>`
5. `git push` to the current branch (usually `main`)

## What deploys the live site

Push to `main` triggers [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml):

- CI runs `flutter build web --release --base-href="/Counter/" --no-tree-shake-icons`
- [JamesIves/github-pages-deploy-action](https://github.com/JamesIves/github-pages-deploy-action) publishes `build/web` to the **`gh-pages`** branch

**Live URL:** https://nkuchenov-hash.github.io/Counter/

The `td` scripts do **not** push to `gh-pages` directly; Actions owns that step.

## Prerequisites

- Flutter stable on `PATH`
- Git remote `origin` → `https://github.com/nkuchenov-hash/Counter.git`
- Permission to push to `main`

## Redeploy without code changes

If there is nothing to commit, `git push` is a no-op and Actions will not run. To force a redeploy:

```bash
git commit --allow-empty -m "Redeploy"
git push origin main
```

## Legacy scripts

- `Archive/root_cleanup_backup/f.ps1` — commit + push only (no analyze/build)
- `lib/deploy.ps1` — Firebase hosting (not used for GitHub Pages)
