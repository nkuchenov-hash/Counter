# Desktop Voice STT Parity Audit — 2026-07-07 (revised)

**Status:** Counter matches extracted GOLOS-equivalent Parakeet pipeline on Counter’s fixture WAV. **Actual Handy parity remains unproven pending live re-capture.** Handy black-box baseline collected 2026-07-07. Capture-parity engineering pass (native 48 kHz capture + float downmix + HQ resample + no_vad command VAD) implemented + unit-tested 2026-07-07; live re-capture and clean-tree installer build still pending.

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

## Capture-parity pass (implemented 2026-07-07)

### Capture path (Handy-style native capture)
- Counter now requests **48 kHz stereo PCM16** from the mic (device-native) instead of fixed 16 kHz mono, avoiding Media Foundation's forced 16 kHz downsample at the ADC boundary.
- Backend decision: **`record` package at native rate**, not a new WASAPI/cpal helper. `record_windows` (`record_mediatype.cpp` `CreateAudioProfileIn`) hardcodes `MFAudioFormat_PCM` 16-bit, so F32 capture is not available through it; rate and channels are configurable, which is the dominant delta. Escalation to a WASAPI/cpal F32 helper is documented if live recapture proves I16 insufficient.
- Processing chain (`processNativeCaptureForStt`, pure/unit-tested): PCM16 → float → **mono downmix (channel average)** → **high-quality windowed-sinc (Hann, 16 zero-crossings) resample to 16 kHz** → PCM16. **No peak normalization** (proven harmful: `Solvan → Solvent` on old Counter WAV).
- Two files saved per capture: `latest_command_raw.wav` (native 48 kHz stereo, diagnostics) and `latest_command.wav` (processed 16 kHz mono, STT).
- Remaining diff vs Handy: Handy captures **F32** native; Counter captures **I16** native (record_windows limitation). Resampler is windowed-sinc vs Handy's `rubato`. Both acoustically minor for 16-bit speech.

### Command VAD — selected by benchmark (`wav_stt_replay`, all pipelines)

Handy WAV (already capture-endpointed by Handy Silero VAD):

| Pipeline | Raw transcript |
|----------|----------------|
| golos 350/700 | Southern Computer Warehouse **Dell** Mod, submit. |
| light_endpoint 300/900 | Southern Computer Warehouse **Dell** Mod, Submit. |
| **no_vad** | Southern Computer Warehouse **Del Mod**, submit. |

Old Counter WAV (fixed 16 kHz, pre-parity):

| Pipeline | Raw transcript |
|----------|----------------|
| golos 350/700 | Solvan Computer Warehouse, Delmore, Submit. |
| golos + peak_norm | **Solvent** … (peak norm degrades) |
| light_endpoint 300/900 | Solvent … **still mod** submit. (worse) |
| **no_vad** | Solvent Computer Warehouse, **Del Mall**, Submit. |

**Selected: `no_vad`** for command-length audio — best DEL MOD accuracy on both WAVs, matches Handy's own app output, never cuts final words. Production helper build (`build_stt_helper_en.ps1`) patched so `trim_silence` is a no-op. Light endpointing tested and rejected.

### Still pending (hard-blocked on live mic + clean-tree build)
1. **Live re-capture** of "Southern Computer Warehouse DEL MOD submit" through the new native path → save `scw_delmod_submit_counter_native_capture_2026_07_07.wav` (raw + processed), replay via `wav_stt_replay`, compare to Handy. Parity is **not** claimed until this is done.
2. **Rebuild** STT helper (no-VAD), Windows release, and Inno installer from a **clean committed SHA** (`build_sha != dev`); silent install + installed smoke.

### Tooling
- `scripts/manual/compare_desktop_voice_vad_modes.ps1` — full pipeline × fixture matrix (Handy / old Counter / new native when present).
- `DesktopVoiceWavSttBenchmark.captureParityReport()` — three-way Handy vs old vs new domain-accuracy comparison.

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

### Capture-parity pass markers
- `DESKTOP_VOICE_CAPTURE_PARITY_PASS_STARTED`
- `DESKTOP_VOICE_NO_ALIAS_FIX_FOR_CAPTURE_PARITY`
- `DESKTOP_VOICE_RAW_STT_QUALITY_TARGET`
- `DESKTOP_VOICE_NATIVE_RATE_CAPTURE` / `DESKTOP_VOICE_F32_CAPTURE_IF_AVAILABLE` (unavailable, record_windows pcm16-only)
- `DESKTOP_VOICE_RAW_CAPTURE_WAV_SAVED` / `DESKTOP_VOICE_STT_READY_WAV_CREATED` / `DESKTOP_VOICE_HIGH_QUALITY_RESAMPLE_USED`
- `DESKTOP_VOICE_NO_HARMFUL_PEAK_NORMALIZATION` / `DESKTOP_VOICE_HANDY_PREPROCESSING_MATCHED` / `DESKTOP_VOICE_REMAINING_AUDIO_DIFFS_LOGGED`
- `DESKTOP_VOICE_COMMAND_VAD_EVALUATED` / `DESKTOP_VOICE_NO_VAD_TRIM_OPTION_TESTED` / `DESKTOP_VOICE_COMMAND_VAD_SELECTED_BY_BENCHMARK` (no_vad) / `DESKTOP_VOICE_FINAL_WORDS_NOT_CUT`
- `DESKTOP_VOICE_HANDY_WAV_FIXTURE_ADDED` / `DESKTOP_VOICE_NEW_COUNTER_NATIVE_CAPTURE_FIXTURE_ADDED` (on recapture) / `DESKTOP_VOICE_CAPTURE_PARITY_BENCHMARK_UPDATED`
- Safety (existing, verified by test): `DESKTOP_VOICE_PARENT_ONLY_RECORD_BLOCKED_WITH_UNRESOLVED_TOKENS`, `DESKTOP_VOICE_NO_GARBAGE_RECORD`, `DESKTOP_VOICE_LOW_CONFIDENCE_NO_RECORD`, `DESKTOP_VOICE_AMBIGUOUS_NO_RECORD`

### Pending markers (emitted on live recapture / build)
- `DESKTOP_VOICE_COUNTER_RECATURE_AFTER_CAPTURE_FIX`
- `DESKTOP_VOICE_COUNTER_RAW_STT_AFTER_CAPTURE_FIX`
- `DESKTOP_VOICE_HANDY_BASELINE_COMPARISON_UPDATED`
