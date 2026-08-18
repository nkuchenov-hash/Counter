from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

app = ROOT / 'lib/app/shell/app_shell.dart'
text = app.read_text(encoding='utf-8')
text = text.replace(
    "import 'package:counter/shared/voice/recognition/speech_engine_handle.dart';\n",
    "import 'package:counter/shared/voice/recognition/speech_engine_controller.dart';\n",
    1,
)
text = text.replace("import 'package:speech_to_text/speech_to_text.dart' as stt;\n", '', 1)
old_state = '''  final ShellLayoutController shellLayout = ShellLayoutController();\n\n  stt.SpeechToText? speech;\n  SpeechEngineHandle? speechHandle;\n  bool speechReady = false;\n\n  /// Last engine init failure (shown with [speech_unavailable] snackbar detail).\n  String? speechLastInitError;\n  bool isVoiceListening = false;\n  void Function(String)? speechStatusCallback;\n'''
new_state = '''  final ShellLayoutController shellLayout = ShellLayoutController();\n  final SpeechEngineController speechEngine = SpeechEngineController();\n  bool isVoiceListening = false;\n'''
if old_state not in text:
    raise RuntimeError('shell STT state block not found')
text = text.replace(old_state, new_state, 1)
for forbidden in ('stt.SpeechToText?', 'SpeechEngineHandle?', 'speechLastInitError;', 'speechStatusCallback;'):
    if forbidden in text:
        raise RuntimeError(f'app shell still owns STT lifecycle token: {forbidden}')
app.write_text(text, encoding='utf-8')

routing = ROOT / 'lib/app/shell/shared/shell_voice_routing.dart'
text = routing.read_text(encoding='utf-8')
start_marker = '  Future<void> ensureSpeechReady() async {'
end_marker = '  Future<String?> desktopVoiceSubmitParsed('
if start_marker not in text or end_marker not in text:
    raise RuntimeError('STT lifecycle method block markers not found')
start = text.index(start_marker)
end = text.index(end_marker, start)
text = text[:start] + text[end:]
text = text.replace('    await ensureSpeechReady();\n', '    await speechEngine.ensureReady();\n', 1)
text = text.replace('    if (!speechReady) {\n', '    if (!speechEngine.ready) {\n', 1)
text = text.replace(
    '      final detail = speechLastInitError?.trim();\n',
    '      final detail = speechEngine.lastInitError?.trim();\n',
    1,
)
old_handle = '''    speechHandle ??= SpeechEngineHandle(speech!);\n    speechHandle!.speech = speech!;\n'''
if old_handle not in text:
    raise RuntimeError('voice sheet speech handle block not found')
text = text.replace(old_handle, '    final speechHandle = speechEngine.handle;\n', 1)
old_sheet = '''          speechHandle: speechHandle!,\n          setSpeechStatusCallback: (cb) {\n            if (mounted) setState(() => speechStatusCallback = cb);\n          },\n          onSpeechEngineHardReset: speechEngineHardReset,\n'''
new_sheet = '''          speechHandle: speechHandle,\n          setSpeechStatusCallback: speechEngine.setStatusCallback,\n          onSpeechEngineHardReset: speechEngine.hardReset,\n'''
if old_sheet not in text:
    raise RuntimeError('VoiceInputSheet STT callback block not found')
text = text.replace(old_sheet, new_sheet, 1)
text = text.replace(
    '    setState(() => speechStatusCallback = null);\n',
    '    speechEngine.setStatusCallback(null);\n',
    1,
)
for forbidden in (
    'speechReady',
    'speechLastInitError',
    'speechStatusCallback',
    'initializeSpeechInstance',
    'logSttLocalesBestEffortWeb',
    'speechEngineHardReset',
):
    if forbidden in text:
        raise RuntimeError(f'shell routing still owns STT lifecycle token: {forbidden}')
routing.write_text(text, encoding='utf-8')

lifecycle = ROOT / 'lib/app/shell/shared/shell_lifecycle.dart'
text = lifecycle.read_text(encoding='utf-8')
if 'unawaited(ensureSpeechReady());' not in text:
    raise RuntimeError('shell lifecycle STT prewarm anchor not found')
text = text.replace(
    '      unawaited(ensureSpeechReady());\n',
    '      unawaited(speechEngine.ensureReady());\n',
    1,
)
if 'unawaited(speechEngine.dispose());' not in text:
    dispose = '  void disposeShellLifecycle() {\n'
    if dispose not in text:
        raise RuntimeError('shell lifecycle dispose anchor not found')
    text = text.replace(dispose, dispose + '    unawaited(speechEngine.dispose());\n', 1)
if 'SleepForegroundReconcileService.instance.start();' not in text:
    raise RuntimeError('Sleep lifecycle start wiring was lost')
if 'SleepForegroundReconcileService.instance.stop();' not in text:
    raise RuntimeError('Sleep lifecycle stop wiring was lost')
lifecycle.write_text(text, encoding='utf-8')

structure = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure.read_text(encoding='utf-8')
lines = doc.splitlines()
controller_row = '| `speech_engine_controller.dart` | Shared SpeechToText instance lifecycle: initialization, readiness/error state, hard reset and locale diagnostics |'
if controller_row not in lines:
    for index, line in enumerate(lines):
        if line.startswith('| `speech_engine_handle.dart` |'):
            lines.insert(index + 1, controller_row)
            break
    else:
        raise RuntimeError('speech engine handle structure row not found')
for index, line in enumerate(lines):
    if line.startswith('| `app/shell/shared/shell_voice_routing.dart` |'):
        lines[index] = '| `app/shell/shared/shell_voice_routing.dart` | Voice command routing, submit flows and voice-sheet hosting; SpeechToText engine lifecycle belongs to shared recognition *(part)* |'
        break
else:
    raise RuntimeError('shell voice routing structure row not found')
structure.write_text('\n'.join(lines) + ('\n' if doc.endswith('\n') else ''), encoding='utf-8')

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Shared STT engine lifecycle [engineering]\n\n- Added `SpeechEngineController` under `shared/voice/recognition` as the owner of SpeechToText initialization, readiness/error state, hard reset and locale diagnostics.\n- Removed SpeechToText engine state and initialization/reset methods from shell state and `shell_voice_routing.dart`.\n- Shell now only prewarms/disposes the controller and hosts the voice sheet/submit routing.\n\n'''
if not text.startswith('## 2026-08-18 — Shared STT engine lifecycle [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')
