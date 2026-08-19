# Windows STT helper artifact pipeline

The Windows installer must not keep the large `counter_stt_helper.exe` binary in Git.

Until the missing base Rust HTTP-sidecar source is recovered, the exact known-good helper is stored as the versioned GitHub Release asset declared in `stt_helper_artifact.json`. `prepare_stt_payload.ps1` downloads that asset and verifies its committed SHA-256 before copying it into the Windows release payload.

`stt_helper_src/` contains Counter-owned capture modules used by the historical build patcher, but it is not the complete base HTTP-sidecar source. `build_stt_helper_en.ps1` therefore remains a recovery/rebuild tool that requires an explicit external backend source root; it is not the production installer dependency.

When the complete base source is recovered, replace this artifact-only bridge with a source-reproducible CI build, verify behavioral parity, publish a new versioned helper asset, and keep the binary out of Git.
