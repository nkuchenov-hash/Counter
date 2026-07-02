import 'package:flutter/foundation.dart';

/// Concise desktop-voice pipeline markers (no spam; one line per step).
class DesktopVoiceLog {
  DesktopVoiceLog._();

  static final DesktopVoiceLog instance = DesktopVoiceLog._();

  final List<String> _lines = <String>[];
  static const _maxLines = 32;

  List<String> get lines => List.unmodifiable(_lines);

  void clear() => _lines.clear();

  void mark(String step, [String? detail]) {
    if (kReleaseMode && step.startsWith('dbg_')) return;
    final line = detail == null || detail.isEmpty ? step : '$step: $detail';
    _lines.add(line);
    if (_lines.length > _maxLines) {
      _lines.removeAt(0);
    }
    if (kDebugMode) {
      debugPrint('[desktop_voice] $line');
    }
  }
}
