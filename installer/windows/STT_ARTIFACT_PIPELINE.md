# Windows STT helper artifact pipeline

The Windows installer must not keep the large `counter_stt_helper.exe` binary in Git.

Until the missing base Rust HTTP-sidecar source is recovered, the exact known-good helper is stored as the immutable versioned GitHub Release asset declared in `stt_helper_artifact.json`. `prepare_stt_payload.ps1` downloads that asset and verifies its committed SHA-256 and byte size before copying it into the Windows release payload. Repository hygiene rejects both a reintroduced tracked helper executable and an invalid/missing manifest.

Current pinned helper: release `counter-stt-helper-artifact-v1`, asset `counter_stt_helper.exe`, 34,587,136 bytes, SHA-256 `eb420c943d564152854c71632ef6e512e19f9a46a23de1efb72fd14b44341f21`. The manifest is the machine-readable source of truth; this line is human-facing documentation.

`stt_helper_src/` contains Counter-owned capture modules used by the historical build patcher, but it is not the complete base HTTP-sidecar source. `build_stt_helper_en.ps1` therefore remains a recovery/rebuild tool that requires an explicit external backend source root; it is not the production installer dependency.

Parakeet and Whisper model directories are separate external build inputs. `prepare_stt_payload.ps1` requires `-ModelsSourceRoot` or `COUNTER_STT_MODELS_ROOT` when producing the full offline-voice payload. The manual GitHub Windows build does not currently have those model files as a repository or CI artifact, so it must not be described as producing a complete offline-model payload until a pinned model-artifact source is added. This is independent from the helper-binary repository hygiene solved here.

When the complete base helper source is recovered, replace this artifact-only bridge with a source-reproducible CI build, verify behavioral parity, publish a new immutable versioned helper asset, and keep the binary out of Git.
