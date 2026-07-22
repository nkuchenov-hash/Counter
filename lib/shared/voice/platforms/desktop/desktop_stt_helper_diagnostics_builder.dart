part of 'desktop_stt_helper_service.dart';

/// Assembles [DesktopSttDiagnostics], WAV duration fallbacks, and last-attempt persistence.
extension DesktopSttHelperDiagnosticsBuilder on DesktopSttHelperService {
  Future<void> _updateDiagnostics({
    DesktopVoiceCaptureResult? capture,
    DesktopVoiceEngineId? engine,
    String? transcript,
    String? error,
    int? latencyMs,
  }) async {
    final e = engine ?? resolveProductionEngine();
    final model = modelPathFor(e);
    final helperExe = helperPath;
    final helperExeExists = helperExe != null && File(helperExe).existsSync();
    final settingsExePath = helperSettingsPath;
    final settingsExists =
        settingsExePath != null && File(settingsExePath).existsSync();
    final modelDirExists =
        model != null && Directory(model).existsSync();
    final modelFilesCount = modelDirExists
        ? Directory(model).listSync(followLinks: false).whereType<File>().length
        : 0;
    final latestWav = capture?.wavPath ?? _capture.lastWavPath;
    final latestWavExists =
        latestWav != null && File(latestWav).existsSync();
    final latestWavBytes =
        latestWavExists ? await File(latestWav).length() : 0;
    final rawWavPath = capture?.rawWavPath ?? _capture.lastRawWavPath;
    final rawWavExists =
        rawWavPath != null && File(rawWavPath).existsSync();
    final overlayRenderer = DesktopVoiceOverlayService.usesNativeOverlay
        ? 'native_handy_pill'
        : 'flutter_capsule';
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_OVERLAY_RENDERER_ACTIVE',
      overlayRenderer,
    );
    _lastDiagnostics = DesktopSttDiagnostics(
      helperPath: helperExe,
      helperExists: helperExeExists,
      helperWorkingDirectory:
          helperExe == null ? null : File(helperExe).parent.path,
      helperSettingsPath: settingsExePath,
      helperSettingsExists: settingsExists,
      modelPath: model,
      modelExists: modelDirExists,
      modelFilesCount: modelFilesCount,
      modelLoaded: e == DesktopVoiceEngineId.windowsSpeech || _finalTranscribeReady,
      helperSpawnAttempted: _spawnAttempted,
      helperPid: helperPid,
      helperProcessAlive: await _helperExitCodeIfAnyLive() == null,
      helperExitCode: _helperExitCodeObserved,
      helperStdoutTail: _helperStdoutTailJoined,
      helperStderrTail: _helperStderrTailJoined,
      helperPort: DesktopSttHelperService._port,
      helperStatusUrl: DesktopSttHelperService._statusUrl,
      helperStatusHttpResult: _lastStatusHttpResult,
      helperStatusResponseBody: _lastStatusBody,
      helperReady: _ready && _finalTranscribeReady,
      transcribeEndpoint: DesktopSttHelperService._transcribeStopEndpoint,
      transcribeCalled: _transcribeCalled,
      transcribeHttpResult: _lastTranscribeHttpResult,
      transcribeErrorKind: _lastTranscribeErrorKind,
      transcribeErrorDetail: _lastTranscribeErrorDetail,
      transcribeResponseBodyTail: _lastTranscribeResponseBodyTail,
      pcmChunksCount: _capture.pcmChunksCount,
      rmsMin: _capture.rmsMin,
      rmsMax: _capture.rmsMax,
      peakMax: _capture.peakMax,
      overlayLevelEventsCount:
          _overlayLevelEventsCount + _capture.overlayLevelEventsCount,
      latestWavPath: latestWav,
      latestWavExists: latestWavExists,
      latestWavBytes: latestWavBytes,
      latestWavDurationMs: await _resolveWavDurationMs(
        capture: capture,
        latestWav: latestWav,
        latestWavExists: latestWavExists,
      ),
      latestRawWavPath: rawWavPath,
      latestRawWavExists: rawWavExists,
      latestRawWavSampleRate:
          capture?.rawSampleRate ?? _capture.captureSampleRate,
      latestRawWavChannels:
          capture?.rawChannels ?? _capture.captureChannels,
      latestRawWavFormat:
          capture?.rawCaptureFormat ?? _capture.rawCaptureFormat,
      latestRawWavDurationMs: await _resolveRawWavDurationMs(
        capture: capture,
        rawWavPath: rawWavPath,
        rawWavExists: rawWavExists,
      ),
      processedWavPath: latestWav,
      processedWavSampleRate: capture?.sampleRate ?? kVoiceSampleRate,
      processedWavChannels: capture?.channels ?? kVoiceChannels,
      pendingWavAfterStop: _pendingWavAfterStop,
      helperReadyAfterRecording: _helperReadyAfterRecording,
      delayedTranscribeCalled: _delayedTranscribeCalled,
      delayedTranscribeResult: _delayedTranscribeResult,
      failureReason: _failureReason ?? error ?? _lastError,
      overlayRendererActive: overlayRenderer,
      captureBackend: capture?.captureBackend ?? _capture.captureBackend,
      captureApi: capture?.captureApi ?? _capture.captureApi,
      rawCaptureFormat:
          capture?.rawCaptureFormat ?? _capture.rawCaptureFormat,
      rawCaptureRms: capture?.rawRms ?? _capture.rawCaptureRms,
      rawCapturePeak: capture?.rawPeak ?? _capture.rawCapturePeak,
      processedWavRms:
          capture?.processedWavRms ?? _capture.processedWavRms,
      processedWavPeak:
          capture?.processedWavPeak ?? _capture.processedWavPeak,
      sessionVolume: capture?.sessionVolume ?? _capture.sessionVolume,
      endpointVolume: capture?.endpointVolume ?? _capture.endpointVolume,
      endpointId: _capture.endpointSnapshot?.endpointId,
      endpointRole: _capture.endpointSnapshot?.endpointRole,
      consoleDefaultDevice: _capture.endpointSnapshot?.consoleDefaultDevice,
      communicationsDefaultDevice:
          _capture.endpointSnapshot?.communicationsDefaultDevice,
      captureGainMode: _capture.endpointSnapshot?.captureGainMode,
      captureGainDb: _capture.endpointSnapshot?.captureGainDb,
      selectedGainReason: _capture.endpointSnapshot?.selectedGainReason,
      selectedCaptureEndpoint: capture?.deviceLabel ??
          _capture.audioDeviceLabel ??
          _capture.endpointSnapshot?.consoleDefaultDevice,
      captureMixFormat: _formatCaptureMix(_capture.endpointSnapshot),
      engine: e.helperEngineId,
      languageHint: e == DesktopVoiceEngineId.windowsSpeech ? 'en-US' : 'en',
      audioDevice: capture?.deviceLabel ??
          _capture.audioDeviceLabel ??
          'default',
      sampleRate: capture?.sampleRate ?? kVoiceSampleRate,
      channels: capture?.channels ?? kVoiceChannels,
      audioBytes: capture?.pcmBytes.length ?? _lastCaptureBytes,
      audioDurationMs: capture?.durationMs ??
          (latestWavExists && latestWav != null
              ? await wavFileDurationMs(latestWav)
              : 0),
      maxAmplitude: capture?.maxAmplitude ?? _capture.maxAmplitude,
      rmsAmplitude: capture?.rmsAmplitude ?? _capture.rmsAmplitude,
      audioLevelSeen: capture?.audioLevelSeen ?? _capture.audioLevelSeen,
      audioFile: capture?.wavPath ?? _capture.lastWavPath,
      transcript: transcript,
      error: error ?? _lastError,
      latencyMs: latencyMs,
      finalTranscribeReady: _finalTranscribeReady,
      helperModelLoaded: _helperModelLoaded,
      helperWarmupDone: _helperWarmupDone,
      reasonIfNotReady: _reasonIfNotReady,
      primarySttEngine: _primarySttEngine ?? e.helperEngineId,
      primarySttResult: _primarySttResult,
      fallbackSttAttempted: _fallbackSttAttempted,
      fallbackSttEngine: _fallbackSttEngine,
      fallbackSttResult: _fallbackSttResult,
      finalTranscriptSource: _finalTranscriptSource,
      partialText: _partialText,
      finalText: _finalText ?? transcript,
      usedPartialAsFinal: _usedPartialAsFinal,
      stopReturnReason: _stopReturnReason,
      finalInferenceLatencyMs: _finalInferenceLatencyMs,
      stopToFirstCandidateMs: _stopToFirstCandidateMs,
      stopToFinalTextMs: _stopToFinalTextMs,
      stopToUsefulCandidateMs: _stopToUsefulCandidateMs,
      candidateText: _candidateText,
      candidateParseStatus: _candidateParseStatus,
      candidateUseful: _candidateUseful,
      candidateVisibleToUser: _candidateVisibleToUser,
      audioDurationMsUsedForInference: _audioDurationMsUsedForInference,
      levelMeterRms: _capture.levelMeterRms,
      levelMeterDisplayLevel: _capture.levelMeterDisplayLevel,
      levelMeterGain: _capture.levelMeterGain,
      levelMeterPeakHold: _capture.levelMeterPeakHold,
      sttGainMode: _sttGainMode,
      sttGainDb: _sttGainDb,
      targetRms: _targetRms,
      rawRmsBeforeGain: _rawRmsBeforeGain,
      rawPeakBeforeGain: _rawPeakBeforeGain,
      processedRmsAfterGain: _processedRmsAfterGain,
      processedPeakAfterGain: _processedPeakAfterGain,
      clippedSamplesAfterGain: _clippedSamplesAfterGain,
      sttTranscriptWithoutGain: _sttTranscriptWithoutGain,
      sttTranscriptWithGain: _sttTranscriptWithGain,
      sttGainRejectedReason: _sttGainRejectedReason,
      overlayMinFontPt: 16,
      overlayTitleFontPt: 17,
      overlayDetailFontPt: 16,
      captureStreamStarted: _capture.captureStreamStarted,
      firstAudioFrameReceived: _capture.firstAudioFrameReceived,
      firstNonSilentFrameMs: _capture.firstNonSilentFrameMs,
      noSignalDetected: _capture.noSignalDetected,
      noSignalReason: _capture.noSignalReason,
      captureStreamError: _capture.captureStreamError,
      levelSource: _capture.levelSource,
      levelStreamConnected: _capture.levelStreamConnected,
      readyCueEnabled: DesktopVoiceReadyCue.enabled,
      readyCueDurationMs:
          DesktopVoiceCaptureReadyPolicy.readyCueDurationMs,
      readyCuePlayRequested: DesktopVoiceReadyCue.playRequested,
      readyCuePlayed: DesktopVoiceReadyCue.playedThisSession,
      readyCueOutputOk: DesktopVoiceReadyCue.outputOk,
      readyCueOutputDevice: DesktopVoiceReadyCue.outputDevice,
      readyCueError: DesktopVoiceReadyCue.lastError,
      readyCuePlayedMs: DesktopVoiceReadyCue.playedAtMs,
      readyCueDetectedInInput: 'unknown',
      readyCueTrimmedFromSttCopy: false,
      firstAudioCallbackBeforeCue: DesktopVoiceCaptureReadyPolicy
          .firstAudioBeforeCue(
        firstAudioCallbackMs:
            _capture.firstAudioCallbackAt?.millisecondsSinceEpoch,
        readyCuePlayedMs: DesktopVoiceReadyCue.playedAtMs,
      ),
      captureReadyBeforeCue: DesktopVoiceCaptureReadyPolicy
          .recordingStartedBeforeCue(
        captureStreamStartedMs:
            _capture.captureStreamStartedAt?.millisecondsSinceEpoch,
        readyCuePlayedMs: DesktopVoiceReadyCue.playedAtMs,
      ),
      cuePlaybackSmokePass: DesktopVoiceReadyCue.cuePlaybackSmokePass,
      overlayWindowTransparent:
          DesktopVoiceNativeOverlay.lastWindowTransparent,
      overlayBackgroundMode:
          DesktopVoiceNativeOverlay.lastBackgroundMode,
      overlayRootBackgroundColor: DesktopVoiceNativeOverlay
              .lastWindowTransparent
          ? 'transparent_colorkey_black'
          : 'opaque',
      overlayCardBackgroundColor: 'rgb(28,28,30)',
      overlayHasBackdrop: DesktopVoiceNativeOverlay.lastHasBackdrop,
      overlayBlackBackdropDetected:
          DesktopVoiceNativeOverlay.lastBlackBackdropDetected,
      overlayWindowFlags: DesktopVoiceNativeOverlay.lastWindowFlags,
      preRollMsConfigured: DesktopVoiceCaptureReadyPolicy.preRollMs,
      leadingPadMsInSttCopy: DesktopVoiceCaptureReadyPolicy.sttLeadingPadMs,
      startTrimGuardApplied: true,
      hotkeyToCaptureStreamMs: _msBetween(
        _capture.hotkeyReceivedAt,
        _capture.captureStreamStartedAt,
      ),
      captureStreamToFirstAudioCallbackMs: _msBetween(
        _capture.captureStreamStartedAt,
        _capture.firstAudioCallbackAt,
      ),
      firstAudioCallbackToReadyCueMs: _msBetween(
        _capture.firstAudioCallbackAt,
        _capture.readyCuePlayedAt,
      ),
      readyCueToFirstSpeechMs: _readyCueToSpeechMs(),
      leadingAudioPreservedMs:
          DesktopVoiceCaptureReadyPolicy.preRollMs +
              DesktopVoiceCaptureReadyPolicy.sttLeadingPadMs,
    );
    unawaited(
      DesktopVoiceLastAttemptStore.write(
        diag: _lastDiagnostics,
        friendlyError: error ?? _lastError,
      ),
    );
  }

  Future<int> _resolveRawWavDurationMs({
    DesktopVoiceCaptureResult? capture,
    String? rawWavPath,
    required bool rawWavExists,
  }) async {
    var ms = capture?.rawDurationMs ?? 0;
    if (ms <= 0 && rawWavExists && rawWavPath != null) {
      ms = await wavFileDurationMs(rawWavPath);
      if (ms > 0) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_RAW_F32_WAV_DURATION_FIXED');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_RAW_WAV_DURATION_MS', '$ms');
      }
    }
    return ms;
  }

  Future<int> _resolveWavDurationMs({
    DesktopVoiceCaptureResult? capture,
    String? latestWav,
    required bool latestWavExists,
  }) async {
    var ms = capture?.durationMs ?? 0;
    if (ms == 0 && capture != null && capture.pcmBytes.isNotEmpty) {
      ms = pcm16DurationMs(capture.pcmBytes);
    }
    if (ms == 0 && latestWavExists && latestWav != null) {
      ms = await wavFileDurationMs(latestWav);
      if (ms > 0) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_WAV_DURATION_FIXED');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_WAV_DURATION_MS', '$ms');
      }
    }
    return ms;
  }

  Future<DesktopSttDiagnostics> fetchDiagnostics({
    String? transcript,
    String? error,
  }) async {
    final e = resolveProductionEngine();
    if (e != DesktopVoiceEngineId.windowsSpeech) {
      await ensureStarted(engine: e);
    }
    await _updateDiagnostics(transcript: transcript, error: error);
    return _lastDiagnostics;
  }

  int? _readyCueToSpeechMs() {
    final cue = _capture.readyCuePlayedAt;
    final started = _capture.captureStreamStartedAt;
    final speechMs = _capture.firstNonSilentFrameMs;
    if (cue == null || started == null || speechMs == null) return null;
    final speechAt = started.add(Duration(milliseconds: speechMs));
    return speechAt.difference(cue).inMilliseconds;
  }
}

String? _formatCaptureMix(DesktopVoiceCaptureEndpointSnapshot? snap) {
  if (snap == null) return null;
  final rate = snap.mixSampleRate;
  final ch = snap.mixChannels;
  final fmt = snap.mixSampleFormat;
  if (rate == null && ch == null && (fmt == null || fmt.isEmpty)) return null;
  return '${rate ?? '—'}Hz ${ch ?? '—'}ch ${fmt ?? '—'}';
}

int? _msBetween(DateTime? a, DateTime? b) {
  if (a == null || b == null) return null;
  return b.difference(a).inMilliseconds;
}
