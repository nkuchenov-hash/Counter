from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def patch(path: str, replacements: list[tuple[str, str]]) -> None:
    p = ROOT / path
    text = p.read_text(encoding='utf-8')
    for old, new in replacements:
        if old not in text:
            raise RuntimeError(f'missing semantic parity anchor in {path}: {old[:80]}')
        text = text.replace(old, new, 1)
    p.write_text(text, encoding='utf-8')


patch(
    'AGENTS.md',
    [
        (
            'Active-tab Voice routing stays in `lib/app/shell/shared/shell_voice_routing.dart`.',
            'Generic active-tab FAB/VoiceInputSheet routing lives in `lib/app/shell/shared/shell_voice_input.dart`; desktop overlay/command routing lives in `shell_voice_routing.dart`; tray/global-hotkey attachment lives in `shell_voice_integration.dart`.',
        ),
        (
            'Pending sync and auth-paused sync belong in the existing offline/sync banner paths, not per-row noise.',
            'Pending sync and auth-paused sync belong in `lib/app/shell/shared/offline_sync_status_bar.dart` via `ShellTopStatusBars`, not per-row noise.',
        ),
        (
            '`CategoryChip`, `TagQuickPickStrip`, and related shared chip components are current shared/legacy-safe paths; future canonical chip work must follow `docs/DESIGN_SYSTEM.md`.',
            '`CategoryChip`, `TagChip`, and `TagQuickPickStrip` currently live in the canonical shared widget file `lib/core/widgets/chip_component.dart`; future API renaming still follows `docs/DESIGN_SYSTEM.md`.',
        ),
        (
            'Planning Time mode uses profile-projected wall time, 5-minute snap/min duration, and no out-of-visible-range fallback bucket.',
            'Planning Time mode uses profile-projected wall time, a 10-minute minimum scheduled duration (`kPlanTimeMinDurationMinutes`), and no out-of-visible-range fallback bucket; interaction snapping must follow the current Time View controller policy rather than a duplicated doc constant.',
        ),
        (
            'For structure/import-boundary work, also consider:\n\n```powershell\n.\\scripts\\audit\\architecture_guard.ps1\n.\\scripts\\audit\\architecture_guard.ps1 -Strict\n```',
            'For structure/import-boundary work, also run:\n\n```powershell\n.\\scripts\\audit\\architecture_guard.ps1 -Strict\npython scripts/audit/documentation_parity.py\n```',
        ),
    ],
)

patch(
    'docs/DESIGN_SYSTEM.md',
    [
        (
            '- Current shared feature components: `CategoryChip`, `TagQuickPickStrip`, `CategoryBreadcrumb`.',
            '- Current shared chip implementation: `CategoryChip`, `TagChip`, `TagQuickPickStrip`, and `CategoryBreadcrumb` in `lib/core/widgets/chip_component.dart`.',
        ),
    ],
)
