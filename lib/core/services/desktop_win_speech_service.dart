import 'dart:io';

/// Windows System.Speech WAV transcription (no Flutter speech_to_text).
class DesktopWinSpeechService {
  DesktopWinSpeechService._();

  static final DesktopWinSpeechService instance = DesktopWinSpeechService._();

  String? _lastError;

  String? get lastError => _lastError;

  String? _resolveScript() {
    try {
      var dir = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 6; i++) {
        final candidate = File(
          '${dir.path}${Platform.pathSeparator}stt_helper'
          '${Platform.pathSeparator}win_speech_wav.ps1',
        );
        if (candidate.existsSync()) return candidate.path;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> transcribeWav(String wavPath) async {
    _lastError = null;
    final script = _resolveScript();
    if (script == null) {
      _lastError = 'win_speech_wav.ps1 not found';
      return null;
    }
    if (!File(wavPath).existsSync()) {
      _lastError = 'WAV not found';
      return null;
    }
    try {
      final result = await Process.run(
        'powershell',
        [
          '-ExecutionPolicy',
          'Bypass',
          '-NoProfile',
          '-File',
          script,
          wavPath,
        ],
        runInShell: false,
      );
      if (result.exitCode != 0) {
        _lastError = (result.stderr as String).trim().isNotEmpty
            ? (result.stderr as String).trim()
            : 'Windows speech exit ${result.exitCode}';
        return null;
      }
      final text = (result.stdout as String).trim();
      if (text.isEmpty) {
        _lastError = 'Empty transcript';
        return null;
      }
      return text;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }
}
