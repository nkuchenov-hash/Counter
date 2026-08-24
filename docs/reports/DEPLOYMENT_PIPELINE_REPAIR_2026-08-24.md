# Deployment Pipeline Repair — 2026-08-24

## Failure

The repository default branch is `gh-pages`, while source changes are made on `main`. The web deployment replaced the `gh-pages` tree with `build/web` but preserved only `.github/workflows/deploy.yml`. That could delete `.github/workflows/deploy-pocketbase.yml` from the default branch after a successful release, breaking the `workflow_run` chain used by the next release.

Temporary Plans Time recovery workflows also accumulated on `gh-pages`, including jobs that referenced repair scripts already removed from `main`.

The web deployment concurrency group additionally included the source SHA, so overlapping releases used different groups and could race each other back onto `gh-pages`.

## Repair

- Synchronized canonical `deploy.yml` and `deploy-pocketbase.yml` onto the default `gh-pages` branch.
- Removed temporary Plans Time bootstrap/finalizer/issue-trigger workflows.
- Web publish now preserves the current default-branch operational workflows, removes known temporary Plans Time recovery workflows, and forcibly restores canonical `deploy.yml` and `deploy-pocketbase.yml` from the validated source checkout.
- Web deployments now share the constant `life-os-web-deploy` concurrency group with `cancel-in-progress: true`, so an older release cannot overwrite a newer one.
- `scripts/audit/deployment_contract.py` now guards workflow continuity and release serialization in addition to server-before-web ordering.

## Expected release chain

`main` push → PocketBase validation/deploy → successful `workflow_run` → exact validated SHA web build → `gh-pages` publish while preserving the deployment workflows required for the next release.
