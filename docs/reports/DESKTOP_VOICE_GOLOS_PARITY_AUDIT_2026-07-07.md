# Desktop Voice GOLOS Parity Audit — 2026-07-07 (same-WAV verified)

**Markers:** `DESKTOP_VOICE_GOLOS_PIPELINE_FOUND` · `DESKTOP_VOICE_GOLOS_EQUIVALENT_SAME_WAV_RUNNER_READY` · `DESKTOP_VOICE_GOLOS_PARITY_DIFFS_LOGGED`

## Executive result

Same fixture WAV + same Parakeet int8 model checksum (`6139D2FA7E1B0860`) + GOLOS-equivalent VAD produces:

**`Solvan Computer Warehouse, Delmore, Submit.`**

This is the **model ceiling** for this WAV without glossary/postprocess. Counter must match this exactly. Strict domain terms **Southern** / **DEL MOD** are **not** produced by Parakeet on this audio — GOLOS-equivalent pipeline does not either.

Handy/GOLOS perceived quality for domain terms is **glossary/postprocess** (`glossary.rs` — DEL mod, SCW expansions), not raw Parakeet.

---

## Same-WAV replay (`wav_stt_replay`)

Fixture: `test/fixtures/desktop_voice_wav/scw_delmod_submit_real_2026_07_07.wav`  
Model: `golos_flutter/Release/models/parakeet` (identical SHA256 to Counter installed model)

| Pipeline | VAD | Peak norm | Raw transcript |
|----------|-----|-----------|----------------|
| **golos_equivalent** | 350ms pad + 700ms tail | **no** | **Solvan Computer Warehouse, Delmore, Submit.** |
| golos_equivalent_peak_norm | 350ms + 700ms tail | yes | Solvent computer warehouse, Delmore, Submit. |
| counter_legacy_vad | 200ms pad only | no | Sov and Computer Warehouse, Del Mall, Submit. |
| counter_helper_current (before fix) | golos VAD | yes | Solvent computer warehouse, Delmore, Submit. |
| no_vad | none | no | Solvent Computer Warehouse, Del Mall, Submit. |

**Baseline (old Counter live):** `Solvent computer warehouse still model submit`

Runner: `installer/windows/wav_stt_replay/`  
Script: `scripts/manual/compare_desktop_voice_wav_stt.ps1`

---

## Exact setting diffs (Counter vs GOLOS native)

| Setting | GOLOS (`transcribe.rs` / `audio.rs`) | Counter (after fix) | Counter (before) |
|---------|--------------------------------------|---------------------|------------------|
| Model | parakeet int8 ONNX | parakeet int8 ONNX | same |
| Model SHA256 (encoder) | 6139D2FA7E1B0860 | same | same |
| Inference lib | transcribe-rs 0.3 ParakeetParams::default() | same via backend-rs | same |
| Language (Parakeet) | none / model default | none | none |
| Whisper prompt | N/A for Parakeet | N/A | EN prompt patched (Whisper only) |
| VAD pad | 350 ms | 350 ms | 200 ms |
| VAD tail keep | 700 ms | 700 ms | 0 ms |
| VAD RMS threshold | 0.01 | 0.01 | 0.01 |
| Post-roll capture | 180+30 ms (live only) | 180+30 ms | 0 ms |
| STT peak normalization | **none** | **removed** | Dart normalizePcm16PeakForStt (harmful) |
| Resample | native→16k linear (`audio.rs`) | 16k capture fixed | 16k capture |
| Glossary after STT | yes (`glossary::correct_text`) | not counted for raw quality | postprocess path |
| Cloud STT | optional groq/salute | disabled for raw pass | bestQuality ladder |

---

## Counter changes (this pass)

1. **Removed STT peak normalization** — proven to degrade same-WAV output.
2. **GOLOS VAD** in helper build (already applied).
3. **GOLOS post-roll** in capture (live recordings; does not affect old fixture WAV).
4. **`wav_stt_replay`** benchmark harness for A/B without golos-backend.exe HTTP.
5. **Parity pass criterion** = match `golos_equivalent_raw_transcript` on same WAV.

---

## Strict domain pass — honest assessment

| Term | Required | GOLOS-equivalent raw | Strict pass |
|------|----------|----------------------|-------------|
| Southern Computer Warehouse | exact | Solvan Computer Warehouse | **NO** |
| DEL MOD | exact | Delmore | **NO** |
| Submit | present | Submit | **YES** |

**Conclusion:** Same-model parity is achievable and must match GOLOS-equivalent output. Strict Southern/DEL MOD on **this pre-fixture WAV** exceeds Parakeet raw capability. New live captures with post-roll may improve trailing phonemes; re-capture WAV after install for regression update.

GOLOS/Handy user-visible quality for SCW/DEL MOD likely includes **glossary** (`glossary.rs` CORRECTIONS + builtin GSA terms), not raw STT alone.

---

## Remaining unknowns

- Live GOLOS Tauri dictation on same WAV file (not HTTP) — replay uses identical math.
- Whether Handy uses a different runtime binary than `golos_flutter/Release/golos.exe` for Parakeet.
