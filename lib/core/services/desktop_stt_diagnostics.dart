/// Last STT / voice capture diagnostic snapshot for Settings display.
///
/// Carries every field a non-developer-facing diagnostics view needs to
/// pinpoint why the recognizer failed (helper missing / model not loaded /
/// port busy / connection closed / partial load race / missing WAV / …)
/// without the user having to read pipeline logs.
class DesktopSttDiagnostics {
  const DesktopSttDiagnostics({
    this.helperPath,
    this.helperExists = false,
    this.helperWorkingDirectory,
    this.helperSettingsPath,
    this.helperSettingsExists = false,
    this.modelPath,
    this.modelExists = false,
    this.modelFilesCount = 0,
    this.modelLoaded = false,
    this.helperSpawnAttempted = false,
    this.helperPid,
    this.helperProcessAlive = false,
    this.helperExitCode,
    this.helperStdoutTail = '',
    this.helperStderrTail = '',
    this.helperPort,
    this.helperStatusUrl,
    this.helperStatusHttpResult,
    this.helperStatusResponseBody,
    this.helperReady = false,
    this.transcribeEndpoint,
    this.transcribeCalled = false,
    this.transcribeHttpResult,
    this.transcribeErrorKind,
    this.transcribeErrorDetail,
    this.transcribeResponseBodyTail = '',
    this.pcmChunksCount = 0,
    this.rmsMin = 0,
    this.rmsMax = 0,
    this.peakMax = 0,
    this.overlayLevelEventsCount = 0,
    this.latestWavPath,
    this.latestWavExists = false,
    this.latestWavBytes = 0,
    this.latestWavDurationMs = 0,
    this.latestRawWavPath,
    this.latestRawWavExists = false,
    this.latestRawWavSampleRate = 0,
    this.latestRawWavChannels = 0,
    this.latestRawWavFormat = '',
    this.latestRawWavDurationMs = 0,
    this.processedWavPath,
    this.processedWavSampleRate = 0,
    this.processedWavChannels = 0,
    this.pendingWavAfterStop = false,
    this.helperReadyAfterRecording = false,
    this.delayedTranscribeCalled = false,
    this.delayedTranscribeResult,
    this.failureReason,
    this.overlayRendererActive,
    this.engine,
    this.languageHint = 'en-US',
    this.audioDevice = 'default',
    this.sampleRate = 16000,
    this.channels = 1,
    this.audioBytes = 0,
    this.audioDurationMs = 0,
    this.maxAmplitude = 0,
    this.rmsAmplitude = 0,
    this.audioLevelSeen = false,
    this.audioFile,
    this.transcript,
    this.error,
    this.latencyMs,
    this.finalTranscribeReady = false,
    this.helperModelLoaded = false,
    this.helperWarmupDone = false,
    this.reasonIfNotReady = '',
    this.primarySttEngine,
    this.primarySttResult,
    this.fallbackSttAttempted = false,
    this.fallbackSttEngine,
    this.fallbackSttResult,
    this.finalTranscriptSource,
    this.partialText,
    this.finalText,
    this.usedPartialAsFinal = false,
    this.stopReturnReason,
    this.finalInferenceLatencyMs,
  });

  final String? helperPath;
  final bool helperExists;
  final String? helperWorkingDirectory;
  final String? helperSettingsPath;
  final bool helperSettingsExists;
  final String? modelPath;
  final bool modelExists;
  final int modelFilesCount;
  final bool modelLoaded;
  final bool helperSpawnAttempted;
  final int? helperPid;
  final bool helperProcessAlive;
  final int? helperExitCode;
  final String helperStdoutTail;
  final String helperStderrTail;
  final int? helperPort;
  final String? helperStatusUrl;
  final String? helperStatusHttpResult;
  final String? helperStatusResponseBody;
  final bool helperReady;
  final String? transcribeEndpoint;
  final bool transcribeCalled;
  final String? transcribeHttpResult;
  final String? transcribeErrorKind;
  final String? transcribeErrorDetail;
  final String transcribeResponseBodyTail;
  final int pcmChunksCount;
  final double rmsMin;
  final double rmsMax;
  final double peakMax;
  final int overlayLevelEventsCount;
  final String? latestWavPath;
  final bool latestWavExists;
  final int latestWavBytes;
  final int latestWavDurationMs;
  final String? latestRawWavPath;
  final bool latestRawWavExists;
  final int latestRawWavSampleRate;
  final int latestRawWavChannels;
  final String latestRawWavFormat;
  final int latestRawWavDurationMs;
  final String? processedWavPath;
  final int processedWavSampleRate;
  final int processedWavChannels;
  final bool pendingWavAfterStop;
  final bool helperReadyAfterRecording;
  final bool delayedTranscribeCalled;
  final String? delayedTranscribeResult;
  final String? failureReason;
  final String? overlayRendererActive;
  final String? engine;
  final String languageHint;
  final String audioDevice;
  final int sampleRate;
  final int channels;
  final int audioBytes;
  final int audioDurationMs;
  final double maxAmplitude;
  final double rmsAmplitude;
  final bool audioLevelSeen;
  final String? audioFile;
  final String? transcript;
  final String? error;
  final int? latencyMs;
  final bool finalTranscribeReady;
  final bool helperModelLoaded;
  final bool helperWarmupDone;
  final String reasonIfNotReady;
  final String? primarySttEngine;
  final String? primarySttResult;
  final bool fallbackSttAttempted;
  final String? fallbackSttEngine;
  final String? fallbackSttResult;
  final String? finalTranscriptSource;
  final String? partialText;
  final String? finalText;
  final bool usedPartialAsFinal;
  final String? stopReturnReason;
  final int? finalInferenceLatencyMs;

  List<String> toDiagLines() {
    return [
      'STT_HELPER_CHECK',
      'helper_expected_path=${helperPath ?? '—'}',
      'helper_exists=${helperExists ? 'yes' : 'no'}',
      'helper_working_directory=${helperWorkingDirectory ?? '—'}',
      'helper_settings_path=${helperSettingsPath ?? '—'}',
      'helper_settings_exists=${helperSettingsExists ? 'yes' : 'no'}',
      'model_expected_path=${modelPath ?? '—'}',
      'model_exists=${modelExists ? 'yes' : 'no'}',
      'model_files_count=$modelFilesCount',
      'model_loaded=${modelLoaded ? 'yes' : 'no'}',
      'helper_spawn_attempted=${helperSpawnAttempted ? 'yes' : 'no'}',
      'helper_pid=${helperPid ?? '—'}',
      'helper_process_alive=${helperProcessAlive ? 'yes' : 'no'}',
      'helper_exit_code=${helperExitCode == null ? '—' : helperExitCode.toString()}',
      'helper_stdout_tail=${helperStdoutTail.isEmpty ? '—' : helperStdoutTail}',
      'helper_stderr_tail=${helperStderrTail.isEmpty ? '—' : helperStderrTail}',
      'helper_port=${helperPort ?? '—'}',
      'helper_status_url=${helperStatusUrl ?? '—'}',
      'helper_status_http_result=${helperStatusHttpResult ?? '—'}',
      'helper_status_response_body=${helperStatusResponseBody ?? '—'}',
      'helper_ready=${helperReady ? 'yes' : 'no'}',
      'final_transcribe_ready=${finalTranscribeReady ? 'yes' : 'no'}',
      'helper_model_loaded=${helperModelLoaded ? 'yes' : 'no'}',
      'helper_warmup_done=${helperWarmupDone ? 'yes' : 'no'}',
      'reason_if_not_ready=${reasonIfNotReady.isEmpty ? '—' : reasonIfNotReady}',
      'primary_stt_engine=${primarySttEngine ?? '—'}',
      'primary_stt_result=${primarySttResult ?? '—'}',
      'fallback_stt_attempted=${fallbackSttAttempted ? 'yes' : 'no'}',
      'fallback_stt_engine=${fallbackSttEngine ?? '—'}',
      'fallback_stt_result=${fallbackSttResult ?? '—'}',
      'final_transcript_source=${finalTranscriptSource ?? '—'}',
      'partial_text=${partialText ?? '—'}',
      'final_text=${finalText ?? '—'}',
      'used_partial_as_final=${usedPartialAsFinal ? 'yes' : 'no'}',
      'stop_return_reason=${stopReturnReason ?? '—'}',
      'final_inference_latency_ms=${finalInferenceLatencyMs ?? '—'}',
      'transcribe_endpoint=${transcribeEndpoint ?? '—'}',
      'transcribe_called=${transcribeCalled ? 'yes' : 'no'}',
      'transcribe_http_result=${transcribeHttpResult ?? '—'}',
      'transcribe_error_kind=${transcribeErrorKind ?? '—'}',
      'transcribe_error_detail=${transcribeErrorDetail ?? '—'}',
      'transcribe_response_body_tail=${transcribeResponseBodyTail.isEmpty ? '—' : transcribeResponseBodyTail}',
      'pcm_chunks_count=$pcmChunksCount',
      'rms_min=${rmsMin.toStringAsFixed(4)}',
      'rms_max=${rmsMax.toStringAsFixed(4)}',
      'peak_max=${peakMax.toStringAsFixed(4)}',
      'overlay_level_events_count=$overlayLevelEventsCount',
      'stt_error_kind=${transcribeErrorKind ?? '—'}',
      'stt_error_detail=${transcribeErrorDetail ?? '—'}',
      'transcript_text=${transcript ?? '—'}',
      'latest_wav_path=${latestWavPath ?? '—'}',
      'latest_wav_exists=${latestWavExists ? 'yes' : 'no'}',
      'latest_wav_bytes=$latestWavBytes',
      'latest_wav_duration_ms=$latestWavDurationMs',
      'latest_raw_wav_path=${latestRawWavPath ?? '—'}',
      'latest_raw_wav_exists=${latestRawWavExists ? 'yes' : 'no'}',
      'latest_raw_wav_sample_rate=$latestRawWavSampleRate',
      'latest_raw_wav_channels=$latestRawWavChannels',
      'latest_raw_wav_format=${latestRawWavFormat.isEmpty ? '—' : latestRawWavFormat}',
      'latest_raw_wav_duration_ms=$latestRawWavDurationMs',
      'processed_wav_path=${processedWavPath ?? '—'}',
      'processed_wav_sample_rate=$processedWavSampleRate',
      'processed_wav_channels=$processedWavChannels',
      'pending_wav_after_stop=${pendingWavAfterStop ? 'yes' : 'no'}',
      'helper_ready_after_recording=${helperReadyAfterRecording ? 'yes' : 'no'}',
      'delayed_transcribe_called=${delayedTranscribeCalled ? 'yes' : 'no'}',
      'delayed_transcribe_result=${delayedTranscribeResult ?? '—'}',
      'failure_reason=${failureReason ?? '—'}',
      'overlay_renderer_active=${overlayRendererActive ?? '—'}',
      'engine=${engine ?? '—'}',
      'language_hint=$languageHint',
      'audio_device=$audioDevice',
      'sample_rate=$sampleRate',
      'channels=$channels',
      'audio_bytes=$audioBytes',
      'audio_duration_ms=$audioDurationMs',
      'max_amplitude=${maxAmplitude.toStringAsFixed(3)}',
      'rms_amplitude=${rmsAmplitude.toStringAsFixed(3)}',
      'audio_level_seen=${audioLevelSeen ? 'yes' : 'no'}',
      'audio_file=${audioFile ?? '—'}',
      'transcript=${transcript ?? '—'}',
      if (latencyMs != null) 'latency_ms=$latencyMs',
      if (error != null && error!.isNotEmpty) 'error=$error',
    ];
  }
}
