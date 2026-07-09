/// Single-instance correction state machine for Desktop Voice pending commands.
///
/// Pure policy — no Flutter UI. Widget/native overlay call into this before
/// opening sheets so duplicate panels and z-order races are blocked.
abstract final class DesktopVoiceCorrectionFlow {
  static const String markerSingleInstance =
      'DESKTOP_VOICE_CORRECTION_SINGLE_INSTANCE';
  static const String markerOpensInFront =
      'DESKTOP_VOICE_CORRECTION_OPENS_IN_FRONT';
  static const String markerOverlayHidden =
      'DESKTOP_VOICE_OVERLAY_HIDDEN_WHILE_CORRECTING';
  static const String markerNoXRequired =
      'DESKTOP_VOICE_CORRECTION_NO_X_REQUIRED';
  static const String markerDuplicateBlocked =
      'DESKTOP_VOICE_CORRECTION_DUPLICATE_OPEN_BLOCKED';
  static const String markerReparsed =
      'DESKTOP_VOICE_CORRECTED_COMMAND_REPARSED';
  static const String markerWritesAfterConfirm =
      'DESKTOP_VOICE_CORRECTED_COMMAND_WRITES_AFTER_CONFIRM';
  static const String markerCancelNoWrite =
      'DESKTOP_VOICE_CORRECTION_CANCEL_NO_WRITE';
  static const String markerNoLostPending =
      'DESKTOP_VOICE_NO_LOST_PENDING_COMMAND_AFTER_CORRECTION';
  static const String markerConfirmNotNoop =
      'DESKTOP_VOICE_CORRECTION_CONFIRM_NOT_NOOP';
  static const String markerNoDuplicateWrite =
      'DESKTOP_VOICE_NO_DUPLICATE_WRITE_AFTER_CORRECTION';

  /// Whether a new correction panel may open.
  static bool mayOpenCorrection({
    required bool pendingVisible,
    required bool correctionAlreadyOpen,
    required bool sessionCancelled,
  }) {
    if (sessionCancelled || !pendingVisible) return false;
    if (correctionAlreadyOpen) return false;
    return true;
  }

  /// Overlay must hide (or convert) before/while correction is shown.
  static bool shouldHideOverlayForCorrection({
    required bool correctionOpenRequested,
  }) =>
      correctionOpenRequested;

  /// Confirm must not silently no-op when parse is unsafe.
  static bool confirmIsNoOp({
    required bool confirmed,
    required bool parseSafeToStart,
    required bool writeRequested,
  }) {
    if (!confirmed) return false;
    return !parseSafeToStart || !writeRequested;
  }

  /// Cancel path must never request a write.
  static bool cancelRequestsWrite({required bool cancelled}) => false;
}

/// Mutable session counters for diagnostics (one pending command).
class DesktopVoiceCorrectionSession {
  DesktopVoiceCorrectionSession({required this.pendingCommandId});

  final String pendingCommandId;
  final String sessionId =
      'corr_${DateTime.now().millisecondsSinceEpoch}';

  bool openRequested = false;
  bool opened = false;
  int panelCount = 0;
  bool duplicateBlocked = false;
  bool overlayHidden = false;
  bool zOrderFront = false;
  bool confirmed = false;
  bool cancelled = false;
  bool writeRequested = false;
  bool writeSuccess = false;
  String? correctedText;
  String? correctedTitle;
  String? correctedSelectedPath;
  String? correctedParserResult;
  bool pendingStateCleared = false;

  bool tryBeginOpen() {
    openRequested = true;
    if (opened || panelCount > 0) {
      duplicateBlocked = true;
      return false;
    }
    opened = true;
    panelCount = 1;
    return true;
  }

  void markOverlayHidden() {
    overlayHidden = true;
    zOrderFront = true;
  }

  void markConfirmed({
    required String text,
    required String title,
    String? path,
    String? parserResult,
  }) {
    confirmed = true;
    correctedText = text;
    correctedTitle = title;
    correctedSelectedPath = path;
    correctedParserResult = parserResult;
  }

  void markCancelled() {
    cancelled = true;
    pendingStateCleared = true;
  }

  void markWrite({required bool success}) {
    writeRequested = true;
    writeSuccess = success;
    pendingStateCleared = true;
  }
}
