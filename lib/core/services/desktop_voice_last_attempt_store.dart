import 'dart:io';

import 'package:counter/core/app_build_info.dart';
import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_stt_diagnostics.dart';
import 'package:counter/core/services/desktop_voice_installed_identity.dart';

/// Writes the latest voice attempt diagnostics to a stable on-disk path so we
/// can pull them after a live capture without asking the user to decode overlay
/// text or open Settings.
abstract final class DesktopVoiceLastAttemptStore {
  static String get lastAttemptPath {
    final local = Platform.environment['LOCALAPPDATA'] ?? '';
    final base = local.isNotEmpty ? local : Directory.systemTemp.path;
    return '$base${Platform.pathSeparator}Counter'
        '${Platform.pathSeparator}voice_samples'
        '${Platform.pathSeparator}last_attempt_diag.txt';
  }

  static Future<void> write({
    required DesktopSttDiagnostics diag,
    String? attemptPlainText,
    String? friendlyError,
  }) async {
    try {
      final file = File(lastAttemptPath);
      await file.parent.create(recursive: true);
      final buf = StringBuffer()
        ..writeln('build_sha=${AppBuildInfo.gitCommit}')
        ..writeln('built_at=${AppBuildInfo.builtAt}')
        ..writeln('running_exe_path=${DesktopVoiceInstalledIdentity.runningExePath}')
        ..writeln('written_at=${DateTime.now().toUtc().toIso8601String()}')
        ..writeln('--- stt diagnostics ---');
      for (final line in diag.toDiagLines()) {
        buf.writeln(line);
      }
      if ((friendlyError ?? '').trim().isNotEmpty) {
        buf.writeln('friendly_error=${friendlyError!.trim()}');
      }
      if ((attemptPlainText ?? '').trim().isNotEmpty) {
        buf.writeln('--- attempt ---');
        buf.writeln(attemptPlainText!.trim());
      }
      await file.writeAsString(buf.toString(), flush: true);
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_LAST_ATTEMPT_DIAG_SAVED',
        lastAttemptPath,
      );
    } catch (e) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_LAST_ATTEMPT_DIAG_SAVE_FAILED',
        '$e',
      );
    }
  }
}
