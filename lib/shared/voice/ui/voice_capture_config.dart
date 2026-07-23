import 'package:flutter/foundation.dart';

/// Intent passed into [VoiceInputSheet] so one speech-recognition UI can commit
/// results through [DatabaseService] in different ways (Timeline vs Planning).
///
/// The shell builds [submitIntent] when opening the sheet (captures tab + dates).
@immutable
class VoiceCaptureConfig {
  const VoiceCaptureConfig({
    required this.submitIntent,
    this.successL10nKey = 'record_synced',
    this.primaryActionL10nKey = 'start_task',
  });

  /// Return `true` when persistence succeeded and the sheet should close + show success.
  final Future<bool> Function(String trimmedText) submitIntent;

  /// Dictionary key for the success SnackBar after [submitIntent] returns true.
  final String successL10nKey;

  /// Dictionary key for the primary FilledButton label.
  final String primaryActionL10nKey;
}
