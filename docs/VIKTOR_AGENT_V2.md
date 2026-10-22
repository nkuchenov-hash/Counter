# Viktor V2 — dialogue-first LIFE OS agent

Status: **in implementation; NOT release-ready**. This document governs the
agent redesign; existing source and Brain invariants remain authoritative.

## User contract

Users speak to Viktor normally in Russian or English. They describe a result,
ask questions about any accessible LIFE OS data, ask for alternatives, adjust a
draft in multiple turns, and approve one final change set. Users never provide
PocketBase IDs, JSON schemas, tool names or troubleshooting syntax.

Concrete acceptance scenarios:

1. "Какая третья строчка стихотворения, написанного в январе 2023?"
   Search across owned historic Notes and Records by reliable creation dates,
   inspect text, disambiguate several candidates, quote exactly the nonempty
   line with the originating document ID. Never fabricate a poem or date.
2. "Поменяй её на ..." Edit precisely the previously observed line and retain
   the rest of the rich document, images, attachment blocks and metadata.
   Compare original text, title and document version before applying.
3. "Предложи три варианта выходных" Answer with actual alternative drafts, each
   aware of schedule, constraints, timezone and preferences. Do not mutate
   user data. "Выбираю второй, но в субботу ..." revises that same draft.
   Confirmation previews all Saturday and Sunday actions together.
4. "Перенеси невыполненное за вчера на сегодня, с 9 утра" Read current state,
   propose once, preview collisions, ask permission and verify persisted
   server state after applying. No model-generated status/time formatting errors
   may be presented as user errors.

## Architecture and boundaries

- **Dialogue implementation:** append-only `viktor_turns` PocketBase collection with authenticated owner rules and conversation_id=`main`; recent messages restore on restart and are available on other devices. This preserves messages but does not constitute semantic or long-term AI memory. Failed sync must be visible and must not cause silent data loss.
- **Dialogue:** authenticated owner-scoped conversations persist across app
  restarts and devices (future `viktor_conversations` / `viktor_turns`).
  The short in-memory dialogue context alone is NOT durable memory.
- **Retrieval:** read-only tools index owner-scoped Plans, historic Records,
  Notes, Paths, tags and categories; query by date, title and content. Exact
  text observations retain immutable source pointers. Search results are never
  treated as executable instructions. Date created is not inferred from title.
- **Reasoning/tool loop:** provider-neutral bounded iteration
  (goal -> read -> observe -> propose -> validate -> preview -> confirm ->
  execute -> independently re-read result). A provider response requesting
  more context must never silently discard a valid action. Repair must be
  typed, not a string-parsing pile of exceptions.
- **Criteria-based multi-day grouping (in progress):** bulk_replan can now
  select by status, category name, tag name, title substring, explicit keep exclusions, maximum count and
  priority, and load several source/target dates in one preview. The engine
  keeps unrelated tasks unchanged, refuses overlap, pinned/recurring plans,
  and recomputes on approval. It is NOT transactional across rows yet.
- **Weekend drafts:** versioned owner-scoped `viktor_drafts` with candidate
  itineraries, selection, changes, current source revisions and explicit
  save/cancel state. A draft is not a saved event. Composite two-day plan
  changes must use a Brain-level transactional adapter with idempotent
  request IDs, fixed-time protection, recurrence-instance policies and
  conflict/rollback behavior. One `create_plan` per event is insufficient.
- **Writing:** only allowlisted Brain commands under the current authenticated
  user's permissions. Compare fresh row version before writing. An LLM never
  gets PocketBase administrator credentials, SQL or arbitrary network access.
  For consequential changes, consent must correspond to the exact preview
  version. Confirmed writes return verified outcomes, not merely a model claim.
- **Privacy:** BYOK/hosted credential material remains in existing protected
  vault; notes and conversation text are transmitted only to selected provider
  with explicit user connection. Do not log plaintext journals or secrets.

## Incremental code in this branch

- Read-only `search_record_notes` and `read_record_note` search historic Records and read numbered text. Historic Record line edits are not yet implemented.
- Read-only `search_notes` with text and creation year/month filters; result
  snippets, source record ID and creation date. `read_note` returns numbered
  nonempty lines from the canonical NoteDocument. This does **not** yet cover
  historic Record notes or semantic search.
- `edit_note_line` validates exact old text and single-line structure,
  preserves other blocks and media, and refuses complex inline runs rather
  than corrupting formatting. Existing Brain preview/approval safeguards apply.
- Bounded prior chat turns are forwarded for within-session references
  ("second option", "change Saturday"). This is **not** durable,
  cross-device conversation persistence.
- No safe two-day composite draft commit tool yet. No claim of full weekend
  scheduling or of ChatGPT-equivalent capability.

## Release gates (all mandatory before V2 readiness)

- Authenticated provider test in deployed web UI, including real model
  responses, multi-turn history, truncated responses and one failed tool.
- January 2023 fixture with dates: search -> read -> quote exact third
  nonempty line -> amend it -> refresh another session -> confirm no changes
  to neighboring lines, formatting or media. Repeat for legacy plain text and
  an ambiguous match.
- Weekend fixture with fixed commitments, two alternative drafts, selection,
  follow-up adjustment, one preview covering two days, consent, write,
  cross-session verification, and safe handling of a stale change or partial
  failure.
- Regression suite: timezone, recurrence, owner isolation, offline retry,
  sync, conflict cascades, cache and responsiveness. Verify other application
  features still work. No self-awarded readiness on a green CI build.
