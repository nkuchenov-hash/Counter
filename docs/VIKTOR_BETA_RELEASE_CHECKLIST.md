# Viktor beta release checklist

Goal: make the in-app Viktor chat usable with an authenticated LIFE OS account and the user's own AI provider key.

## Before first use
- [ ] Rebase the feature onto current main without losing newer changes.
- [ ] Regenerate the detailed app structure and pass all architecture checks.
- [ ] Pass web, Android ARM64, and Windows builds on the rebased code.
- [ ] Deploy the PocketBase proposal endpoint and validate access controls.
- [ ] Perform a real API-key request with provider consent and valid credentials.
- [ ] Verify read -> preview -> update plan -> refresh -> read from another session.
- [ ] Check small-screen button and keyboard layout, desktop hotkey and voice input.
- [ ] Confirm that failed writes are reported accurately and recurrence is protected.
- [ ] Publish the verified web build and attach builds corresponding to the same commit.

## Beta scope
BYOK supports authenticated users without a paid platform plan. Server-funded AI remains disabled until metering, limits, billing and subscription management are implemented. Provider keys are session-only. The core scheduling and record mutations go through the existing Brain, never model-generated API endpoints.

## After beta
Hosted AI and subscriptions, persistent credential vault, synced chat history, transaction-level undo, recurring-series editing, and external ChatGPT access.

## Release rule
Only claim usable after an authenticated end-to-end test with a noncritical plan. Keep #285 as draft until tests pass.
