# Viktor · Russian-first model options and one-tap swaps

Status: **candidate integration**, not a production verification. Update this status only after final CI, PocketBase deployment and real key E2E.

## Intended user flow

From Planning, select exactly two saved, non-recurring cards and open Viktor. Say **«Поменяй эти две карточки местами»**. Audio capture stops after speech/silence (manual stop still supported), the captured WAV is transcribed using a configured speech provider, and the message is automatically passed to the chosen language model. The model must propose `swap_plan_positions` for those exact IDs. The app checks current times/ownership, pinned/recurring safety and cascades, then applies the calculated bulk schedule without a second modal only for the exact explicit pair. If ambiguous, ask for clarification.

A single spoken command referring to two full, distinct task names also supports the one-tap path. All other mutations retain the preview/confirm dialog. No hallucinated IDs, unpinned recurrence edits, or direct AI database access.

## Model options

1. **GigaChat** (Russian): `GigaChat-2`, `GigaChat-2-Pro`, `GigaChat-2-Max`. BYOK authorization key, exchange via Sber OAuth, fixed `https://api.giga.chat/v1/chat/completions` endpoint. Scope selection: personal (`GIGACHAT_API_PERS`), B2B (`GIGACHAT_API_B2B`), corporate PAYG (`GIGACHAT_API_CORP`). Short-lived bearer access tokens are never written to PocketBase. See [official auth docs](https://developers.sber.ru/docs/ru/gigachat/api/reference/rest/gigachat-api).
2. **YandexGPT via AI Studio** (Russian): `yandexgpt/rc`, `yandexgpt/latest`, user API key + folder ID, fixed `https://ai.api.cloud.yandex.net/v1/chat/completions` endpoint, `Authorization: Api-Key`, `OpenAI-Project: folder id`, model `gpt://folder/yandexgpt/rc`. See [Yandex OpenAI compatible API](https://aistudio.yandex.ru/en/docs/ai-studio/operations/generation/completions-basic).
3. Existing OpenAI, Gemini, Groq and OpenRouter options remain available.

**Important license/cost note:** GigaChat freemium is for personal noncommercial use. A paid/commercial LIFE OS offering requires the appropriate commercial API arrangement; verify latest terms before offering model-funded access. Text model BYOK credentials never persist; only provider/model selection and non-secret Yandex folder ID are saved.

## Voice availability
This increment keeps the current actual recorded WAV and BYOK Groq/OpenAI/Gemini transcription. Russian language model ≠ Russian voice provider: users of GigaChat and YandexGPT choose an independent supported STT provider/key. The research direction for true full-duplex live Russian interaction is Yandex AI Studio Realtime API over WebSocket, which supports voice and function/tool invocation. **Continuous realtime voice is not yet integrated**, and GigaChat/Yandex credentials must be supplied and tested by the user; shipping UI is not E2E verification.

## Required acceptance tests
- [ ] Server auth mocked for Sber token exchange and GigaChat model call, correct Yandex folder header and model URI
- [ ] Contract and planner tests for swap of adjacent and separated plans and guarded pinned/recurring cases
- [ ] Selected IDs are strictly current-day PocketBase IDs; ambiguous reference not auto-executed
- [ ] Flutter analyze/unit/widget checks + architecture/docs parity
- [ ] Production PocketBase deployment; provider URL/network and credential rejection handling
- [ ] Real Russian BYOK chat instruction and update visible after refresh/device sync
- [ ] One-tap speech end-of-utterance detection on Yandex Browser and Android mic (fallback manual stop)
- [ ] Do not claim live full-duplex voice or subscription-funded unlimited access
