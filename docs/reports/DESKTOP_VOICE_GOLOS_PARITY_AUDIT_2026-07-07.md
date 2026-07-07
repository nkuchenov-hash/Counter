# Desktop Voice STT Parity Audit — 2026-07-07 (revised)

**Status:** Counter matches extracted GOLOS-equivalent Parakeet pipeline on Counter’s fixture WAV. **Actual Handy parity remains unproven.** Handy black-box baseline collected 2026-07-07.

---

## Accepted phrasing

> Counter now matches the extracted GOLOS-equivalent local Parakeet pipeline on the same WAV. Actual Handy parity remains unproven.

Do **not** claim Handy quality comes from glossary/postprocess unless directly proven for a given session.

---

## What is proven

| Claim | Evidence |
|-------|----------|
| Counter raw STT matches GOLOS-equivalent pipeline on Counter fixture WAV | `wav_stt_replay` + HTTP helper: both → `Solvan Computer Warehouse, Delmore, Submit.` |
| Same Parakeet int8 encoder weights (Handy / GOLOS / Counter) | SHA256 prefix `6139D2FA7E1B0860`, size 652,183,999 |
| Handy user-visible transcript for same spoken phrase (approximate live session) | `handy.log` 2026-07-07 15:14:54 |
| Handy session used `transcribe` binding, not post-process | Log: `TranscribeAction::stop` for `transcribe`; settings: `post_process_enabled: false` |
| Handy WAV replay through no-VAD Parakeet matches Handy log text | See same-WAV matrix below |

---

## Handy black-box baseline (collected)

**Source:** [Handy](https://github.com/cjpais/Handy) (`com.pais.handy`), log + saved recording.

| Field | Value |
|-------|-------|
| Date/time | 2026-07-07 15:14:54 (local) |
| Spoken phrase (user intent) | Southern Computer Warehouse DEL MOD submit |
| Handy visible transcript | `Southern Computer Warehouse Del Mod, submit.` |
| Model | `parakeet-tdt-0.6b-v3` |
| Post-process | **off** (`post_process_enabled: false`) |
| Capture (device) | 48 kHz, 2 ch, F32 (`Realtek` mic) |
| Processed audio length | 66,720 samples (16 kHz mono equivalent ≈ 4.17 s) |
| Saved WAV | `%APPDATA%\com.pais.handy\recordings\handy-1783437294.wav` |
| Fixture copy | `test/fixtures/desktop_voice_wav/scw_delmod_submit_handy_2026_07_07.wav` |

---

## Counter baseline (same phrase, different recording)

| Field | Value |
|-------|-------|
| Date/time | 2026-07-07 ~11:48 (Counter `latest_command.wav`) |
| Counter raw STT (GOLOS-equivalent pipeline) | `Solvan Computer Warehouse, Delmore, Submit.` |
| Counter final command text | Parser-dependent; parent-only garbage blocked |
| Fixture | `test/fixtures/desktop_voice_wav/scw_delmod_submit_real_2026_07_07.wav` |
| Capture | 16 kHz PCM16 mono (`record` package) |

**Comparison type:** approximate same-phrase live — **not** the same WAV file. Handy WAV is 133,484 bytes; Counter fixture is 140,142 bytes; timestamps ~34 minutes apart.

---

## Same-WAV replay matrix (`wav_stt_replay`, shared Parakeet model)

### Handy WAV (`scw_delmod_submit_handy_2026_07_07.wav`)

| Pipeline | Raw transcript |
|----------|----------------|
| golos_equivalent (350 ms pad + 700 ms tail VAD) | Southern Computer Warehouse **Dell** Mod, submit. |
| **no_vad** | Southern Computer Warehouse **Del Mod**, submit. |
| Handy app log (black box) | Southern Computer Warehouse **Del Mod**, submit. |

### Counter fixture WAV (`scw_delmod_submit_real_2026_07_07.wav`)

| Pipeline | Raw transcript |
|----------|----------------|
| golos_equivalent VAD | **Solvan** Computer Warehouse, **Delmore**, Submit. |
| no_vad | Solvent Computer Warehouse, Del Mall, Submit. |

**Interpretation:** On Handy’s own WAV, Parakeet + no VAD ≈ Handy app output. Counter’s fixture WAV is a **worse acoustic capture** of the same phrase; pipeline parity with GOLOS does not fix that file.

---

## Confirmed differences (Handy vs Counter today)

| Area | Handy (observed) | Counter (observed) |
|------|------------------|---------------------|
| Model encoder | parakeet-tdt-0.6b-v3 int8, SHA256 6139D2FA… | Same weights via GOLOS Release bundle |
| Device capture | 48 kHz F32 stereo → internal resample | Fixed 16 kHz PCM16 mono |
| VAD before inference | Unknown in closed app; replay suggests **minimal/no trim** | GOLOS-style 350 ms + 700 ms tail in helper |
| Post-process / LLM | Off for this session | Cloud/postprocess not on raw path |
| Glossary / word correction | `custom_words: []`; `word_correction_threshold: 0.18` — **effect on this transcript unproven** | Separate Counter postprocess (not counted as raw STT) |
| Recording | `handy-1783437294.wav` | `latest_command.wav` (different take) |

---

## Unproven assumptions (do not state as fact)

- That Handy uses `glossary.rs` or GOLOS glossary for this result
- That postprocess/glossary is why Handy “sounds better”
- That Counter equals Handy
- That GOLOS native app would match Handy on either WAV (GOLOS live baseline not collected for this phrase)

---

## Next proposed fix (technical focus)

1. **Match Handy audio capture:** native device rate, F32, stereo/mono downmix, linear resample to 16 kHz (not fixed 16 kHz PCM16 at ADC).
2. **Revisit VAD for short command clips:** Handy WAV + no VAD matches Handy log; GOLOS tail-trim may be wrong for command-length audio.
3. **Re-capture regression WAV** after capture change; add Handy WAV as secondary golden reference.
4. **Optional:** inspect Handy open-source `audio_toolkit` / transcription manager for decode params (separate from GOLOS `golos_flutter` source).

---

## Tools

- `installer/windows/wav_stt_replay/` — offline Parakeet replay
- `scripts/manual/compare_desktop_voice_wav_stt.ps1` — Counter helper vs replay pipelines

---

## Markers

- `DESKTOP_VOICE_GOLOS_EQUIVALENT_SAME_WAV_RUNNER_READY`
- `DESKTOP_VOICE_HANDY_BASELINE_COLLECTED` (log + WAV)
- `DESKTOP_VOICE_SAME_WAV_HANDY_VS_COUNTER_NOT_IDENTICAL` (different recordings)
- `DESKTOP_VOICE_COUNTER_PIPELINE_MATCHED_TO_GOLOS` (on Counter fixture only)
