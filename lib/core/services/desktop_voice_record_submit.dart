import 'package:counter/core/services/desktop_voice_command_normalize.dart';
import 'package:counter/data/models.dart';
import 'package:counter/core/diagnostics/desktop_voice_log.dart';
import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/data/voice_command_parser.dart';

/// Arguments passed to the Brain [DatabaseService.writeRecord] boundary.
class DesktopVoiceWriteRecordRequest {
  const DesktopVoiceWriteRecordRequest({
    required this.dateKey,
    required this.title,
    required this.categoryId,
    required this.explicitStartTime,
  });

  final String dateKey;
  final String title;
  final int categoryId;
  final DateTime explicitStartTime;
}

typedef DesktopVoiceWriteRecordFn = Future<String?> Function(
  DesktopVoiceWriteRecordRequest request,
);

/// Outcome of a production desktop-voice record start (parser → submit → Brain).
class DesktopVoiceSubmitOutcome {
  const DesktopVoiceSubmitOutcome({
    required this.serverId,
    required this.confirmationMessage,
    required this.writeRecordCalled,
  });

  final String serverId;
  final String confirmationMessage;
  final bool writeRecordCalled;
}

/// Production submit path shared by app shell, widget, and self-acceptance runner.
abstract final class DesktopVoiceRecordSubmit {
  /// Parses [transcript] and, when safe, invokes [writeRecord] (Brain boundary).
  static Future<DesktopVoiceSubmitOutcome?> submitTranscript({
    required List<CategoryRule> categoryRules,
    required String transcript,
    required String dateKey,
    required String localeCode,
    required DesktopVoiceWriteRecordFn writeRecord,
    required DateTime Function() planetaryNow,
  }) async {
    final parsed = parseVoiceCommand(
      rules: categoryRules,
      transcript: transcript,
    );
    return submitParsed(
      result: parsed,
      dateKey: dateKey,
      localeCode: localeCode,
      writeRecord: writeRecord,
      planetaryNow: planetaryNow,
    );
  }

  /// Submits an already-parsed command through the production writeRecord boundary.
  static Future<DesktopVoiceSubmitOutcome?> submitParsed({
    required VoiceCommandParseResult result,
    required String dateKey,
    required String localeCode,
    required DesktopVoiceWriteRecordFn writeRecord,
    required DateTime Function() planetaryNow,
    DateTime? explicitStartTime,
  }) async {
    final norm = normalizeDesktopVoiceCommand(result);
    if (norm == null || !norm.autoStartAllowed) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_WRITE_RECORD_BLOCKED',
        result.ambiguityReason ?? result.confidence.name,
      );
      return null;
    }
    final effective = norm.effectiveResult;
    final title = norm.normalizedTitle.trim();
    final cid = effective.matchedLocalCategoryId;
    if (title.isEmpty || cid == null) return null;

    DesktopVoicePipeline.mark('DESKTOP_VOICE_SUBMIT_PARSED_CALLED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_WRITE_RECORD_CALLED', '$title · $cid');
    DesktopVoiceLog.instance.mark('writeRecord_args', '$title · cat $cid');

    final now = explicitStartTime ?? planetaryNow();
    if (explicitStartTime != null) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_COMMIT_USES_CAPTURED_START_TIME',
        now.toUtc().toIso8601String(),
      );
    }
    final serverId = await writeRecord(
      DesktopVoiceWriteRecordRequest(
        dateKey: dateKey,
        title: title,
        categoryId: cid,
        explicitStartTime: now,
      ),
    );

    if (serverId == null || serverId.trim().isEmpty) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_WRITE_RECORD_RESULT', 'failed');
      return null;
    }

    DesktopVoicePipeline.mark('DESKTOP_VOICE_WRITE_RECORD_RESULT', 'ok $serverId');
    final confirmation = voiceCommandStartConfirmationMessage(
      effective,
      localeCode: localeCode,
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CONFIRMATION_SHOWN');

    return DesktopVoiceSubmitOutcome(
      serverId: serverId.trim(),
      confirmationMessage: confirmation,
      writeRecordCalled: true,
    );
  }
}
