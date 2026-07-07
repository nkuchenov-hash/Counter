import 'dart:convert';
import 'dart:io';

/// Temporary debug-mode probe for installed Desktop Voice runtime evidence.
abstract final class DesktopVoiceDebugProbe {
  static const _sessionId = 'd3c282';
  static const _logPath =
      r'C:\Users\nkuch\Development\Apps\counter\debug-d3c282.log';

  static void log({
    required String runId,
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, Object?> data = const {},
  }) {
    try {
      final payload = <String, Object?>{
        'sessionId': _sessionId,
        'id': 'log_${DateTime.now().microsecondsSinceEpoch}',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'runId': runId,
        'hypothesisId': hypothesisId,
        'location': location,
        'message': message,
        'data': data,
      };
      File(_logPath).writeAsStringSync(
        '${jsonEncode(payload)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }
}
