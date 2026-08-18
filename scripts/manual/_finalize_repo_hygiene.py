#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

DELETE_PATHS = [
    "lib/app/shell/shared/settings_page.dart",
    "lib/core/navigation/shell_side_navigation.dart",
    "lib/core/widgets/plan_card/plan_card_controls.dart",
    "lib/core/widgets/plan_card/plan_card_geometry.dart",
    "lib/core/widgets/plan_card/plan_card_metrics.dart",
    "lib/core/widgets/plan_card/plan_card_sections.dart",
    "lib/core/widgets/plan_card/plan_time_card_density.dart",
    "lib/data/local_sync/plan_create_outbox.dart",
    "lib/features/profile/settings/settings_page.dart",
    "lib/shared/voice/recognition/desktop_voice_error_classification.dart",
    "lib/features/notes/notes_library_page.dart",
    "lib/features/voice/desktop_voice_command_panel.dart",
    "lib/features/shared/notes_editor/notes_editor_launcher.dart",
    "lib/features/shared/notes_editor/notes_editor_sheet.dart",
    "lib/features/lists/lists_inline_add.dart",
    "lib/shared/voice/platforms/desktop/desktop_voice_window_flags.dart",
    "lib/shared/voice/platforms/desktop/desktop_voice_benchmark_service.dart",
    "lib/core/widgets/notes/notes.dart",
    "lib/core/widgets/notes/notes_context_row.dart",
    "lib/core/widgets/notes/notes_editor_surface.dart",
    "lib/core/widgets/notes/notes_markdown.dart",
    "lib/core/widgets/notes/notes_save_status.dart",
    "lib/core/widgets/notes/notes_toolbar.dart",
    "lib/core/widgets/notes/note_preview_card.dart",
    "test/fixtures/desktop_voice_wav/scw_delmod_submit_counter_native_raw_2026_07_08.wav",
    "test/fixtures/desktop_voice_wav/scw_delmod_submit_counter_native_raw_2026_07_08_f69fb1b.wav",
]

VANISHED_DIRS = [
    "lib/core/widgets/notes/",
    "lib/core/widgets/plan_card/",
    "lib/features/shared/notes_editor/",
]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path: str, body: str) -> None:
    (ROOT / path).write_text(body, encoding="utf-8", newline="\n")


def replace_required(path: str, old: str, new: str) -> None:
    body = read(path)
    if old not in body:
        raise SystemExit(f"required anchor missing in {path}: {old[:120]!r}")
    write(path, body.replace(old, new))


# Delete only files already proven unreachable by exact import/export graph or unreferenced fixture scan.
for rel in DELETE_PATHS:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"delete target unexpectedly missing: {rel}")
    p.unlink()

# The retained-product watchlist has been fully resolved: dead entries were deleted;
# LifeCard + confirm dialog were proven production-reachable and therefore are not watchlist items.
evidence = read("scripts/manual/structure_evidence_index.py")
start = evidence.index("WATCHLIST_PATHS: dict[str, str] = {")
end_marker = "# Test/bench-only modules that are not production-reachable but are tooling-required."
end = evidence.index(end_marker, start)
evidence = (
    evidence[:start]
    + "WATCHLIST_PATHS: dict[str, str] = {}\n\n"
    + evidence[end:]
)
write("scripts/manual/structure_evidence_index.py", evidence)

# Live navigation: remove the obsolete outbox alias row. Historical reports remain historical.
nav = read("AGENT_NAVIGATION.md")
nav_lines = [
    line for line in nav.splitlines()
    if "lib/data/local_sync/plan_create_outbox.dart" not in line
]
write("AGENT_NAVIGATION.md", "\n".join(nav_lines).rstrip() + "\n")

# Product inventory: point mobile/web generic voice and desktop voice at their current owners.
product = read("docs/website/PRODUCT_INVENTORY.md")
product = product.replace(
    "`lib/shared/voice/ui/voice_input_sheet.dart`; `lib/app/shell/shared/shell_voice_routing.dart`; `docs/ARCHITECTURE.md` § Voice Input Protocol",
    "`lib/shared/voice/ui/voice_input_sheet.dart`; `lib/app/shell/shared/shell_voice_input.dart`; `docs/ARCHITECTURE.md` § Voice Input Protocol",
)
product = product.replace(
    "`lib/data/voice/voice_command_parser.dart`, `lib/features/voice/desktop_voice_command_panel.dart`; `lib/shared/voice/platforms/desktop/desktop_voice_hotkey.dart`; `kDesktopVoiceCommandEnabled` default **false**",
    "`lib/data/voice/voice_command_parser.dart`, `lib/features/voice/desktop_voice_widget.dart`; `lib/shared/voice/platforms/desktop/desktop_voice_hotkey.dart`; `kDesktopVoiceCommandEnabled` default **false**",
)
write("docs/website/PRODUCT_INVENTORY.md", product)

# APP_STRUCTURE is the manually maintained canonical map. Remove rows for deleted files
# and rows for directories that disappear completely after this cleanup.
structure = read("docs/APP_STRUCTURE.md")
needles = set()
for rel in DELETE_PATHS:
    if rel.endswith(".dart"):
        needles.add(rel)
        needles.add(rel.removeprefix("lib/"))
for rel in VANISHED_DIRS:
    needles.add(rel)
    needles.add(rel.removeprefix("lib/"))
kept: list[str] = []
for line in structure.splitlines():
    if any(needle in line for needle in needles):
        continue
    kept.append(line)
write("docs/APP_STRUCTURE.md", "\n".join(kept).rstrip() + "\n")

# Remove workstation-specific absolute paths from STT build tooling without pretending
# the helper is reproducible in CI. The tracked helper remains required until that source/artifact
# dependency is solved.
builder = read("installer/windows/build_stt_helper_en.ps1")
builder = builder.replace(
    "$ErrorActionPreference = 'Stop'\n$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent\n$backendSrcRoot = 'C:\\Users\\nkuch\\Development\\Apps\\_cleanup_backup_20260615_110428\\backend-rs'",
    "param(\n    [string]$BackendSourceRoot = $env:COUNTER_STT_BACKEND_ROOT\n)\n\n$ErrorActionPreference = 'Stop'\n$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent\nif ([string]::IsNullOrWhiteSpace($BackendSourceRoot)) {\n    throw 'STT backend source is required. Pass -BackendSourceRoot <path> or set COUNTER_STT_BACKEND_ROOT.'\n}\n$backendSrcRoot = [System.IO.Path]::GetFullPath($BackendSourceRoot)",
)
if "_cleanup_backup_20260615_110428" in builder:
    raise SystemExit("hardcoded STT backend workstation path still present")
write("installer/windows/build_stt_helper_en.ps1", builder)

payload = read("installer/windows/prepare_stt_payload.ps1")
payload = payload.replace(
    "$ErrorActionPreference = 'Stop'",
    "param(\n    [string]$ModelsSourceRoot = $env:COUNTER_STT_MODELS_ROOT,\n    [string]$HelperSource = ''\n)\n\n$ErrorActionPreference = 'Stop'",
    1,
)
old_sources = """# Production GOLOS backend (parakeet-capable). EN whisper patch optional for debug.\n\n$enHelper = Join-Path $PSScriptRoot 'stt_helper_build\\counter_stt_helper.exe'\n\n$backendSrc = if (Test-Path $enHelper) { $enHelper } else {\n\n    'C:\\Users\\nkuch\\Development\\Apps\\_cleanup_backup_20260615_110428\\Release\\backend\\golos-backend.exe'\n\n}\n\n$parakeetSrc = 'C:\\Users\\nkuch\\Development\\Apps\\golos_flutter\\Release\\models\\parakeet'\n\n$whisperSrc = 'C:\\Users\\nkuch\\Development\\Apps\\golos_flutter\\Release\\models\\whisper-tiny'\n"""
new_sources = """# Production GOLOS helper is currently retained in-repo because the old HTTP-sidecar\n# source is not yet reproducibly built by Counter CI. Models stay external build inputs.\n$trackedHelper = Join-Path $PSScriptRoot 'stt_helper_build\\counter_stt_helper.exe'\n$backendSrc = if (-not [string]::IsNullOrWhiteSpace($HelperSource)) {\n    [System.IO.Path]::GetFullPath($HelperSource)\n} else {\n    $trackedHelper\n}\nif ([string]::IsNullOrWhiteSpace($ModelsSourceRoot)) {\n    throw 'STT models source is required. Pass -ModelsSourceRoot <path> or set COUNTER_STT_MODELS_ROOT.'\n}\n$modelsRoot = [System.IO.Path]::GetFullPath($ModelsSourceRoot)\n$parakeetSrc = Join-Path $modelsRoot 'parakeet'\n$whisperSrc = Join-Path $modelsRoot 'whisper-tiny'\n"""
if old_sources not in payload:
    raise SystemExit("prepare_stt_payload source anchor missing")
payload = payload.replace(old_sources, new_sources)
if "C:\\Users\\nkuch\\Development\\Apps" in payload:
    raise SystemExit("hardcoded STT payload workstation path still present")
write("installer/windows/prepare_stt_payload.ps1", payload)

# Deploy doc must state the real STT build inputs rather than imply clean-runner reproducibility.
deploy = read("docs/DEPLOY.md")
deploy = deploy.replace(
    "4. *(Recommended)* `powershell -ExecutionPolicy Bypass -File installer\\windows\\build_stt_helper_en.ps1`\n5. `powershell -ExecutionPolicy Bypass -File installer\\windows\\prepare_stt_payload.ps1`",
    "4. *(Only when rebuilding the helper)* `powershell -ExecutionPolicy Bypass -File installer\\windows\\build_stt_helper_en.ps1 -BackendSourceRoot <path-to-http-sidecar-source>` (or set `COUNTER_STT_BACKEND_ROOT`)\n5. `powershell -ExecutionPolicy Bypass -File installer\\windows\\prepare_stt_payload.ps1 -ModelsSourceRoot <path-to-models>` (or set `COUNTER_STT_MODELS_ROOT`)",
)
ci_anchor = "2. Download **`CounterSetup`** artifact\n3. Run **`CounterSetup.exe`**"
ci_replacement = "2. Download **`CounterSetup`** artifact\n3. The clean-runner workflow does **not** provision the external offline STT model directories yet; treat the artifact as voice-complete only when the release payload has been prepared with the model source contract above.\n4. Run **`CounterSetup.exe`**"
if ci_anchor not in deploy:
    raise SystemExit("DEPLOY CI anchor missing")
deploy = deploy.replace(ci_anchor, ci_replacement)
write("docs/DEPLOY.md", deploy)

# Changelog entry for the hygiene pass.
changelog = read("CHANGELOG.md")
entry = """## 2026-08-18 — Repository hygiene closure [engineering]\n\n- Removed unreachable compatibility aliases, superseded Notes/desktop-voice UI, and two unreferenced raw voice fixtures; active runtime/design-system owners are unchanged.\n- Resolved the retained-product watchlist: dead entries were deleted, while `LifeCard` and `showConfirmDialog` were proven production-reachable and reclassified as normal code.\n- Added `repository_hygiene.py` to CI so orphan pure re-exports and new unapproved huge tracked binaries fail automatically.\n- Kept the tracked `counter_stt_helper.exe` explicitly because desktop voice still requires that HTTP sidecar; removed developer-machine absolute paths from its build/payload scripts and documented the remaining external model/source inputs.\n\n"""
if not changelog.startswith("## 2026-08-18 — Repository hygiene closure"):
    changelog = entry + changelog
write("CHANGELOG.md", changelog)

print(f"deleted_files={len(DELETE_PATHS)}")
print("repo_hygiene_finalize: applied")
