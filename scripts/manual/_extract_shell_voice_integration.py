from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

routing_path = ROOT / 'lib/app/shell/shared/shell_voice_routing.dart'
routing = routing_path.read_text(encoding='utf-8')
start = routing.find('  Future<void> refreshDesktopTrayMenu() async {')
first_keep = routing.find('  Future<bool> runDesktopVoiceAcceptanceCommand(', start)
if start == -1 or first_keep == -1:
    raise RuntimeError('Cannot locate desktop tray/hotkey pre-routing block')
routing = routing[:start] + routing[first_keep:]
reattach = routing.find('  Future<bool> reattachDesktopVoiceHotkey() async {')
second_keep = routing.find('  Future<void> retryVoiceWriteNewTask(', reattach)
if reattach == -1 or second_keep == -1:
    raise RuntimeError('Cannot locate desktop hotkey reattach block')
routing = routing[:reattach] + routing[second_keep:]
routing_path.write_text(routing, encoding='utf-8')

lifecycle_path = ROOT / 'lib/app/shell/shared/shell_lifecycle.dart'
lifecycle = lifecycle_path.read_text(encoding='utf-8')
old = 'mixin ShellLifecycle on ShellTabHost, ShellVoiceRouting {'
new = 'mixin ShellLifecycle on ShellTabHost, ShellVoiceIntegration {'
if old in lifecycle:
    lifecycle = lifecycle.replace(old, new, 1)
elif new not in lifecycle:
    raise RuntimeError('ShellLifecycle dependency anchor not found')
lifecycle_path.write_text(lifecycle, encoding='utf-8')

app_path = ROOT / 'lib/app/shell/app_shell.dart'
app = app_path.read_text(encoding='utf-8')
old_parts = "part 'shared/shell_voice_routing.dart';\npart 'shared/shell_lifecycle.dart';"
new_parts = "part 'shared/shell_voice_routing.dart';\npart 'shared/shell_voice_integration.dart';\npart 'shared/shell_lifecycle.dart';"
if old_parts in app:
    app = app.replace(old_parts, new_parts, 1)
elif new_parts not in app:
    raise RuntimeError('Voice part anchor not found')
old_mixins = '        ShellMoreMenu,\n        ShellVoiceRouting,\n        ShellLifecycle,'
new_mixins = '        ShellMoreMenu,\n        ShellVoiceRouting,\n        ShellVoiceIntegration,\n        ShellLifecycle,'
if old_mixins in app:
    app = app.replace(old_mixins, new_mixins, 1)
elif new_mixins not in app:
    raise RuntimeError('Voice mixin anchor not found')
app_path.write_text(app, encoding='utf-8')

structure = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure.read_text(encoding='utf-8')
replacement = (
    '| `app/shell/shared/shell_voice_routing.dart` | Voice command/STT routing and submit flows *(part)* |\n'
    '| `app/shell/shared/shell_voice_integration.dart` | Desktop tray/global-hotkey attachment and reattachment at the shell boundary *(part)* |'
)
if replacement not in doc:
    for anchor in (
        '| `app/shell/shared/shell_voice_routing.dart` | Voice hotkey + submit routing *(part)* |',
        '| `app/shell/shared/shell_voice_routing.dart` | Voice input / STT / desktop voice routing *(part)* |',
    ):
        if anchor in doc:
            doc = doc.replace(anchor, replacement, 1)
            break
    else:
        raise RuntimeError('APP_STRUCTURE voice routing row not found')
structure.write_text(doc, encoding='utf-8')

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Shell desktop voice integration boundary [engineering]\n\n- Split desktop tray/global-hotkey attach/reattach lifecycle from `shell_voice_routing.dart` into `shell_voice_integration.dart`.\n- `ShellVoiceRouting` remains responsible for voice command/STT routing and submission; the integration mixin only connects desktop voice infrastructure to shell lifecycle/chrome.\n- Voice behavior, hotkey semantics, tray actions, and recognition flow are unchanged.\n\n'''
if not text.startswith('## 2026-08-18 — Shell desktop voice integration boundary [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')
