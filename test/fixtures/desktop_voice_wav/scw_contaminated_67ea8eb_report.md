# Desktop Voice session contamination fixture (67ea8eb)

DESKTOP_VOICE_CONTAMINATED_TASK_FIXTURE_ARCHIVED
DESKTOP_VOICE_STALE_TRANSCRIPT_FAILURE_REPRODUCED
DESKTOP_VOICE_CORRUPTED_TITLE_PROVEN_FROM_DIAG

## Observed failure (live, build 67ea8eb)

- **Actual task title:** DEL MOD Submit BLINK Laredo Technical Services SELVENT Computer Warehouse DEL MOD Submit
- **Expected task title:** Submit
- **Expected path:** Work > Price Reporter > SOUTHERN COMPUTER warehouse > DEL MOD
- **Category shown:** Работа > Price Reporter > SOUTHERN COMPUTER warehouse

## Forbidden stale fragments

- BLINK
- Laredo Technical Services
- SELVENT
- duplicated DEL MOD Submit

## Expected counts

- record count: exactly one (must NOT be created for contaminated command)
- active voice session count: exactly one

## Diagnostics summary (last_attempt_diag_67ea8eb_contaminated_2026_07_10.txt)

| Field | Value |
|-------|-------|
| build_sha | 67ea8eb |
| partial_text (stale) | Sal intervened for Liam. |
| final_text | Southern Computer Warehouse, DEL MOD, Submit, BLINK, Laredo Technical Services, SELVENT, Computer Warehouse, DEL MOD, Submit, |
| candidate_useful (incorrect) | yes |
| stop_to_useful_candidate_ms | 7729 |
| final_inference_latency_ms | 1450 |

## Root cause (offline repro)

1. **Global `last_partial` cache** — prior session partial (`Sal intervened for Liam.`) served at stop before session reset.
2. **Whisper initial_prompt** listed BLINK/Laredo client names → hallucinated into final output.
3. **No contamination gate** — parser marked mega-string as `exact` / useful.
4. **Latency counted on final** (~7.7s), not session-scoped useful partial.

## Fix markers

- DESKTOP_VOICE_HELPER_SESSION_RESET
- DESKTOP_VOICE_CONTAMINATION_GATE
- DESKTOP_VOICE_STOP_TO_USEFUL_CANDIDATE_UNDER_500MS (strict <500ms, useful only)
