from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

app = ROOT / 'lib/app/shell/app_shell.dart'
text = app.read_text(encoding='utf-8')
anchor = "import 'package:counter/data/database_service.dart';\n"
imports = (
    anchor
    + "import 'package:counter/data/health/sleep_foreground_reconcile_service.dart';\n"
    + "import 'package:counter/data/records/unfilled_time_gap_service.dart';\n"
)
if 'sleep_foreground_reconcile_service.dart' not in text:
    if anchor not in text:
        raise RuntimeError('app_shell database import not found')
    text = text.replace(anchor, imports, 1)
app.write_text(text, encoding='utf-8')

lifecycle = ROOT / 'lib/app/shell/shared/shell_lifecycle.dart'
text = lifecycle.read_text(encoding='utf-8')
start_anchor = '    DesktopVoiceSmokeBridge.startPolling();\n'
if 'SleepForegroundReconcileService.instance.start();' not in text:
    if start_anchor not in text:
        raise RuntimeError('shell lifecycle startup anchor not found')
    text = text.replace(
        start_anchor,
        start_anchor
        + '\n    SleepForegroundReconcileService.instance.start();\n'
        + '    unawaited(UnfilledTimeGapService.instance.start());\n',
        1,
    )
if 'SleepForegroundReconcileService.instance.stop();' not in text:
    dispose_anchor = '  void disposeShellLifecycle() {\n'
    if dispose_anchor not in text:
        raise RuntimeError('shell lifecycle dispose anchor not found')
    text = text.replace(
        dispose_anchor,
        dispose_anchor + '    SleepForegroundReconcileService.instance.stop();\n',
        1,
    )
lifecycle.write_text(text, encoding='utf-8')

structure = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure.read_text(encoding='utf-8')
lines = doc.splitlines()
health_row = '| `health/sleep_foreground_reconcile_service.dart` | App-lifecycle sleep ingestion coordinator: device-first then cloud reconciliation on startup/resume; UI does not own sync lifecycle |'
if health_row not in lines:
    for index, line in enumerate(lines):
        if line.startswith('| `health/health_sleep_sync_service.dart` |'):
            lines.insert(index + 1, health_row)
            break
    else:
        raise RuntimeError('health sync structure row not found')
for index, line in enumerate(lines):
    if line.startswith('| `app/shell/shared/shell_offline_banner.dart` |'):
        lines[index] = '| `app/shell/shared/shell_offline_banner.dart` | Presentation-only top status bars; no Health/Cloud ingestion side effects |'
        break
else:
    raise RuntimeError('shell status-bar structure row not found')
structure.write_text('\n'.join(lines) + ('\n' if doc.endswith('\n') else ''), encoding='utf-8')

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Sleep foreground lifecycle ownership [engineering]\n\n- `ShellTopStatusBars` is presentation-only again; Health Connect/cloud ingestion no longer starts from a UI widget.\n- Added `SleepForegroundReconcileService` under `data/health` for device-first then cloud reconciliation on startup/resume.\n- Shell lifecycle starts/stops the coordinator and starts unfilled-time tracking; sync semantics are unchanged.\n\n'''
if not text.startswith('## 2026-08-18 — Sleep foreground lifecycle ownership [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')
