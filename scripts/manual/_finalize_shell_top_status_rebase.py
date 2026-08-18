from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

app = ROOT / 'lib/app/shell/app_shell.dart'
text = app.read_text(encoding='utf-8')
old_import = "import 'package:counter/app/shell/shared/shell_offline_banner.dart';\n"
new_import = "import 'package:counter/app/shell/shared/shell_top_status_bars.dart';\n"
if old_import not in text:
    raise RuntimeError('old shell status import not found')
app.write_text(text.replace(old_import, new_import, 1), encoding='utf-8')

chrome = ROOT / 'lib/app/shell/shared/shell_chrome.dart'
text = chrome.read_text(encoding='utf-8')
old = '''                                  ShellTopStatusBars(\n                                    routeTab:\n                                        ShellDashboardBase.shellTabDiagnosticLabel(\n                                      shellPageIndex,\n                                    ),\n                                  ),\n'''
if old not in text:
    raise RuntimeError('ShellTopStatusBars routeTab call not found')
chrome.write_text(
    text.replace(old, '                                  const ShellTopStatusBars(),\n', 1),
    encoding='utf-8',
)

structure = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure.read_text(encoding='utf-8')
lines = doc.splitlines()
for index, line in enumerate(lines):
    if line.startswith('| `app/shell/shared/shell_offline_banner.dart` |'):
        lines[index] = '| `app/shell/shared/shell_top_status_bars.dart` | Presentation-only top status bars for Profile hydration and unfilled-time notices |'
        break
else:
    raise RuntimeError('old shell status structure row not found')
structure.write_text('\n'.join(lines) + ('\n' if doc.endswith('\n') else ''), encoding='utf-8')

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Shell top status naming cleanup [engineering]\n\n- Renamed obsolete `shell_offline_banner.dart` to `shell_top_status_bars.dart`; the widget is no longer an offline banner.\n- Removed the unused `routeTab` parameter from `ShellTopStatusBars`.\n- No UI or behavior changes.\n\n'''
if not text.startswith('## 2026-08-18 — Shell top status naming cleanup [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')
