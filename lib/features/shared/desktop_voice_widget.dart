import 'dart:async';

import 'package:counter/core/diagnostics/desktop_voice_log.dart';
import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_confirmation_timer.dart';
import 'package:counter/core/navigation/app_navigator.dart';
import 'package:counter/core/services/desktop_voice_overlay_service.dart';
import 'package:counter/core/services/desktop_voice_native_overlay.dart';
import 'package:counter/core/services/desktop_voice_recognizer_factory.dart';
import 'package:counter/core/services/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_voice_glossary.dart';
import 'package:counter/core/services/desktop_voice_command_normalize.dart';
import 'package:counter/core/services/desktop_voice_user_error.dart';
import 'package:counter/core/services/desktop_voice_overlay_bridge.dart';
import 'package:counter/core/services/desktop_voice_attempt_log.dart';
import 'package:counter/core/services/desktop_voice_audio_capture.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:counter/features/shared/desktop_voice_correction_sheet.dart';
import 'package:counter/features/shared/desktop_voice_capsule.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum DesktopVoiceOverlayPhase {
  preparing,
  listening,
  processing,
  pendingConfirmation,
  started,
  stopped,
  error,
}

typedef DesktopVoiceStartRecordFn = Future<String?> Function(
  VoiceCommandParseResult result, {
  DateTime? explicitStartTime,
});

/// Generic Life OS desktop voice overlay — recording first, parse preview second.
class DesktopVoiceOverlay extends StatefulWidget {
  const DesktopVoiceOverlay({
    super.key,
    required this.categoryRules,
    required this.onStartRecord,
    this.onUndoStop,
    required this.onClose,
  });

  final List<CategoryRule> categoryRules;
  final Future<String?> Function(VoiceCommandParseResult result, {DateTime? explicitStartTime}) onStartRecord;
  final Future<void> Function(String? recordDocId)? onUndoStop;
  final VoidCallback onClose;

  @override
  State<DesktopVoiceOverlay> createState() => _DesktopVoiceOverlayState();
}

class _DesktopVoiceOverlayState extends State<DesktopVoiceOverlay> {
  DesktopVoiceOverlayPhase _phase = DesktopVoiceOverlayPhase.listening;
  String _statusLine = '';
  String _transcript = '';
  String? _errorDetail;
  VoiceCommandParseResult? _parseResult;
  String? _startedRecordDocId;
  DesktopVoiceGlossaryPack? _lastGlossary;

  DesktopVoiceRecognizer? _recognizer;
  Timer? _listenTimer;
  Timer? _uiTimer;
  Timer? _noSignalTimer;
  bool _sessionCancelled = false;
  bool _cancelling = false;
  Stopwatch? _recordStopwatch;
  StreamSubscription<double>? _ampSub;
  final _confirmTimer = DesktopVoiceConfirmationTimer();
  double _confirmProgress = 0;
  bool _correctionOpen = false;
  bool _commitInFlight = false;

  double _micLevel = 0;
  bool _audioLevelSeen = false;
  int _audioBytes = 0;

  @override
  void initState() {
    super.initState();
    final loc = currentLocale.value;
    DesktopVoiceLog.instance.clear();
    DesktopVoiceLog.instance.mark('widget_opened');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_PREPARING_UI');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_FIRST_VISIBLE_STATE_LISTENING');
    DesktopVoiceSettings.instance.setVoiceStatusLine(
      t(loc, 'desktop_voice_state_listening'),
    );
    _statusLine = t(loc, 'desktop_voice_state_listening');
    _recordStopwatch = Stopwatch()..start();
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_COMPACT');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_CLEAN_RELEASE');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_NO_DEBUG_TEXT');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_COMPACT_POLISHED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_NO_DEBUG_UI');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_DESIGN_TOKENS_USED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_MIC_BARS_PRESERVED_IN_OVERLAY');
    _uiTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) setState(() {});
    });
    DesktopVoiceOverlayBridge.bindSession(
      isListening: () =>
          _phase == DesktopVoiceOverlayPhase.listening,
      isPreparing: () => false,
      isProcessing: () =>
          _phase == DesktopVoiceOverlayPhase.processing ||
          _phase == DesktopVoiceOverlayPhase.pendingConfirmation,
      finishListening: () => unawaited(_finishListening()),
      cancelSession: () => unawaited(_cancelSession(fromUser: true)),
      onOverlayClosed: () {},
    );
    DesktopVoiceNativeOverlay.onCloseRequested = () {
      unawaited(_cancelSession(fromUser: true));
    };
    DesktopVoiceNativeOverlay.onBodyClicked = () {
      if (_phase == DesktopVoiceOverlayPhase.pendingConfirmation) {
        unawaited(_openCorrection());
      }
    };
    unawaited(DesktopVoiceOverlayService.showListening(timer: _formatTimer()));
    // Start a fresh attempt summary so the in-app Voice diagnostics dialog can
    // reflect this session in real time. The user should NOT need to open the
    // %TEMP% pipeline log to verify what happened.
    DesktopVoiceAttemptLog.instance.begin();
    unawaited(_beginSessionRecordingFirst());
  }

  @override
  void dispose() {
    DesktopVoiceAudioCapture.instance.onReadyCuePlayed = null;
    DesktopVoiceNativeOverlay.onCloseRequested = null;
    DesktopVoiceNativeOverlay.onBodyClicked = null;
    _confirmTimer.cancel();
    DesktopVoiceOverlayBridge.clearSession();
    _listenTimer?.cancel();
    _uiTimer?.cancel();
    _noSignalTimer?.cancel();
    _ampSub?.cancel();
    _recognizer?.dispose();
    unawaited(_recognizer?.cancelCapture());
    unawaited(DesktopVoiceOverlayService.forceHide());
    super.dispose();
  }

  Future<void> _beginSessionRecordingFirst() async {
    final loc = currentLocale.value;
    if (!mounted || _sessionCancelled) return;

    final mic = await Permission.microphone.status;
    if (_sessionCancelled || !mounted) return;
    if (!mic.isGranted) {
      final res = await Permission.microphone.request();
      if (_sessionCancelled || !mounted) return;
      if (!res.isGranted) {
        _failFriendly(
          t(loc, 'microphone_permission'),
          diag: 'mic_permission_denied',
          stage: DesktopVoiceErrorStage.listening,
          recordingFailed: true,
        );
        return;
      }
    }
    if (!mounted || _sessionCancelled) return;

    DesktopVoiceAudioCapture.instance.noteHotkeyReceived();
    DesktopVoiceAudioCapture.instance.onReadyCuePlayed = () {
      if (!mounted || _sessionCancelled) return;
      if (_phase != DesktopVoiceOverlayPhase.listening) return;
      final loc = currentLocale.value;
      setState(() {
        _statusLine = t(loc, 'desktop_voice_state_speak');
      });
      unawaited(
        DesktopVoiceOverlayService.showSpeakReady(
          timer: _formatTimer(),
          level: _micLevel,
        ),
      );
    };

    _recognizer = await createDesktopVoiceRecognizer();
    if (_sessionCancelled || !mounted) return;

    _helper.prewarmRecognizerInBackground();
    _helper.evaluateCommandCandidate = (text) {
      final parsed = parseVoiceCommand(
        rules: widget.categoryRules,
        transcript: text,
        taskTitleHints: _lastGlossary?.taskTitles ?? const [],
      );
      final useful = parsed.isSafeToStart &&
          parsed.confidence == VoiceCommandMatchConfidence.exact;
      return (
        useful: useful,
        parseStatus:
            '${parsed.confidence.name}${parsed.ambiguityReason == null ? '' : ':${parsed.ambiguityReason}'}',
      );
    };

    final started = await _recognizer!.startCapture();
    DesktopVoiceLog.instance.mark(
      'recording_started',
      started ? 'yes' : 'no',
    );
    if (!started) {
      // Pipe-level marker so runtime smoke logs show WHERE the chain died
      // (capture start returned false) instead of only the friendly error UI.
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_CAPTURE_START_FAILED',
        DesktopSttHelperService.instance.lastError ?? 'unknown',
      );
      _helper.noteCaptureStartFailed(
        DesktopSttHelperService.instance.lastError,
      );
      DesktopVoiceAttemptLog.instance.markRecordingStarted(
        false,
        error: DesktopSttHelperService.instance.lastError,
      );
      _failFriendly(
        DesktopSttHelperService.instance.lastError,
        message: t(loc, 'desktop_voice_mic_no_signal'),
        diag: 'recording_failed',
        stage: DesktopVoiceErrorStage.listening,
        recordingFailed: true,
      );
      return;
    }
    DesktopVoiceAttemptLog.instance.markRecordingStarted(true);

    DesktopVoicePipeline.mark('DESKTOP_VOICE_RECORDING_STARTED_IMMEDIATELY');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_RECORDING_STARTED');

    _ampSub = _recognizer!.amplitudeStream?.listen((level) {
      if (!mounted) return;
      setState(() {
        _micLevel = level;
        if (level >= 0.008) _audioLevelSeen = true;
        _audioBytes = _recognizer?.capturedAudioBytes ?? _audioBytes;
      });
      if (level >= 0.008) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_LEVEL_SEEN');
        DesktopVoiceLog.instance.mark('audio_level_seen', 'yes');
        DesktopVoiceAttemptLog.instance.markMicHeard();
      }
      if (_phase == DesktopVoiceOverlayPhase.listening) {
        _helper.noteOverlayLevelEvent();
        unawaited(
          DesktopVoiceOverlayService.updateLevel(
            level,
            timer: _formatTimer(),
          ),
        );
      }
    });

    _noSignalTimer?.cancel();
    _noSignalTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_phase != DesktopVoiceOverlayPhase.listening) return;
      if (_audioLevelSeen || _audioBytes > 4800) return;
      DesktopVoiceLog.instance.mark('audio_level_seen', 'no');
      _helper.noteIntermittentListeningNoSignal();
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_MIC_SIGNAL_VISIBLE');
      unawaited(_recognizer?.cancelCapture());
      _failFriendly(
        t(loc, 'desktop_voice_mic_no_signal'),
        message: t(loc, 'desktop_voice_mic_no_signal'),
        diag: 'no_audio_signal',
        stage: DesktopVoiceErrorStage.listening,
      );
    });

    _setPhase(
      DesktopVoiceOverlayPhase.listening,
      status: t(loc, 'desktop_voice_state_listening'),
    );

    _listenTimer?.cancel();
    _listenTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && _phase == DesktopVoiceOverlayPhase.listening) {
        unawaited(_finishListening());
      }
    });
  }

  DesktopSttHelperService get _helper => DesktopSttHelperService.instance;

  /// State B entry: hotkey while listening finishes capture and parses command.
  Future<void> finishListeningFromHotkey() => _finishListening();

  Future<void> _finishListening() async {
    if (_phase != DesktopVoiceOverlayPhase.listening) return;
    final loc = currentLocale.value;
    _listenTimer?.cancel();
    _noSignalTimer?.cancel();
    _uiTimer?.cancel();
    _recordStopwatch?.stop();
    final durationMs = _recordStopwatch?.elapsedMilliseconds ?? 0;
    DesktopVoiceLog.instance.mark('audio_duration_ms', '$durationMs');

    _setPhase(
      DesktopVoiceOverlayPhase.processing,
      status: t(loc, 'desktop_voice_transcribing'),
    );
    DesktopVoiceSettings.instance.setVoiceStatusLine(
      t(loc, 'desktop_voice_transcribing'),
    );
    unawaited(
      DesktopVoiceOverlayService.showProcessing(timer: _formatTimer()),
    );

    final rec = _recognizer;
    if (rec == null) {
      // Recognizer vanished between listening and finalize — loggable breakpoint.
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_FINALIZE_NO_RECOGNIZER',
        'recognizer_null_after_listening',
      );
      return;
    }
    DesktopVoicePipeline.mark('DESKTOP_VOICE_FINALIZE_CAPTURE_REQUESTED');
    final glossary = DesktopVoiceGlossaryPack.buildFromCategoryRules(
      widget.categoryRules,
    );
    _lastGlossary = glossary;
    DesktopSttHelperService.instance.setTranscribeGlossary(glossary);
    final result = await rec.finishCapture();
    if (!mounted) return;

    _audioBytes = result.audioBytes ?? rec.capturedAudioBytes;
    DesktopVoiceLog.instance.mark('audio_bytes', '$_audioBytes');
    DesktopVoiceLog.instance.mark(
      'audio_level_seen',
      _audioLevelSeen || rec.audioLevelSeen ? 'yes' : 'no',
    );

    if (!result.isSuccess) {
      DesktopVoiceLog.instance.mark('transcript_returned', 'no');
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_STT_FAILED',
        result.error ?? 'no_transcript',
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CURRENT_RECORD_UNCHANGED_ON_FAILURE');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_RECOGNIZER_FAILED_NO_RECORD_CHANGE');
      final kind = result.failureKind ??
          DesktopVoiceUserError.classifySttFailure(
            audioLevelSeen: _audioLevelSeen || rec.audioLevelSeen,
            errorText: result.error,
            transcribeErrorKind: _helper.lastDiagnostics.transcribeErrorKind,
            helperExists: _helper.lastDiagnostics.helperExists,
            modelExists: _helper.lastDiagnostics.modelExists,
            helperReady: _helper.lastDiagnostics.helperReady,
            finalTranscribeReady: _helper.lastDiagnostics.finalTranscribeReady,
            pendingWavAfterStop: _helper.lastDiagnostics.pendingWavAfterStop,
            helperReadyAfterRecording:
                _helper.lastDiagnostics.helperReadyAfterRecording,
            delayedTranscribeCalled:
                _helper.lastDiagnostics.delayedTranscribeCalled,
          );
      DesktopVoiceAttemptLog.instance.markSttError(
        DesktopVoiceUserError.fromException(
          result.error,
          stage: DesktopVoiceErrorStage.transcribing,
          localeCode: loc,
          kind: kind,
        ).message,
      );
      _failFriendly(
        result.error,
        diag: 'stt_failed',
        stage: DesktopVoiceErrorStage.transcribing,
        kind: kind,
      );
      return;
    }

    _transcript = result.transcript.trim();
    if ((result.rawModelText ?? '').trim().isNotEmpty) {
      DesktopVoiceLog.instance.mark('raw_model_text', result.rawModelText!.trim());
    }
    if ((result.postprocessedText ?? '').trim().isNotEmpty) {
      DesktopVoiceLog.instance.mark(
        'postprocessed_text',
        result.postprocessedText!.trim(),
      );
    }
    if ((result.finalCommandText ?? '').trim().isNotEmpty) {
      DesktopVoiceLog.instance.mark(
        'final_command_text',
        result.finalCommandText!.trim(),
      );
    }
    if (_transcript.isEmpty) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIPT_EMPTY');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CURRENT_RECORD_UNCHANGED_ON_FAILURE');
      DesktopVoiceAttemptLog.instance.markSttError(
        t(loc, 'desktop_voice_stt_empty_transcript'),
      );
      _failFriendly(
        null,
        message: t(loc, 'desktop_voice_stt_empty_transcript'),
        diag: 'stt_empty_transcript',
        stage: DesktopVoiceErrorStage.transcribing,
        kind: DesktopVoiceFailureKind.sttEmptyTranscript,
      );
      return;
    }

    DesktopVoicePipeline.mark('DESKTOP_VOICE_COMMAND_TRANSCRIPT_READY', _transcript);
    DesktopVoiceLog.instance.mark('transcript_returned', 'yes');
    DesktopVoiceLog.instance.mark('transcript_text', _transcript);
    // Pipe-level transcript marker so a real STT transcription that the parser
    // later rejects is visible in the runtime smoke log (root-cause tracing).
    DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIPT_RECEIVED', _transcript);
    DesktopVoiceAttemptLog.instance.recordTranscript(_transcript);
    await _parseTranscript();
  }

  Future<void> _parseTranscript() async {
    final loc = currentLocale.value;
    if (_transcript.trim().isEmpty) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIPT_EMPTY');
      return;
    }
    _setPhase(
      DesktopVoiceOverlayPhase.processing,
      status: t(loc, 'desktop_voice_transcribing'),
    );

    final parsed = parseVoiceCommand(
      rules: widget.categoryRules,
      transcript: _transcript,
      taskTitleHints: _lastGlossary?.taskTitles ?? const [],
    );
    _parseResult = parsed;
    DesktopVoiceLog.instance.mark('parser_status', parsed.confidence.name);
    DesktopVoiceLog.instance.mark(
      'parser_path',
      parsed.matchedCategoryDisplayPath ?? '—',
    );
    DesktopVoiceLog.instance.mark('parser_title', parsed.recordTitle);
    // Pipe-level parser verdict so a rejected transcript is traceable in the
    // runtime smoke log without grepping diag internals.
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_PARSER_RESULT',
      '${parsed.confidence.name} · path=${parsed.matchedCategoryDisplayPath ?? '—'}'
      ' · title=${parsed.recordTitle}'
      '${parsed.ambiguityReason == null ? '' : ' · reason=${parsed.ambiguityReason}'}',
    );
    // Mirror the parser verdict into the in-app Voice diagnostics log so the
    // user can read what the parser produced without opening the pipeline log.
    DesktopVoiceAttemptLog.instance.recordParser(
      confidence: parsed.confidence.name,
      matchedScope: parsed.matchedCategoryDisplayPath ?? '',
      taskTitle: parsed.recordTitle,
    );
    VoiceDomainResolver.logDomainDiagnosticsToAttemptLog(
      DesktopVoiceLog.instance.mark,
    );

    final norm = normalizeDesktopVoiceCommand(parsed);
    if (norm == null || !norm.autoStartAllowed) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_COMMAND_UNRECOGNIZED_NO_RECORD_CHANGE',
      );
      final reject = analyzeVoiceCommandReject(
        transcript: _transcript,
        result: parsed,
      );
      if (reject != null) {
        DesktopVoicePipeline.mark('parser_reject_reason', reject.parserRejectReason);
        DesktopVoicePipeline.mark(
          'missing_required_tokens',
          reject.missingRequiredTokens.join(','),
        );
        DesktopVoicePipeline.mark(
          'ambiguous_leaf_matches',
          reject.ambiguousLeafMatches.join(','),
        );
        DesktopVoicePipeline.mark('rejected_reason', reject.rejectedReason);
        DesktopVoicePipeline.mark(
          'selected_candidate_path',
          reject.selectedCandidatePath ?? '—',
        );
        DesktopVoiceAttemptLog.instance.markParserReject(
          rejectReason: reject.rejectedReason,
          missingTokens: reject.missingRequiredTokens,
        );
      }
      DesktopVoiceAttemptLog.instance.markNotRecognized();
      DesktopVoicePipeline.mark('DESKTOP_VOICE_COMMAND_NOT_RECOGNIZED', _transcript);
      _failFriendly(
        null,
        message: _heardNotMatchedMessage(loc, _transcript),
        diag: 'normalization_blocked',
        stage: DesktopVoiceErrorStage.parsing,
        kind: DesktopVoiceFailureKind.parserRejected,
        autoCloseAfter: const Duration(milliseconds: 1800),
      );
      return;
    }
    _parseResult = norm.effectiveResult;

    if (norm.effectiveResult.confidence == VoiceCommandMatchConfidence.exact &&
        norm.effectiveResult.isSafeToStart) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_COMMAND_RECOGNIZED_NEW_TASK',
        norm.normalizedTitle,
      );
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_COMMAND_ACCEPTED',
        norm.normalizedTitle,
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CURRENT_RECORD_UNCHANGED_BEFORE_COMMIT');
      _enterPendingConfirmation(norm.effectiveResult);
      return;
    }

    if (parsed.confidence == VoiceCommandMatchConfidence.ambiguous) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_COMMAND_UNRECOGNIZED_NO_RECORD_CHANGE',
        'ambiguous',
      );
      DesktopVoiceAttemptLog.instance.markNotRecognized();
      final names = parsed.ambiguousCandidates.join(', ');
      _failFriendly(
        null,
        message: names.isEmpty
            ? _heardNotMatchedMessage(loc, _transcript)
            : names,
        diag: parsed.ambiguityReason ?? 'ambiguous',
        stage: DesktopVoiceErrorStage.parsing,
      );
      return;
    }

    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_COMMAND_UNRECOGNIZED_NO_RECORD_CHANGE',
      parsed.ambiguityReason ?? 'no_match',
    );
    DesktopVoiceAttemptLog.instance.markNotRecognized();
    _failFriendly(
      null,
      message: _heardNotMatchedMessage(loc, _transcript),
      diag: parsed.ambiguityReason ?? 'no_match',
      stage: DesktopVoiceErrorStage.parsing,
    );
  }

  /// Builds the friendly "Heard: X. Could not match command." line shown when
  /// the parser could not turn a transcript into a task. EN/RU.
  String _heardNotMatchedMessage(String loc, String transcript) {
    final heard = transcript.trim();
    if (loc == 'ru') {
      return heard.isEmpty
          ? 'Не удалось распознать команду.'
          : 'Услышано: "$heard". Команда не распознана.';
    }
    return heard.isEmpty
        ? 'Could not recognise the command.'
        : 'Heard: "$heard". Could not match command.';
  }

  void _enterPendingConfirmation(VoiceCommandParseResult parsed) {
    final loc = currentLocale.value;
    _parseResult = parsed;
    final previewLines = voiceCommandPendingConfirmationLines(
      parsed,
      localeCode: loc,
    );
    final preview = previewLines.join('\n');
    _confirmProgress = 0;
    _setPhase(
      DesktopVoiceOverlayPhase.pendingConfirmation,
      status: preview,
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_PENDING_CONFIRMATION_STARTED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STATE_PENDING_CONFIRMATION');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_PENDING_FULL_COMMAND_VISIBLE');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_COMMAND_TEXT_CLIPPING');
    DesktopVoicePipeline.mark(
      't_pending_confirmation_visible',
      '${DateTime.now().millisecondsSinceEpoch}',
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_WRITE_BEFORE_TIMER');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_WRITE_RECORD_THROUGH_BRAIN');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_GARBAGE_RECORD');
    DesktopVoiceAttemptLog.instance.markWriteRecordPending();

    _confirmTimer.onProgress = (p) {
      if (!mounted) return;
      setState(() => _confirmProgress = p);
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_CONFIRMATION_TIMER_PROGRESS',
        p.toStringAsFixed(2),
      );
      unawaited(
        DesktopVoiceOverlayService.updatePendingProgress(
          previewLine: preview,
          hintLine: t(loc, 'desktop_voice_tap_to_edit'),
          progress: p,
        ),
      );
    };
    _confirmTimer.onComplete = () {
      if (!mounted || _correctionOpen || _sessionCancelled) return;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_AUTO_COMMIT_AFTER_TIMER');
      unawaited(_commitAfterConfirmation());
    };
    _confirmTimer.start();
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CONFIRMATION_TIMER_STARTED');
    unawaited(
      DesktopVoiceOverlayService.showPendingConfirmation(
        previewLine: preview,
        hintLine: t(loc, 'desktop_voice_tap_to_edit'),
        progress: 0,
      ),
    );
  }

  Future<void> _openCorrection() async {
    if (_phase != DesktopVoiceOverlayPhase.pendingConfirmation) return;
    final parsed = _parseResult;
    if (parsed == null) return;
    _correctionOpen = true;
    _confirmTimer.pause();
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CORRECTION_OPENED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CORRECTION_TIMER_PAUSED');

    final ctx = appRootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      _correctionOpen = false;
      _confirmTimer.resume();
      return;
    }

    final result = await showDesktopVoiceCorrectionSheet(
      context: ctx,
      parseResult: parsed,
      categoryPath: parsed.matchedCategoryDisplayPath ?? parsed.rootLabel,
    );
    _correctionOpen = false;
    if (!mounted || _sessionCancelled) return;

    if (result == null || result.cancelled) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CORRECTION_CANCELLED');
      await _cancelPendingConfirmation();
      return;
    }

    _parseResult = result.parseResult ?? parsed;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CORRECTION_CONFIRMED');
    await _commitAfterConfirmation();
  }

  Future<void> _cancelPendingConfirmation() async {
    _confirmTimer.cancel();
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CURRENT_RECORD_UNCHANGED_ON_FAILURE');
    await DesktopVoiceOverlayService.forceHide();
    if (mounted) widget.onClose();
  }

  Future<void> _commitAfterConfirmation() async {
    if (_commitInFlight) return;
    _commitInFlight = true;
    final capturedStart = _confirmTimer.intendedStartTime;
    _confirmTimer.cancel();
    DesktopVoicePipeline.mark('DESKTOP_VOICE_WRITE_RECORD_CALLED_AFTER_CONFIRMATION');
    if (capturedStart != null) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_COMMIT_USES_CAPTURED_START_TIME');
    }
    await _confirmStart(
      explicitStartTime: capturedStart,
    );
    _commitInFlight = false;
  }

  Future<void> _confirmStart({DateTime? explicitStartTime}) async {
    final parsed = _parseResult;
    if (parsed == null || !parsed.isSafeToStart) return;
    final loc = currentLocale.value;
    DesktopVoiceLog.instance.mark('writeRecord_called', 'yes');
    _setPhase(
      DesktopVoiceOverlayPhase.processing,
      status: t(loc, 'desktop_voice_starting'),
    );
    try {
      final docId = await widget.onStartRecord(
        parsed,
        explicitStartTime: explicitStartTime,
      );
      if (!mounted) return;
      if (docId == null || docId.trim().isEmpty) {
        DesktopVoiceLog.instance.mark('writeRecord_result', 'failed');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_WRITE_RECORD_FAILED');
        DesktopVoiceAttemptLog.instance.markSubmission(
          serverId: null,
          error: 'writeRecord returned no id',
        );
        _fail(t(loc, 'sync_failed_retry'), diag: 'writeRecord_failed');
        return;
      }
      DesktopVoiceLog.instance.mark('writeRecord_result', 'ok $docId');
      DesktopVoiceAttemptLog.instance.markSubmission(serverId: docId);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_WRITE_RECORD_SUCCESS');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_TIMELINE_RUNNING_RECORD_VISIBLE');
      _startedRecordDocId = docId;
      final confirmation = voiceCommandStartConfirmationMessage(
        parsed,
        localeCode: loc,
      );
      _setPhase(
        DesktopVoiceOverlayPhase.started,
        status: confirmation,
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_CONFIRMATION_SHOWN');
      DesktopVoiceSettings.instance.setVoiceStatusLine(
        t(loc, 'desktop_voice_state_started'),
      );
      await DesktopVoiceOverlayService.showStarted(
        confirmationLine: confirmation,
      );
      if (DesktopVoiceSettings.instance.autoCloseAfterApply) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_AUTO_CLOSE_SUCCESS');
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        if (mounted) widget.onClose();
      }
    } catch (e) {
      if (!mounted) return;
      DesktopVoiceLog.instance.mark('writeRecord_result', 'error $e');
      DesktopVoiceAttemptLog.instance.markSubmission(
        serverId: null,
        error: e.toString(),
      );
      _fail(t(loc, 'sync_failed_retry'), diag: e.toString());
    }
  }

  void _failFriendly(
    Object? error, {
    String? message,
    required String diag,
    required DesktopVoiceErrorStage stage,
    DesktopVoiceOverlayPhase phase = DesktopVoiceOverlayPhase.error,
    bool recordingFailed = false,
    DesktopVoiceFailureKind? kind,
    Duration? autoCloseAfter,
  }) {
    final loc = currentLocale.value;
    final mapped = DesktopVoiceUserError.resolve(
      message: message,
      error: error,
      stage: stage,
      localeCode: loc,
      kind: kind,
    );
    _fail(
      mapped.message,
      diag: diag,
      phase: phase,
      recordingFailed: recordingFailed,
      technicalDetail: mapped.technicalDetail,
      autoCloseAfter: autoCloseAfter,
    );
  }

  void _fail(
    String message, {
    required String diag,
    DesktopVoiceOverlayPhase phase = DesktopVoiceOverlayPhase.error,
    bool recordingFailed = false,
    String? technicalDetail,
    Duration? autoCloseAfter,
  }) {
    if (recordingFailed) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_RECORDING_FAILED', diag);
    }
    DesktopVoiceLog.instance.mark('error', diag);
    if (technicalDetail != null && technicalDetail.isNotEmpty) {
      DesktopVoiceLog.instance.mark('error_technical', technicalDetail);
    }
    DesktopVoiceSettings.instance.setVoiceStatusLine(
      t(currentLocale.value, 'desktop_voice_state_error'),
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_ERROR_VISIBLE', diag);
    _setPhase(phase, status: message);
    if (autoCloseAfter != null) {
      unawaited(
        Future<void>.delayed(autoCloseAfter, () {
          if (mounted) widget.onClose();
        }),
      );
    }
  }

  void _setPhase(
    DesktopVoiceOverlayPhase phase, {
    String? status,
    String? error,
  }) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      if (status != null) _statusLine = status;
      if (error != null) {
        _errorDetail = error;
      } else if (phase != DesktopVoiceOverlayPhase.error) {
        _errorDetail = null;
      }
    });
    _syncOverlayVisual(phase);
    switch (phase) {
      case DesktopVoiceOverlayPhase.listening:
      case DesktopVoiceOverlayPhase.preparing:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STATE_LISTENING');
      case DesktopVoiceOverlayPhase.processing:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STATE_PROCESSING');
      case DesktopVoiceOverlayPhase.pendingConfirmation:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STATE_PENDING_CONFIRMATION');
      case DesktopVoiceOverlayPhase.started:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STATE_SUCCESS');
      case DesktopVoiceOverlayPhase.error:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STATE_ERROR');
      case DesktopVoiceOverlayPhase.stopped:
        break;
    }
  }

  void _syncOverlayVisual(DesktopVoiceOverlayPhase phase) {
    final loc = currentLocale.value;
    final timer = _formatTimer();
    switch (phase) {
      case DesktopVoiceOverlayPhase.preparing:
        unawaited(DesktopVoiceOverlayService.showListening(timer: timer, level: _micLevel));
      case DesktopVoiceOverlayPhase.listening:
        unawaited(
          DesktopVoiceOverlayService.showListening(
            timer: timer,
            level: _micLevel,
          ),
        );
      case DesktopVoiceOverlayPhase.processing:
        unawaited(
          DesktopVoiceOverlayService.showProcessing(
            timer: timer,
          ),
        );
      case DesktopVoiceOverlayPhase.pendingConfirmation:
        break;
      case DesktopVoiceOverlayPhase.started:
        break;
      case DesktopVoiceOverlayPhase.stopped:
        break;
      case DesktopVoiceOverlayPhase.error:
        unawaited(
          DesktopVoiceOverlayService.showError(
            message: loc == 'ru' ? 'Не удалось распознать' : 'Could not recognize',
            detail: _transcript.trim().isNotEmpty
                ? _transcript.trim()
                : (_errorDetail ?? _statusLine.trim()),
          ),
        );
    }
  }

  Future<void> _cancelSession({bool fromUser = false}) async {
    if (_sessionCancelled && _phase == DesktopVoiceOverlayPhase.error) {
      if (fromUser) widget.onClose();
      return;
    }
    if (_cancelling) return;

    if (_phase == DesktopVoiceOverlayPhase.processing) {
      _cancelling = true;
      final loc = currentLocale.value;
      _setPhase(
        DesktopVoiceOverlayPhase.processing,
        status: t(loc, 'desktop_voice_cancelling'),
      );
    }

    _sessionCancelled = true;
    _confirmTimer.cancel();
    _listenTimer?.cancel();
    _noSignalTimer?.cancel();
    _uiTimer?.cancel();
    _ampSub?.cancel();
    await _recognizer?.cancelCapture();
    _recognizer?.dispose();
    _recognizer = null;

    DesktopVoicePipeline.mark('DESKTOP_VOICE_SESSION_CANCELLED');
    DesktopVoiceAttemptLog.instance.markCancelled();
    await DesktopVoiceOverlayService.forceHide();
    if (mounted) widget.onClose();
  }

  Future<void> _onRetry() async {
    _sessionCancelled = false;
    _cancelling = false;
    _transcript = '';
    _parseResult = null;
    _errorDetail = null;
    _startedRecordDocId = null;
    _micLevel = 0;
    _audioLevelSeen = false;
    _audioBytes = 0;
    _recordStopwatch = Stopwatch()..start();
    _uiTimer ??= Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) setState(() {});
    });
    final loc = currentLocale.value;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_PREPARING_UI');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_FIRST_VISIBLE_STATE_LISTENING');
    _setPhase(
      DesktopVoiceOverlayPhase.listening,
      status: t(loc, 'desktop_voice_state_listening'),
    );
    unawaited(DesktopVoiceOverlayService.showListening(timer: _formatTimer()));
    await _beginSessionRecordingFirst();
  }

  Future<void> _onCancel() => _cancelSession(fromUser: true);

  String _formatTimer() {
    final ms = _recordStopwatch?.elapsedMilliseconds ?? 0;
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final rs = s % 60;
    return '${m.toString().padLeft(2, '0')}:${rs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final pending = _phase == DesktopVoiceOverlayPhase.pendingConfirmation;
    final listening = _phase == DesktopVoiceOverlayPhase.listening;
    final preparing = _phase == DesktopVoiceOverlayPhase.preparing;
    final processing = _phase == DesktopVoiceOverlayPhase.processing;
    final started = _phase == DesktopVoiceOverlayPhase.started;
    final stopped = _phase == DesktopVoiceOverlayPhase.stopped;
    final isError = _phase == DesktopVoiceOverlayPhase.error;

    String primary;
    String? secondary;
    var showMic = false;
    var showSpinner = false;
    String? timer;
    VoidCallback? onCancel;
    VoidCallback? onRetry;
    VoidCallback? onTap;
    double? progressFill;

    if (preparing) {
      primary = t(loc, 'desktop_voice_state_listening');
      showMic = true;
      timer = _formatTimer();
      onCancel = _onCancel;
    } else if (listening) {
      primary = t(loc, 'desktop_voice_state_listening');
      showMic = true;
      timer = _formatTimer();
      onCancel = _onCancel;
    } else if (processing) {
      primary = t(loc, 'desktop_voice_transcribing');
      showSpinner = true;
    } else if (pending) {
      primary = _statusLine.trim().isEmpty
          ? t(loc, 'desktop_voice_state_preview')
          : _statusLine.trim();
      secondary = t(loc, 'desktop_voice_tap_to_edit');
      progressFill = _confirmProgress;
      onTap = () => unawaited(_openCorrection());
      onCancel = () => unawaited(_cancelPendingConfirmation());
    } else if (started || stopped) {
      primary = started
          ? t(loc, 'desktop_voice_state_started')
          : t(loc, 'desktop_voice_state_stopped');
      secondary = _statusLine.trim().isEmpty ? null : _statusLine.trim();
    } else if (isError) {
      primary = _statusLine.trim().isEmpty
          ? t(loc, 'desktop_voice_state_error')
          : _statusLine.trim();
      secondary = _errorDetail;
      onRetry = _onRetry;
      onCancel = _onCancel;
    } else {
      primary = _statusLine;
      onCancel = _onCancel;
    }

    if (DesktopVoiceOverlayService.usesNativeOverlay) {
      return const SizedBox.shrink();
    }

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _DesktopVoiceEscapeIntent(),
      },
      child: Actions(
        actions: {
          _DesktopVoiceEscapeIntent: CallbackAction<_DesktopVoiceEscapeIntent>(
            onInvoke: (_) {
              unawaited(_onCancel());
              return null;
            },
          ),
        },
        child: DesktopVoiceCapsule(
          primaryLine: primary,
          secondaryLine: secondary,
          showMic: showMic,
          showSpinner: showSpinner,
          micLevel: _micLevel,
          timerText: timer,
          onCancel: onCancel,
          onRetry: onRetry,
          isError: isError,
          progressFill: progressFill,
          onTap: onTap,
          accentColor: Theme.of(context).colorScheme.primary,
          compactActions: pending,
        ),
      ),
    );
  }
}

OverlayEntry? _desktopVoiceOverlayEntry;
Timer? _desktopVoiceStatusTimer;
bool _desktopVoiceSessionActive = false;

bool get isDesktopVoiceOverlayOpen => _desktopVoiceSessionActive;

Future<void> _closeDesktopVoiceOverlayEntry() async {
  _desktopVoiceStatusTimer?.cancel();
  _desktopVoiceStatusTimer = null;
  _desktopVoiceOverlayEntry?.remove();
  _desktopVoiceOverlayEntry = null;
  _desktopVoiceSessionActive = false;
  DesktopVoiceOverlayBridge.notifyOverlayClosed();
  await DesktopVoiceOverlayService.forceHide();
}

Future<bool> showDesktopVoiceWidget({
  required BuildContext context,
  required List<CategoryRule> categoryRules,
  required DesktopVoiceStartRecordFn onStartRecord,
  Future<void> Function(String? recordDocId)? onUndoStop,
}) async {
  if (_desktopVoiceSessionActive) return false;

  DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_HOST_REQUESTED');
if (DesktopVoiceOverlayService.usesNativeOverlay) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_FIRST_VISIBLE_STATE_LISTENING');
    final nativeOk = await DesktopVoiceOverlayService.showListening(
      timer: '00:00',
    );
if (!nativeOk) {
      await DesktopVoiceOverlayService.notifyNativeOverlayUnavailable();
      DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_BLOCKED', 'native_failed');
      return false;
    }
  }

  final overlay = appRootNavigatorKey.currentState?.overlay;
  if (overlay == null) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_BLOCKED', 'no_overlay');
    if (DesktopVoiceOverlayService.usesNativeOverlay) {
      await DesktopVoiceOverlayService.hide();
    }
    return false;
  }

  DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_OPEN_REQUESTED');

  void closeOverlay() {
    unawaited(_closeDesktopVoiceOverlayEntry());
  }

  try {
    _desktopVoiceSessionActive = true;
    _desktopVoiceOverlayEntry = OverlayEntry(
      builder: (ctx) => DesktopVoiceOverlay(
        categoryRules: categoryRules,
        onStartRecord: onStartRecord,
        onUndoStop: onUndoStop,
        onClose: closeOverlay,
      ),
    );

    overlay.insert(_desktopVoiceOverlayEntry!);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_OPENED', 'session');
    return true;
  } catch (e) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_HOTKEY_ERROR_CAUGHT', '$e');
    await _closeDesktopVoiceOverlayEntry();
    return false;
  }
}

/// Brief stop/start status capsule (hotkey stop without full voice session).
Future<void> showDesktopVoiceStatusCapsule({
  required String primaryLine,
  String? secondaryLine,
  Duration hold = const Duration(seconds: 2),
}) async {
  if (_desktopVoiceSessionActive) return;

  if (DesktopVoiceOverlayService.usesNativeOverlay) {
    final ok = await DesktopVoiceOverlayService.showStopped(
      titleLine: secondaryLine ?? primaryLine,
      hold: hold,
    );
    if (!ok) {
      await DesktopVoiceOverlayService.notifyNativeOverlayUnavailable();
    }
    return;
  }

  final overlay = appRootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;

  DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_OPEN_REQUESTED', 'status');

  void closeOverlay() {
    unawaited(_closeDesktopVoiceOverlayEntry());
  }

  try {
    _desktopVoiceSessionActive = true;
    _desktopVoiceOverlayEntry = OverlayEntry(
      builder: (ctx) => DesktopVoiceCapsule(
        primaryLine: primaryLine,
        secondaryLine: secondaryLine,
        showMic: false,
        showSpinner: false,
        micLevel: 0,
      ),
    );
    overlay.insert(_desktopVoiceOverlayEntry!);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_CONFIRMATION_SHOWN');

    _desktopVoiceStatusTimer?.cancel();
    _desktopVoiceStatusTimer = Timer(hold, closeOverlay);
  } catch (e) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_HOTKEY_ERROR_CAUGHT', '$e');
    await _closeDesktopVoiceOverlayEntry();
  }
}

class _DesktopVoiceEscapeIntent extends Intent {
  const _DesktopVoiceEscapeIntent();
}

/// Closes the desktop voice overlay if open (e.g. on app exit).
void closeDesktopVoiceOverlayIfOpen() {
  if (!_desktopVoiceSessionActive) return;
  unawaited(_closeDesktopVoiceOverlayEntry());
}
