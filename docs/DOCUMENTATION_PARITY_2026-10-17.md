# LIFE OS — documentation/code parity review (2026-10-17)

## Scope and evidence
Documentation-only review of `main` at `fa0fd73fc2` (GitHub repository tree and selected sources). This is **not** an executed Flutter test or deployment verification. No application files, schema, scripts, historical reports, or releases were changed.

- Current agent entry: [AGENTS.md](../../AGENTS.md), then [AGENT_NAVIGATION.md](../../AGENT_NAVIGATION.md).
- Current architecture/UX: [ARCHITECTURE.md](../ARCHITECTURE.md), [UX_CONTRACT.md](../UX_CONTRACT.md).
- Source code is in `lib/`; test entrypoints exist in `test/` and `integration_test/`.
- `CHANGELOG.md` records Calendar Week drag changes on 2026-10-17.
- [PROJECT_KNOWLEDGE_PACK.md](../PROJECT_KNOWLEDGE_PACK.md) specifies **16**, not 14, canonical upload documents; `AGENT_NAVIGATION.md` superseded the legacy `CLAUDE.md`.
- The repository's GitHub **default branch is currently `gh-pages`**, although application development/source docs are on `main`. Unqualified GitHub file readers can therefore inspect generated site files instead of source. This is verified from repository metadata.

## Confirmed actions
1. For AI/tooling, **always supply `ref: main` explicitly** when retrieving application code or documentation. `gh-pages` is for published web output, not the source-of-truth code.
2. Correct the default GitHub branch to `main` in repository Settings using an authorized admin workflow; do not change or delete the `gh-pages` publishing branch. This step is **not performed** by this documentation-only review.
3. Refresh ChatGPT Project Knowledge attachments from the current **16-file** pack; the uploaded July `CLAUDE.md` and 14-file manifest are historical and cannot supersede current Git.
4. Run the existing strict architecture/documentation parity guards, Flutter analysis/tests and release build on a working checkout to validate code↔docs. They were **not run** in this review.
5. Retain existing architecture, UX, data, security and release contracts. No mass rewriting or deletion.

## Acceptance
- Source branch is unambiguous (`main`); deployment branch remains `gh-pages`.
- Exactly one canonical agent navigation document is referenced.
- Uploaded knowledge pack matches the current repository.
- Guard output is recorded for the actual checked-out commit, not inferred from older audits.
