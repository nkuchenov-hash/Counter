import 'dart:io';

import 'package:counter/shared/voice/diagnostics/desktop_voice_log.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;

/// One-line desktop voice pipeline markers (installed-app acceptance tracing).
abstract final class DesktopVoicePipeline {
  static File? _pipelineLogFile;
  static Future<void> _fileTail = Future<void>.value();

  static File get pipelineLogFile {
    _pipelineLogFile ??= File(
      '${Platform.environment['TEMP'] ?? '.'}${Platform.pathSeparator}counter_desktop_voice_pipeline.log',
    );
    return _pipelineLogFile!;
  }

  static void mark(String step, [String? detail]) {
    final line = detail == null || detail.isEmpty ? step : '$step $detail';
    DesktopVoiceLog.instance.mark(step, detail);
    if (step.startsWith('DESKTOP_VOICE_')) {
      final stamped = '${DateTime.now().toIso8601String()} $line';
      if (kDebugMode) {
        debugPrint('[DesktopVoice] $line');
      } else {
        // Release: single line per step for installed-app log capture.
        // ignore: avoid_print
        print('[DesktopVoice] $line');
      }
      if (!kIsWeb && Platform.isWindows) {
        // Keep ordering for acceptance traces, but never block the voice
        // interaction isolate on filesystem I/O (antivirus, slow disk, etc.).
        _fileTail = _fileTail.then((_) async {
          try {
            await pipelineLogFile.writeAsString(
              '$stamped\n',
              mode: FileMode.append,
            );
          } catch (_) {}
        });
      }
    }
  }
}