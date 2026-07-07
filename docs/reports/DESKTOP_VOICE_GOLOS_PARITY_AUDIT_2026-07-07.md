# Desktop Voice GOLOS Parity Audit — 2026-07-07

**Markers:** `DESKTOP_VOICE_GOLOS_PIPELINE_FOUND` · `DESKTOP_VOICE_GOLOS_PARITY_DIFFS_LOGGED` · `DESKTOP_VOICE_COUNTER_PIPELINE_MATCHED_TO_GOLOS`

## Summary

Counter Desktop Voice and GOLOS/Handy share the same **backend-rs** inference stack (Parakeet / Whisper local engines). Recognition quality gaps on the failing SCW command were traced to **audio capture endpointing** and **VAD trim**, not a different model file. This pass aligns Counter with GOLOS-native settings and separates raw STT quality from alias/postprocess safety.

---

## GOLOS Pipeline (found)

**Source:** `C:\Users\nkuch\Development\Apps\golos_flutter\src-tauri\src\`

| Setting | GOLOS value | File |
|---------|-------------|------|
| Manual stop post-roll | 180 ms | `audio.rs` `MANUAL_STOP_POST_ROLL_MS` |
| Stream drain after stop | 30 ms | `audio.rs` `STREAM_DRAIN_MS` |
| VAD pad | 350 ms | `transcribe.rs` `VAD_PAD_MS` |
| VAD tail keep | 700 ms | `transcribe.rs` `VAD_TAIL_KEEP_MS` |
| VAD window | 30 ms | `transcribe.rs` |
| VAD RMS threshold | 0.01 | `transcribe.rs` |
| Sample rate (inference) | 16 kHz mono | backend-rs |
| Partial interval | ~200–250 ms | GOLOS incremental path |
| Pre-roll (partials) | ~700 ms | GOLOS audio buffer |

**Prebuilt GOLOS helper on machine:** not found (`golos-backend.exe` absent). Same-WAV GOLOS-side transcript comparison deferred; settings comparison is from source.

`DESKTOP_VOICE_GOLOS_PIPELINE_FOUND`

---

## Counter Pipeline (before)

| Setting | Counter (before) | File |
|---------|------------------|------|
| Post-roll at stop | **0 ms** | `desktop_voice_audio_capture.dart` |
| VAD pad | **200 ms** | backend-rs `main.rs` |
| VAD tail keep | **none** | backend-rs |
| STT mode default | bestQuality (cloud ladder) | `desktop_voice_settings.dart` |
| Command text source | postprocessed (alias repair) | `desktop_stt_orchestrator.dart` |
| Partial timer | 400 ms | `desktop_voice_audio_capture.dart` |
| Capture | PCM16 16 kHz mono | `record` package |
| Helper | `counter_stt_helper.exe` from backend-rs | EN prompt patch in build script |
| Model | Parakeet (same backend-rs weights path) | `%LOCALAPPDATA%\Counter\stt_models` |

---

## Differences (root cause)

1. **Missing post-roll (180+30 ms)** — Counter stopped mic immediately; trailing “DEL MOD submit” phonemes were clipped before WAV save.
2. **Weaker VAD** — 200 ms pad, no 700 ms tail preservation; final inference saw truncated audio vs GOLOS.
3. **Quality counted postprocess** — alias/glossary repair masked raw Parakeet errors in acceptance criteria.
4. **Cloud STT ladder** — not used by GOLOS; removed from default transcribe path for this pass.

`DESKTOP_VOICE_GOLOS_PARITY_DIFFS_LOGGED`

---

## Changes Made to Counter

| Change | Location |
|--------|----------|
| GOLOS post-roll 180+30 ms before mic stop | `lib/core/services/desktop_voice_audio_capture.dart` |
| VAD 350 ms pad + 700 ms tail keep in helper build | `installer/windows/build_stt_helper_en.ps1` |
| Raw STT quality mode; postprocess logged only | `lib/core/services/desktop_stt_quality_evaluation.dart`, `desktop_stt_orchestrator.dart` |
| Default STT mode → fastLocal (local Parakeet) | `desktop_voice_settings.dart` |
| Parent-only + unresolved token block | `desktop_voice_command_normalize.dart` |
| Real WAV fixture + golden manifest | `test/fixtures/desktop_voice_wav/` |
| WAV replay benchmark | `lib/core/services/desktop_voice_wav_stt_benchmark.dart`, `scripts/manual/benchmark_desktop_voice_stt.ps1` |

`DESKTOP_VOICE_COUNTER_PIPELINE_MATCHED_TO_GOLOS`

---

## Same-WAV Test

| Field | Value |
|-------|-------|
| WAV | `test/fixtures/desktop_voice_wav/scw_delmod_submit_real_2026_07_07.wav` |
| Source | `%LOCALAPPDATA%\Counter\voice_samples\latest_command.wav` |
| Baseline raw STT | `Solvent computer warehouse still model submit` |
| Expected | `Southern Computer Warehouse DEL MOD submit` |

Run: `scripts/manual/benchmark_desktop_voice_stt.ps1` (requires rebuilt helper).

`DESKTOP_VOICE_SAME_WAV_COMPARISON_READY`

---

## Remaining Unknowns

- Live GOLOS binary transcript on identical WAV (no prebuilt helper on disk).
- Whether GOLOS native resampling (device-native → 16 kHz) vs Counter fixed 16 kHz capture affects this specific mic/device.
- Parakeet vs Whisper selection in GOLOS for short commands (Counter production uses Parakeet).

---

## Quality Evaluation Contract (this pass)

```
stt_quality_mode=raw_transcript_evaluation
alias_postprocess_used_for_quality=false
```

Raw pass criteria: `raw_model_text` / `final_stt_text` only — not `postprocessed_text` or parser repair.

Markers: `DESKTOP_VOICE_RAW_STT_QUALITY_EVALUATION` · `DESKTOP_VOICE_POSTPROCESS_NOT_COUNTED_AS_STT_QUALITY` · `DESKTOP_VOICE_RAW_FINAL_STT_TEXT_LOGGED`
