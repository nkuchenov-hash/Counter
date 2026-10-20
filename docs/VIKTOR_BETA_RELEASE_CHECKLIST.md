# Viktor beta release checklist

Goal: make the in-app Viktor chat usable with an authenticated LIFE OS account and the user's own AI provider key.

## Before first use
- [x] Rebase onto the October 20 main without losing Notes/Profile updates; PR #285 merged as b25d06a.
- [x] Regenerate detailed structure and pass Architecture Guard (GitHub Actions run 39435272669).
- [ ] Pass web, Android ARM64, and Windows builds on the rebased code.
- [x] Deploy PocketBase proposal endpoint and validate anonymous route 401, entitlement hooks and existing sleep/Paths checks (run 39435272698).
- [ ] Perform a real API-key request with provider consent and valid credentials.
- [ ] Verify read -> preview -> update plan -> refresh -> read from another session.
- [x] Pass 320/390/768 px composer widget tests and Windows compilation; physical phone microphone/keyboard checks still pending.
- [x] Pass stale-preview, fixed-time and recurrence unit checks; partial persistence errors are surfaced rather than reported as complete success.
- [ ] Publish the verified web build and attach builds corresponding to the same commit.

## Beta scope
BYOK supports authenticated users without a paid platform plan. Server-funded AI remains disabled until metering, limits, billing and subscription management are implemented. Provider keys are session-only. The core scheduling and record mutations go through the existing Brain, never model-generated API endpoints.

## Dictation regression release gate (2026-10-20)
- [x] Replace browser SpeechRecognition with the Notes-proven record PCM16 WAV capture and live audio level/byte count.
- [x] Add session-only BYOK speech transcription support to PocketBase for OpenAI, Groq and Gemini; OpenRouter requires an independent speech provider key.
- [x] Add WAV unit tests and speech endpoint authentication/provider contract tests to CI.
- [ ] Pass architecture parity, web/Android/Windows compile and PocketBase hook tests on the final commit.
- [ ] Deploy the endpoint to production and confirm anonymous access gets 401 (not 404).
- [ ] In Yandex Browser, verify speaking causes changing mic level and accumulating captured bytes; after pressing stop, editable recognized words appear.
- [ ] If the provider rejects the key or no audio arrives, check the inline error appears and no false transcript or plan write happens.

## Russian-first model and one-command swap (2026-10-20)
- [x] PR #302 merged into main as `82a4a75`: GigaChat (personal/B2B/CORP), YandexGPT, two-card swap, selected-card context and voice auto-submit after recording.
- [x] Fixed GigaChat Authorization Key prefix parsing and separate speech credential check for Russian text models.
- [x] Production PocketBase hook deployment and existing data/sleep health checks passed (run 39479047773).
- [x] Architecture Guard passed on integration commit (run 39479047855).
- [ ] Publish current-main Flutter web build to gh-pages and verify the exact `lifeos-build.txt` SHA.
- [ ] Verify actual BYOK GigaChat/YandexGPT key with a signed-in user. Browser voice currently needs an independent Groq, OpenAI or Gemini STT key for Russian text models.
- [ ] In Planning, select two stored cards and verify one spoken/text command swaps only those two with correct schedule cascade, remote refresh and safe error behavior.

## After beta
Hosted AI and subscriptions, persistent credential vault, synced chat history, transaction-level undo, recurring-series editing, and external ChatGPT access.

## Release rule
PR #285 has been merged into main. Server rollout succeeded, but the latest web build and an authenticated provider-key end-to-end test still need confirmation. Only claim full readiness after testing a noncritical real plan across two sessions. Release issue #296 remains the single tracking location.
