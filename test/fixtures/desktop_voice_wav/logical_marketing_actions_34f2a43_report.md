# Desktop Voice Logical Marketing failure (34f2a43 live)

DESKTOP_VOICE_LOGICAL_MARKETING_FAILURE_ARCHIVED
DESKTOP_VOICE_LOGICAL_MARKETING_FAILURE_REPRODUCED
DESKTOP_VOICE_CORRUPTED_TITLE_SOURCE_TRACED

## Spoken phrase

Logical Marketing Actions

## Observed result

Logical Marketing - Taxis and Technical Marketing and Taxis

(final STT: `Logical Marketing, Taxis, and Technical Marketing, and Taxis.`)

## Expected

| Field | Value |
|-------|--------|
| category/client path | Logical Marketing |
| task title | Actions |
| write count before confirm | 0 |
| final record count after valid confirm | exactly 1 |

## Forbidden

- Technical Marketing (unspoken insertion)
- Taxis (misrecognition of Actions + duplicate)
- second Taxis

## Diagnostics summary (last_attempt_diag_34f2a43)

| Field | Value |
|-------|-------|
| build_sha | 34f2a43 |
| partial_text | — (no rolling partial) |
| final_text | Logical Marketing, Taxis, and Technical Marketing, and Taxis. |
| candidate_useful (incorrect) | yes |
| stop_to_useful_candidate_ms | 6856 |
| final_inference_latency_ms | 2534 |
| effective initial_prompt (pre-fix) | Price Reporter, Planning, Southern Computer Warehouse, SCW, DEL MOD, … |

## Root cause (offline repro)

1. **Whisper hallucination** — broad domain `initial_prompt` + whisper misheard “Actions” as “Taxis”; invented “Technical Marketing”.
2. **No partial** — useful candidate only at final inference (~6.8s), not &lt;500ms.
3. **No hallucination gate** — duplicate Taxis + conflicting marketing scopes not blocked before pending/write.
4. **Not merge concat** — `partial_text=—`; corruption is in whisper `final_text` only.

## Provenance

| Fragment | Source |
|----------|--------|
| Logical Marketing | whisper final (spoken) |
| Taxis | whisper final (misrecognition of Actions) |
| Technical Marketing | whisper final (hallucination / prompt bias) |
| second Taxis | whisper final (duplicate segment) |

## Fix markers

- DESKTOP_VOICE_INITIAL_PROMPT_DOMAIN_LIST_REMOVED
- DESKTOP_VOICE_HALLUCINATED_TEXT_BLOCKED
- DESKTOP_VOICE_DUPLICATE_TITLE_SEGMENT_BLOCKED
- DESKTOP_VOICE_FINAL_REPLACES_PARTIAL
- DESKTOP_VOICE_LOGICAL_MARKETING_EXACT_PARSE
