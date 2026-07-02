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
    this.transcribeHttpResult,
    this.transcribeErrorKind,
    this.transcribeErrorDetail,
    this.latestWavPath,
    this.latestWavExists = false,
    this.latestWavBytes = 0,
    this.latestWavDurationMs = 0,
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
  final String? transcribeHttpResult;
  final String? transcribeErrorKind;
  final String? transcribeErrorDetail;
  final String? latestWavPath;
  final bool latestWavExists;
  final int latestWavBytes;
  final int latestWavDurationMs;
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
      'transcribe_endpoint=${transcribeEndpoint ?? '—'}',
      'transcribe_http_result=${transcribeHttpResult ?? '—'}',
      'transcribe_error_kind=${transcribeErrorKind ?? '—'}',
      'transcribe_error_detail=${transcribeErrorDetail ?? '—'}',
      'latest_wav_path=${latestWavPath ?? '—'}',
      'latest_wav_exists=${latestWavExists ? 'yes' : 'no'}',
      'latest_wav_bytes=$latestWavBytes',
      'latest_wav_duration_ms=$latestWavDurationMs',
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
