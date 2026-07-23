import 'package:counter/shared/voice/recognition/desktop_voice_user_error.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';

/// Final human-facing outcome of a single desktop-voice attempt.
enum DesktopVoiceAttemptStatus {
  /// Still in progress (recording / transcribing / submitting).
  inProgress,

  /// A new task record was created and is visible in the app.
  taskCreated,

  /// STT produced a transcript but the parser could not match a command.
  notRecognized,

  /// Microphone permission / capture / signal failure.
  micError,

  /// STT helper failed to transcribe (helper down, model not loaded, etc.).
  sttError,

  /// Parser matched a command but writeRecord failed (PocketBase / network).
  saveError,

  /// User cancelled the session before any command was submitted.
  cancelled,
}

/// Human-readable outcome of one desktop-voice attempt (hotkey в†’ task).
///
/// Populated stage-by-stage by the desktop-voice overlay widget; the in-app
/// Voice diagnostics dialog renders the latest attempt with a Copy button so
/// the user never has to open the %TEMP% pipeline log to verify behaviour.
@immutable
class DesktopVoiceAttempt {
  const DesktopVoiceAttempt({
    required this.startedAt,
    required this.hotkeyReceived,
    required this.recordingStarted,
    required this.micInputDetected,
    required this.transcript,
    required this.parserConfidence,
    required this.matchedScope,
    required this.taskTitle,
    required this.writeRecordResult,
    required this.status,
    required this.statusDetail,
  });

  final DateTime startedAt;

  /// Hotkey was received and the overlay opened.
  final bool hotkeyReceived;

  /// Microphone capture started successfully.
  final bool recordingStarted;

  /// At least one non-silent audio chunk arrived from the microphone.
  final bool micInputDetected;

  /// Final STT transcript text (empty until transcription completes).
  final String transcript;

  /// Parser verdict: `exact`, `ambiguous`, `noMatch`, or `вЂ”` (not parsed yet).
  final String parserConfidence;

  /// Matched category / scope display path (e.g.
  /// "Price Reporter > AGE SOLUTIONS"). Empty when nothing matched.
  final String matchedScope;

  /// Resolved task title that would be / was written (e.g. "ADD SIN").
  final String taskTitle;

  /// Result of the writeRecord call: `ok`, `failed`, `pending`, or `not called`.
  final String writeRecordResult;

  /// Final user-facing status (see [DesktopVoiceAttemptStatus]).
  final DesktopVoiceAttemptStatus status;

  /// Human-facing detail line accompanying the status (translated copy).
  final String statusDetail;

  DesktopVoiceAttempt copyWith({
    bool? hotkeyReceived,
    bool? recordingStarted,
    bool? micInputDetected,
    String? transcript,
    String? parserConfidence,
    String? matchedScope,
    String? taskTitle,
    String? writeRecordResult,
    DesktopVoiceAttemptStatus? status,
    String? statusDetail,
  }) {
    return DesktopVoiceAttempt(
      startedAt: startedAt,
      hotkeyReceived: hotkeyReceived ?? this.hotkeyReceived,
      recordingStarted: recordingStarted ?? this.recordingStarted,
      micInputDetected: micInputDetected ?? this.micInputDetected,
      transcript: transcript ?? this.transcript,
      parserConfidence: parserConfidence ?? this.parserConfidence,
      matchedScope: matchedScope ?? this.matchedScope,
      taskTitle: taskTitle ?? this.taskTitle,
      writeRecordResult: writeRecordResult ?? this.writeRecordResult,
      status: status ?? this.status,
      statusDetail: statusDetail ?? this.statusDetail,
    );
  }

  /// Plain-text summary safe for clipboard copy / sharing. No internal codes,
  /// no PocketBase IDs вЂ” only what a non-developer can read.
  String toPlainText() {
    final buf = StringBuffer()
      ..writeln('Desktop Voice вЂ” last attempt')
      ..writeln('Time: ${startedAt.toLocal()}')
      ..writeln('----')
      ..writeln('Hotkey received: ${_yesNo(hotkeyReceived)}')
      ..writeln('Recording started: ${_yesNo(recordingStarted)}')
      ..writeln('Microphone input detected: ${_yesNo(micInputDetected)}')
      ..writeln('Heard: "${transcript.isEmpty ? '(nothing yet)' : transcript}"')
      ..writeln('Parser: ${parserConfidence.isEmpty ? 'вЂ”' : parserConfidence}')
      ..writeln('Matched scope: ${matchedScope.isEmpty ? 'вЂ”' : matchedScope}')
      ..writeln('Task title: ${taskTitle.isEmpty ? 'вЂ”' : taskTitle}')
      ..writeln('Save result: ${writeRecordResult.isEmpty ? 'вЂ”' : writeRecordResult}')
      ..writeln('Final: ${_statusLabel(status)}');
    if (statusDetail.trim().isNotEmpty) {
      buf.writeln('Detail: ${statusDetail.trim()}');
    }
    return buf.toString().trimRight();
  }

  static String _yesNo(bool v) => v ? 'yes' : 'no';

  static String _statusLabel(DesktopVoiceAttemptStatus s) {
    switch (s) {
      case DesktopVoiceAttemptStatus.inProgress:
        return 'in progress';
      case DesktopVoiceAttemptStatus.taskCreated:
        return 'task created';
      case DesktopVoiceAttemptStatus.notRecognized:
        return 'not recognized';
      case DesktopVoiceAttemptStatus.micError:
        return 'microphone error';
      case DesktopVoiceAttemptStatus.sttError:
        return 'recognition (STT) error';
      case DesktopVoiceAttemptStatus.saveError:
        return 'task save error';
      case DesktopVoiceAttemptStatus.cancelled:
        return 'cancelled';
    }
  }
}

/// Singleton registry of the latest desktop-voice attempt, exposed via a
/// [ValueNotifier] so the in-app diagnostics dialog reacts in real time.
class DesktopVoiceAttemptLog {
  DesktopVoiceAttemptLog._();
  static final DesktopVoiceAttemptLog instance = DesktopVoiceAttemptLog._();

  final ValueNotifier<DesktopVoiceAttempt?> _notifier =
      ValueNotifier<DesktopVoiceAttempt?>(null);

  ValueListenable<DesktopVoiceAttempt?> get listenable => _notifier;
  DesktopVoiceAttempt? get current => _notifier.value;

  /// Begin a new attempt. Resets every field; called when the overlay opens
  /// after a hotkey press.
  void begin() {
    _notifier.value = DesktopVoiceAttempt(
      startedAt: DateTime.now(),
      hotkeyReceived: true,
      recordingStarted: false,
      micInputDetected: false,
      transcript: '',
      parserConfidence: 'вЂ”',
      matchedScope: '',
      taskTitle: '',
      writeRecordResult: 'not called',
      status: DesktopVoiceAttemptStatus.inProgress,
      statusDetail: 'ListeningвЂ¦',
    );
  }

  void _update(DesktopVoiceAttempt Function(DesktopVoiceAttempt) fn) {
    final cur = _notifier.value;
    if (cur == null) return;
    _notifier.value = fn(cur);
  }

  void markRecordingStarted(bool ok, {String? error}) {
    _update(
      (a) => a.copyWith(
        recordingStarted: ok,
        status: ok
            ? DesktopVoiceAttemptStatus.inProgress
            : DesktopVoiceAttemptStatus.micError,
        statusDetail: ok
            ? 'ListeningвЂ¦'
            : (error?.isNotEmpty == true
                ? error!
                : 'Microphone is not receiving audio'),
      ),
    );
  }

  void markMicHeard() {
    _update((a) => a.copyWith(micInputDetected: true));
  }

  void recordTranscript(String text) {
    _update(
      (a) => a.copyWith(
        transcript: text,
        statusDetail: text.trim().isEmpty
            ? 'No speech recognised.'
            : 'Heard: "$text". Matching commandвЂ¦',
      ),
    );
  }

  void recordParser({
    required String confidence,
    required String matchedScope,
    required String taskTitle,
  }) {
    _update(
      (a) => a.copyWith(
        parserConfidence: confidence.isEmpty ? 'вЂ”' : confidence,
        matchedScope: matchedScope,
        taskTitle: taskTitle,
      ),
    );
  }

  void markParserReject({
    required String rejectReason,
    List<String> missingTokens = const [],
  }) {
    final missing = missingTokens.isEmpty
        ? ''
        : ' Missing: ${missingTokens.join(', ')}.';
    _update(
      (a) => a.copyWith(
        statusDetail:
            'Heard: "${a.transcript}". $rejectReason.$missing',
      ),
    );
  }

  void markNotRecognized() {
    _update(
      (a) => a.copyWith(
        status: DesktopVoiceAttemptStatus.notRecognized,
        statusDetail: a.transcript.trim().isEmpty
            ? 'Could not recognise the command.'
            : 'Heard: "${a.transcript}". Could not match command.',
        writeRecordResult: 'not called',
      ),
    );
  }

  void markSttError(String detail, {DesktopVoiceFailureKind? kind}) {
    final friendly = kind == null
        ? detail
        : DesktopVoiceUserError.fromException(
            detail,
            stage: DesktopVoiceErrorStage.transcribing,
            localeCode: currentLocale.value,
            kind: kind,
          ).message;
    _update(
      (a) => a.copyWith(
        status: DesktopVoiceAttemptStatus.sttError,
        statusDetail: friendly.isEmpty
            ? 'Speech recognition failed. Try again.'
            : friendly,
        writeRecordResult: 'not called',
      ),
    );
  }

  void markWriteRecordPending() {
    _update(
      (a) => a.copyWith(
        writeRecordResult: 'pending',
      ),
    );
  }

  void markSubmission({required String? serverId, String? error}) {
    if (serverId != null && serverId.trim().isNotEmpty) {
      _update(
        (a) => a.copyWith(
          writeRecordResult: 'ok',
          status: DesktopVoiceAttemptStatus.taskCreated,
          statusDetail: 'Started: ${a.matchedScope.isEmpty ? a.taskTitle : a.matchedScope}'
              '${a.taskTitle.isEmpty ? '' : ' вЂ” ${a.taskTitle}'}',
        ),
      );
    } else {
      _update(
        (a) => a.copyWith(
          writeRecordResult: 'failed',
          status: DesktopVoiceAttemptStatus.saveError,
          statusDetail: error?.isNotEmpty == true
              ? 'Could not save the task. $error'
              : 'Could not save the task. Please retry.',
        ),
      );
    }
  }

  void markCancelled() {
    _update(
      (a) => a.copyWith(
        status: a.status == DesktopVoiceAttemptStatus.inProgress
            ? DesktopVoiceAttemptStatus.cancelled
            : a.status,
        statusDetail: a.status == DesktopVoiceAttemptStatus.inProgress
            ? 'Cancelled.'
            : a.statusDetail,
      ),
    );
  }
}
