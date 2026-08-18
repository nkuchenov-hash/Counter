from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

app_path = ROOT / 'lib/app/shell/app_shell.dart'
app = app_path.read_text(encoding='utf-8')
part_anchor = "part 'shared/shell_voice_routing.dart';\n"
part_line = "part 'shared/shell_voice_input.dart';\n"
if part_line not in app:
    if part_anchor not in app:
        raise RuntimeError('voice routing part anchor not found')
    app = app.replace(part_anchor, part_anchor + part_line, 1)
mixin_anchor = '        ShellVoiceRouting,\n        ShellVoiceIntegration,\n'
if '        ShellVoiceInput,\n' not in app:
    if mixin_anchor not in app:
        raise RuntimeError('voice routing mixin anchor not found')
    app = app.replace(
        mixin_anchor,
        '        ShellVoiceRouting,\n        ShellVoiceInput,\n        ShellVoiceIntegration,\n',
        1,
    )
app_path.write_text(app, encoding='utf-8')

chrome_path = ROOT / 'lib/app/shell/shared/shell_chrome.dart'
chrome = chrome_path.read_text(encoding='utf-8')
old_chrome = 'mixin ShellChrome on ShellLifecycle, ShellMoreMenu {'
new_chrome = 'mixin ShellChrome on ShellLifecycle, ShellMoreMenu, ShellVoiceInput {'
if old_chrome in chrome:
    chrome = chrome.replace(old_chrome, new_chrome, 1)
elif new_chrome not in chrome:
    raise RuntimeError('ShellChrome dependency anchor not found')
chrome_path.write_text(chrome, encoding='utf-8')

routing_path = ROOT / 'lib/app/shell/shared/shell_voice_routing.dart'
routing = routing_path.read_text(encoding='utf-8')
block_start = routing.find('  Future<void> retryVoiceWriteNewTask(')
block_end = routing.find('  Future<String?> desktopVoiceSubmitParsed(')
if block_start < 0 or block_end < 0 or block_end <= block_start:
    raise RuntimeError('generic voice submit block anchors not found')
routing = routing[:block_start] + routing[block_end:]
start_voice = routing.find('  Future<void> startVoiceInput() async {')
if start_voice < 0:
    raise RuntimeError('startVoiceInput anchor not found')
final_close = routing.rfind('\n}')
if final_close < start_voice:
    raise RuntimeError('routing final mixin close not found')
routing = routing[:start_voice] + routing[final_close:]
routing_path.write_text(routing, encoding='utf-8')

task_path = ROOT / 'lib/app/shell/shared/shell_task_actions.dart'
task = task_path.read_text(encoding='utf-8')
retry_method = '''  Future<void> retryVoiceWriteNewTask(\n    String title,\n    int? cid,\n    String pathTag, {\n    String? sourcePlanPocketRecordId,\n  }) async {\n    try {\n      final now = DatabaseService.getPlanetaryNow();\n      final serverId = await DatabaseService.instance.writeRecord(\n        timelineVoiceDateKey,\n        title,\n        categoryId: cid,\n        explicitStartTime: now,\n        sourcePlanPocketRecordId: sourcePlanPocketRecordId,\n      );\n      if (!mounted) return;\n      if (serverId == null || serverId.trim().isEmpty) {\n        showSyncFailedSnackBar(\n          onRetry: () => unawaited(\n            retryVoiceWriteNewTask(\n              title,\n              cid,\n              pathTag,\n              sourcePlanPocketRecordId: sourcePlanPocketRecordId,\n            ),\n          ),\n        );\n        return;\n      }\n      setState(() {\n        tasks.add(\n          Task(\n            title: title,\n            startTime: now,\n            endTime: null,\n            tags: [pathTag],\n            isActive: true,\n          ),\n        );\n        tasks.sort((a, b) => a.startTime.compareTo(b.startTime));\n      });\n      await saveTasks();\n    } catch (e) {\n      debugPrint('UI ERROR: $e');\n      if (mounted) {\n        showSyncFailedSnackBar(\n          onRetry: () => unawaited(\n            retryVoiceWriteNewTask(\n              title,\n              cid,\n              pathTag,\n              sourcePlanPocketRecordId: sourcePlanPocketRecordId,\n            ),\n          ),\n        );\n      }\n    }\n  }\n\n'''
if '  Future<void> retryVoiceWriteNewTask(' not in task:
    anchor = '  Future<void> startTaskFromInput() async {'
    if anchor not in task:
        raise RuntimeError('task action insertion anchor not found')
    task = task.replace(anchor, retry_method + anchor, 1)
task_path.write_text(task, encoding='utf-8')

structure_path = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure_path.read_text(encoding='utf-8')
lines = doc.splitlines()
for index, line in enumerate(lines):
    if line.startswith('| `app/shell/shared/shell_task_actions.dart` |'):
        lines[index] = '| `app/shell/shared/shell_task_actions.dart` | Shell task/record action orchestration, shared record-start retry and source-plan suggestion prompt presentation; preference/matching/link policy lives in Brain *(part)* |'
        break
else:
    raise RuntimeError('shell_task_actions structure row not found')
voice_row = '| `app/shell/shared/shell_voice_routing.dart` | Desktop voice command, hotkey/overlay submission and confirmation routing; generic FAB voice input is separate *(part)* |'
voice_input_row = '| `app/shell/shared/shell_voice_input.dart` | Generic FAB / VoiceInputSheet orchestration for Timeline record, Planning task and Backlog task submission *(part)* |'
for index, line in enumerate(lines):
    if line.startswith('| `app/shell/shared/shell_voice_routing.dart` |'):
        lines[index] = voice_row
        if voice_input_row not in lines:
            lines.insert(index + 1, voice_input_row)
        break
else:
    raise RuntimeError('shell_voice_routing structure row not found')
structure_path.write_text('\n'.join(lines) + ('\n' if doc.endswith('\n') else ''), encoding='utf-8')

changelog_path = ROOT / 'CHANGELOG.md'
changelog = changelog_path.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Shell generic voice-input boundary [engineering]\n\n- Split generic FAB/`VoiceInputSheet` submission into `shell_voice_input.dart`.\n- `shell_voice_routing.dart` now stays focused on desktop hotkey/overlay command routing and confirmation.\n- Shared failed record-start retry moved to `ShellTaskActions`, so desktop and generic voice siblings do not depend on each other.\n- Timeline/Planning/Backlog persistence and retry semantics are unchanged.\n\n'''
if not changelog.startswith('## 2026-08-18 — Shell generic voice-input boundary [engineering]'):
    changelog_path.write_text(entry + changelog, encoding='utf-8')
