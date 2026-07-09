# Desktop Voice — Handy Endpoint Parity Audit (2026-07-09)

**Status:** Counter df696fc live quiet failure is **STT-unrecoverable** on archived WAV (RMS ≈0.0135, missing “Southern”). This pass adds **real Windows endpoint diagnostics** and capture endpoint selection in the STT helper — **not** a claim that old audio recovers.

---

## Proven (from prior audit + df696fc offline bench)

| Area | Handy (2026-07-07 baseline) | Counter df696fc live |
|------|----------------------------|----------------------|
| Spoken phrase | Southern Computer Warehouse DEL MOD submit | same |
| Visible / replay transcript | Southern Computer Warehouse Del Mod, submit. | Computer Warehouse, DEL MOD, Submit. (**Southern missing**) |
| Processed WAV RMS | **≈0.058** (`scw_delmod_submit_handy_2026_07_07.wav`) | **≈0.0135** (~**4× quieter**) |
| Capture device label | Realtek mic array (48 kHz F32 stereo in log) | Realtek mic array (CPAL WASAPI F32) |
| STT engine (Counter today) | N/A (Handy uses Parakeet) | whisper-tiny primary |
| STT-only RMS gain fixes Southern on df696fc WAV | N/A | **No** — all variants tested offline |

**Markers:** `DESKTOP_VOICE_COUNTER_HANDY_DEVICE_DIFFS_LOGGED`, `DESKTOP_VOICE_LIVE_QUIET_FAILURE_REPRODUCED_OFFLINE`

---

## Handy endpoint / capture evidence inspected (2026-07-09)

| Source | Finding |
|--------|---------|
| `docs/reports/DESKTOP_VOICE_GOLOS_PARITY_AUDIT_2026-07-07.md` | Handy session: 48 kHz, 2 ch, **F32**, Realtek mic; postprocess off; saved `handy-1783437294.wav` |
| `%APPDATA%\com.pais.handy\recordings\` | Handy WAV fixtures present in repo (`scw_delmod_submit_handy_2026_07_07.wav`); live folder empty on dev machine today |
| `%LOCALAPPDATA%\com.pais.handy\logs\` | No `handy.log` on dev machine today — prior audit log cited from 2026-07-07 session |
| `C:\Users\nkuch\AppData\Local\Handy\handy.exe` | Installed v0.8.3 (pais) |

### Proven differences

- **Amplitude:** Handy WAV RMS ≈4× higher than Counter df696fc live quiet take on same phrase intent.
- **Transcript:** Handy retains “Southern”; Counter live + offline whisper on df696fc WAV does not.
- **Capture API:** Handy closed-source; Counter uses **CPAL/WASAPI raw F32** (likely **pre–OS AGC/enhancement** path).

### Not proven (unknowns)

- Whether Handy uses **console** vs **communications** default capture endpoint role.
- Whether Handy applies **driver AGC / noise suppression / mic boost** before save (no readable config on this machine).
- Whether Handy and Counter hit the **same MMDevice endpoint ID** at runtime.

**Markers:** `DESKTOP_VOICE_HANDY_ENDPOINT_CONFIG_INSPECTED`, `DESKTOP_VOICE_HANDY_CAPTURE_GAIN_OR_AGC_NOT_PROVEN`

---

## Counter changes (this pass)

1. **Helper `win_audio_endpoint.rs` + `capture.rs`:** MMDevice COM queries for console + communications defaults; logs endpoint id, volume, mute, mix format; auto role selection with cpal device name match + fallback.
2. **`GET /capture/device_diag`:** Smoke endpoint without mic open.
3. **Dart `DesktopVoiceCaptureEndpointPolicy`:** Posts `endpoint_role: auto` on `/capture/start`; parses endpoint fields into `last_attempt_diag.txt`.
4. **Capture gain experiment (off by default):** `COUNTER_CAPTURE_GAIN_EXPERIMENT=1` applies RMS target 0.058 on **STT copy only**; raw WAV unchanged. **Not** counted as parity fix; for **new captures only**.

**Markers:** `DESKTOP_VOICE_CORE_AUDIO_DEVICE_DIAGNOSTICS`, `DESKTOP_VOICE_ENDPOINT_ID_LOGGED`, `DESKTOP_VOICE_ENDPOINT_VOLUME_LOGGED`, `DESKTOP_VOICE_DEFAULT_CONSOLE_DEVICE_LOGGED`, `DESKTOP_VOICE_DEFAULT_COMMUNICATIONS_DEVICE_LOGGED`, `DESKTOP_VOICE_CAPTURE_MIX_FORMAT_LOGGED`, `DESKTOP_VOICE_MIC_BOOST_OR_EFFECTS_CHECKED`, `DESKTOP_VOICE_CAPTURE_ENDPOINT_SELECTED`, `DESKTOP_VOICE_CAPTURE_ENDPOINT_ROLE_SELECTED`, `DESKTOP_VOICE_CAPTURE_ENDPOINT_FALLBACK_READY`, `DESKTOP_VOICE_CAPTURE_GAIN_EXPERIMENT_READY`, `DESKTOP_VOICE_CAPTURE_GAIN_NOT_COUNTED_AS_RAW_CAPTURE_PARITY`, `DESKTOP_VOICE_RAW_WAV_UNCHANGED`

---

## Next meaningful proof

After **installed smoke** shows non-stub endpoint fields, one live capture:

> “Southern Computer Warehouse DEL MOD submit”

Compare **raw RMS / peak / endpoint_role / endpoint_volume** against Handy baseline (0.058 RMS target). Do **not** expect df696fc archived WAV to improve.
