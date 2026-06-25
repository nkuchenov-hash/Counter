import 'package:counter/data/models.dart';
import 'package:counter/core/diagnostics/desktop_voice_diag.dart';
import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/features/shared/voice_command_parser.dart';

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
  }) async {
    if (!result.isSafeToStart) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_WRITE_RECORD_BLOCKED',
        result.ambiguityReason ?? result.confidence.name,
      );
      return null;
    }
    final title = result.recordTitle.trim();
    final cid = result.matchedLocalCategoryId;
    if (title.isEmpty || cid == null) return null;

    DesktopVoicePipeline.mark('DESKTOP_VOICE_SUBMIT_PARSED_CALLED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_WRITE_RECORD_CALLED', '$title · $cid');
    DesktopVoiceDiag.instance.mark('writeRecord_args', '$title · cat $cid');

    final now = planetaryNow();
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
      result,
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
