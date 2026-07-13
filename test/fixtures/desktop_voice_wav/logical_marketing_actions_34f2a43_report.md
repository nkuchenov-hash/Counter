# Desktop Voice Logical Marketing failure fixture (34f2a43 live)

DESKTOP_VOICE_LOGICAL_MARKETING_FAILURE_ARCHIVED
DESKTOP_VOICE_LOGICAL_MARKETING_FAILURE_REPRODUCED
DESKTOP_VOICE_CORRUPTED_TITLE_SOURCE_TRACED

## Spoken phrase

Logical Marketing Actions

## Observed result (live, build 34f2a43)

**Logical Marketing, Taxis, and Technical Marketing, and Taxis.**

## Expected

| Field | Value |
|-------|--------|
| Category/client path | Logical Marketing (deepest safe match) |
| Task title | Actions |
| Write count before confirm | 0 until clean command |
| Final record count | exactly 1 only after valid confirmation |

## Forbidden

- Inserted **Technical Marketing** (not spoken)
- **Taxis** instead of **Actions** (whisper mis-hear)
- Repeated **Taxis**
- Title **Logical Marketing - Taxis and Technical Marketing and Taxis**

## Root cause (offline trace)

| Fragment | Source | Provenance |
|----------|--------|------------|
| Logical Marketing | whisper final | `final` — user speech (correct) |
| Taxis (first) | whisper final | `final` — mis-hear of **Actions** |
| Technical Marketing | whisper final | `final` — hallucination (not in neutral prompt; likely acoustic bleed + “Marketing” repetition) |
| Taxis (second) | whisper final | `final` — duplicate tail hallucination |

**Not caused by:**

- Partial/final concatenation (`partial_text=—`, `used_partial_as_final=no`)
- Prior session cache (`stop_return_reason=final_inference` only)
- Parser/postprocess inserting Technical Marketing (raw helper text already corrupted)

**Contributing factors:**

1. **Domain-heavy whisper `initial_prompt`** in installed helper (pre-fix) listed Price Reporter / SCW / BLINK vocabulary → biases hallucinated domain terms.
2. **No hallucination/duplicate gate** on 4-segment corrupted final → marked `candidate_useful=yes`.
3. **Latency counted on final inference** (~6856ms) — no rolling useful partial.

## Diagnostics summary (`logical_marketing_actions_34f2a43_diag.txt`)

| Field | Value |
|-------|--------|
| build_sha | 34f2a43 |
| voice_session_id | (see diag at capture) |
| partial_text | — |
| final_text | Logical Marketing, Taxis, and Technical Marketing, and Taxis. |
| candidate_useful (incorrect) | yes |
| stop_to_useful_candidate_ms | 6856 |
| final_inference_latency_ms | 2534 |

## Fix markers (this checkpoint)

- DESKTOP_VOICE_INITIAL_PROMPT_DOMAIN_LIST_REMOVED
- DESKTOP_VOICE_HALLUCINATED_TEXT_BLOCKED
- DESKTOP_VOICE_DUPLICATE_TITLE_SEGMENT_BLOCKED
- DESKTOP_VOICE_CONFLICTING_CLIENT_COMMAND_BLOCKED
- DESKTOP_VOICE_CORRUPTED_TITLE_NOT_WRITTEN
- DESKTOP_VOICE_FINAL_REPLACES_PARTIAL
- DESKTOP_VOICE_LOGICAL_MARKETING_EXACT_PARSE

## Fixtures

- `logical_marketing_actions_34f2a43_live.wav`
- `logical_marketing_actions_34f2a43_live_raw.wav`
- `logical_marketing_actions_34f2a43_diag.txt`
