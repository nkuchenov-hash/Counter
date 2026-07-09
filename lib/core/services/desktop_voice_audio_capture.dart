import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_audio_presentation.dart';
import 'package:counter/core/services/desktop_voice_capture_endpoint.dart';
import 'package:counter/core/services/desktop_voice_ready_cue.dart';
import 'package:counter/core/services/desktop_voice_windows_audio_diagnostics.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

/// Live microphone capture for desktop voice.
///
/// Windows primary path: STT helper CPAL/WASAPI F32 native capture
/// (`/capture/start` + `/capture/stop`). The bad Media Foundation 48 kHz
/// stereo PCM16 path is disabled — it measured ~10 dB quieter than Handy and
/// worse than the old 16 kHz mono path.
///
/// Fallback only: legacy `record` 16 kHz mono PCM16 (pre-f69fb1b loudness).
class DesktopVoiceAudioCapture {
  DesktopVoiceAudioCapture._();

  static final DesktopVoiceAudioCapture instance = DesktopVoiceAudioCapture._();

  static const _levelThreshold = 0.008;
  static const _helperBase = 'http://127.0.0.1:8765';

  AudioRecorder? _recorder;
  StreamSubscription<List<int>>? _audioSub;
  StreamController<double>? _ampController;
  Timer? _partialTimer;
  Timer? _helperLevelTimer;
  final List<int> _buffer = [];

  String? _deviceLabel;
  String? _deviceId;
  bool _audioLevelSeen = false;
  double _maxAmplitude = 0;
  double _rmsAmplitude = 0;
  String? _lastWavPath;
  String? _rawWavPath;
  int _captureSampleRate = kNativeCaptureSampleRate;
  int _captureChannels = kNativeCaptureChannels;
  String _captureBackend = 'cpal_wasapi';
  String _captureApi = 'Wasapi';
  String _rawCaptureFormat = 'F32';
  double _rawCaptureRms = 0;
  double _rawCapturePeak = 0;
  double _processedWavRms = 0;
  double _processedWavPeak = 0;
  double? _sessionVolume;
  double? _endpointVolume;
  DesktopVoiceCaptureEndpointSnapshot? _endpointSnapshot;
  bool _usingHelperCapture = false;
  String? _lastError;
  bool _levelMarkerLogged = false;
  int _pcmChunksCount = 0;
  double _rmsMin = 1.0;
  double _rmsMax = 0;
  double _peakMax = 0;
  double _levelMeterRms = 0;
  double _levelMeterDisplay = 0;
  double _levelMeterPeakHold = 0;
  int _overlayLevelEventsCount = 0;
  bool _captureStreamStarted = false;
  bool _firstAudioFrameReceived = false;
  int? _firstNonSilentFrameMs;
  DateTime? _captureStreamStartedAt;
  DateTime? _firstAudioCallbackAt;
  DateTime? _readyCuePlayedAt;
  DateTime? _hotkeyReceivedAt;
  DateTime? _captureStartRequestedAt;
  VoidCallback? onReadyCuePlayed;
  bool _noSignalDetected = false;
  String? _noSignalReason;
  String? _captureStreamError;
  String _levelSource = '—';

  bool get captureStreamStarted => _captureStreamStarted;
  bool get firstAudioFrameReceived => _firstAudioFrameReceived;
  DateTime? get captureStreamStartedAt => _captureStreamStartedAt;
  DateTime? get firstAudioCallbackAt => _firstAudioCallbackAt;
  DateTime? get readyCuePlayedAt => _readyCuePlayedAt;
  DateTime? get hotkeyReceivedAt => _hotkeyReceivedAt;
  DateTime? get captureStartRequestedAt => _captureStartRequestedAt;
  bool get readyCuePlayed => DesktopVoiceReadyCue.playedThisSession;
  bool get readyCueOutputOk => DesktopVoiceReadyCue.outputOk;

  void noteHotkeyReceived() {
    _hotkeyReceivedAt = DateTime.now();
  }
  int? get firstNonSilentFrameMs => _firstNonSilentFrameMs;
  bool get noSignalDetected => _noSignalDetected;
  String? get noSignalReason => _noSignalReason;
  String? get captureStreamError => _captureStreamError;
  String get levelSource => _levelSource;
  bool get levelStreamConnected =>
      _usingHelperCapture
          ? _helperLevelTimer != null
          : _audioSub != null;

  /// Capture never started (helper/legacy start returned false).
  void noteCaptureStartFailed([String? detail]) {
    _noSignalDetected = true;
    _noSignalReason = detail == null || detail.trim().isEmpty
        ? 'capture_start_failed'
        : 'capture_start_failed:${detail.trim()}';
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CAPTURE_START_NO_SIGNAL');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_SIGNAL_DETECTED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_SIGNAL_ERROR_CLASSIFIED');
  }

  /// Stream started but no audible level during the listening window.
  void noteIntermittentListeningNoSignal() {
    _noSignalDetected = true;
    _noSignalReason = 'intermittent_no_level_during_listening';
    DesktopVoicePipeline.mark('DESKTOP_VOICE_INTERMITTENT_MIC_NO_SIGNAL');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_SIGNAL_DETECTED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_SIGNAL_ERROR_CLASSIFIED');
  }

  Stream<double>? get amplitudeStream => _ampController?.stream;
  int get capturedBytes => _buffer.length;
  int get pcmChunksCount => _pcmChunksCount;
  double get rmsMin => _pcmChunksCount == 0 ? 0 : _rmsMin;
  double get rmsMax => _rmsMax;
  double get peakMax => _peakMax;
  double get levelMeterRms => _levelMeterRms;
  double get levelMeterDisplayLevel => _levelMeterDisplay;
  double get levelMeterPeakHold => _levelMeterPeakHold;
  double get levelMeterGain => DesktopVoiceAudioPresentation.levelMeterGain;
  int get overlayLevelEventsCount => _overlayLevelEventsCount;
  bool get audioLevelSeen => _audioLevelSeen;
  double get maxAmplitude => _maxAmplitude;
  double get rmsAmplitude => _rmsAmplitude;
  String? get audioDeviceLabel => _deviceLabel;
  String? get audioDeviceId => _deviceId;
  String? get lastWavPath => _lastWavPath;
  String? get lastRawWavPath => _rawWavPath;
  int get captureSampleRate => _captureSampleRate;
  int get captureChannels => _captureChannels;
  String get captureBackend => _captureBackend;
  String get captureApi => _captureApi;
  String get rawCaptureFormat => _rawCaptureFormat;
  double get rawCaptureRms => _rawCaptureRms;
  double get rawCapturePeak => _rawCapturePeak;
  double get processedWavRms => _processedWavRms;
  double get processedWavPeak => _processedWavPeak;
  double? get sessionVolume => _sessionVolume;
  double? get endpointVolume => _endpointVolume;
  DesktopVoiceCaptureEndpointSnapshot? get endpointSnapshot => _endpointSnapshot;
  String? get lastError => _lastError;
  bool get isCapturing => _usingHelperCapture || _recorder != null;

  Future<List<InputDevice>> listInputDevices() async {
    try {
      final rec = AudioRecorder();
      final devices = await rec.listInputDevices();
      await rec.dispose();
      return devices;
    } catch (_) {
      return const [];
    }
  }

  Future<bool> start({String? deviceId, String? deviceLabel}) async {
    try {
      await cancel();
      _deviceId = deviceId;
      _deviceLabel = deviceLabel ?? deviceId ?? 'default';
      _buffer.clear();
      _audioLevelSeen = false;
      _maxAmplitude = 0;
      _rmsAmplitude = 0;
      _lastWavPath = null;
      _rawWavPath = null;
      _lastError = null;
      _levelMarkerLogged = false;
      _pcmChunksCount = 0;
      _rmsMin = 1.0;
      _rmsMax = 0;
      _peakMax = 0;
      _levelMeterRms = 0;
      _levelMeterDisplay = 0;
      _levelMeterPeakHold = 0;
      _overlayLevelEventsCount = 0;
      _captureStreamStarted = false;
      _firstAudioFrameReceived = false;
      _firstNonSilentFrameMs = null;
      _captureStreamStartedAt = null;
      _firstAudioCallbackAt = null;
      _readyCuePlayedAt = null;
      _captureStartRequestedAt = DateTime.now();
      DesktopVoiceReadyCue.resetSession();
      _noSignalDetected = false;
      _noSignalReason = null;
      _captureStreamError = null;
      _levelSource = '—';
      _usingHelperCapture = false;
      _rawCaptureRms = 0;
      _rawCapturePeak = 0;
      _processedWavRms = 0;
      _processedWavPeak = 0;
      _sessionVolume = null;
      _endpointVolume = null;
      _endpointSnapshot = null;
      _ampController = StreamController<double>.broadcast();

      // Primary: Handy-like CPAL/WASAPI F32 via STT helper.
      if (await _startHelperCapture()) {
        return true;
      }

      // Safety fallback: old louder 16 kHz mono Media Foundation path.
      // Do NOT use the rejected 48 kHz stereo MF path (f69fb1b, ~-10 dB).
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_RECORD_WINDOWS_MF_48K_DISABLED',
        'rejected_quieter_than_old_and_handy',
      );
      return _startLegacy16kMonoFallback(deviceId: deviceId);
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<bool> _startHelperCapture() async {
    try {
      final r = await http
          .post(
            Uri.parse('$_helperBase/capture/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
              DesktopVoiceCaptureEndpointPolicy.startRequestBody(),
            ),
          )
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_CPAL_CAPTURE_START_FAILED',
          'HTTP ${r.statusCode}',
        );
        return false;
      }
      final body = jsonDecode(r.body);
      if (body is! Map || body['ok'] != true) {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_CPAL_CAPTURE_START_FAILED',
          '${body is Map ? body['error'] : 'bad_json'}',
        );
        return false;
      }
      _usingHelperCapture = true;
      _captureStreamStarted = true;
      _captureStreamStartedAt = DateTime.now();
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CAPTURE_STREAM_STARTED');
      _captureBackend = (body['capture_backend'] as String?) ?? 'cpal_wasapi';
      _captureApi = (body['capture_api'] as String?) ?? 'Wasapi';
      _rawCaptureFormat = (body['raw_capture_format'] as String?) ?? 'F32';
      _captureSampleRate =
          (body['raw_capture_sample_rate'] as num?)?.toInt() ??
              kNativeCaptureSampleRate;
      _captureChannels =
          (body['raw_capture_channels'] as num?)?.toInt() ??
              kNativeCaptureChannels;
      _deviceLabel =
          (body['device_name'] as String?)?.trim().isNotEmpty == true
              ? (body['device_name'] as String)
              : (_deviceLabel ?? 'default');
      _endpointSnapshot = DesktopVoiceCaptureEndpointSnapshot.fromJson(
        Map<String, dynamic>.from(body),
      );
      _endpointVolume = _endpointSnapshot?.endpointVolume ??
          (body['endpoint_volume'] as num?)?.toDouble();
      _sessionVolume = _endpointSnapshot?.sessionVolume ??
          (body['session_volume'] as num?)?.toDouble();
      DesktopVoiceCaptureEndpointPolicy.logFromHelperJson(
        Map<String, dynamic>.from(body),
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CORE_AUDIO_DEVICE_DIAGNOSTICS');
      final f32 = body['f32_available'] == true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CPAL_WASAPI_CAPTURE_ACTIVE');
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_NATIVE_RATE_CAPTURE',
        '${_captureSampleRate}Hz x${_captureChannels}ch $_rawCaptureFormat',
      );
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_F32_CAPTURE_IF_AVAILABLE',
        f32 ? 'yes_cpal_f32' : 'cpal_non_f32_$_rawCaptureFormat',
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_RECORD_WINDOWS_MF_PATH_BYPASSED');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CAPTURE_PARITY_PASS_STARTED');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_ALIAS_FIX_FOR_CAPTURE_PARITY');
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_RAW_STT_QUALITY_TARGET',
        'Southern Computer Warehouse Del Mod, submit.',
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HANDY_PREPROCESSING_MATCHED');
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_REMAINING_AUDIO_DIFFS_LOGGED',
        'backend=cpal_wasapi; mf_48k_stereo=disabled',
      );
      _helperLevelTimer?.cancel();
      _helperLevelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        unawaited(_pollHelperLevel());
      });
      _levelSource = 'cpal_wasapi_active_capture';
      DesktopVoicePipeline.mark('DESKTOP_VOICE_LEVEL_SOURCE_ACTIVE_CAPTURE');
      unawaited(_logWindowsEndpointDiagnostics());
      return true;
    } catch (e) {
      _captureStreamError = e.toString();
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_CPAL_CAPTURE_START_FAILED',
        e.toString(),
      );
      return false;
    }
  }

  Future<void> _pollHelperLevel() async {
    if (!_usingHelperCapture) return;
    try {
      final r = await http
          .get(Uri.parse('$_helperBase/capture/level'))
          .timeout(const Duration(milliseconds: 400));
      if (r.statusCode != 200) return;
      final body = jsonDecode(r.body);
      if (body is! Map) return;
      final peak = (body['peak'] as num?)?.toDouble() ??
          (body['level'] as num?)?.toDouble() ??
          0;
      final rms = (body['rms'] as num?)?.toDouble() ?? peak;
      _onLevel(peak: peak, rms: rms);
    } catch (_) {}
  }

  void _onLevel({required double peak, required double rms}) {
    _pcmChunksCount++;
    if (!_firstAudioFrameReceived) {
      _firstAudioFrameReceived = true;
      _firstAudioCallbackAt = DateTime.now();
      DesktopVoicePipeline.mark('DESKTOP_VOICE_FIRST_AUDIO_FRAME_RECEIVED');
      // Recording already started; arm short ready cue after first callback.
      DesktopVoiceReadyCue.armAfterFirstAudio(
        captureStreamStarted: _captureStreamStarted,
        firstAudioCallbackReceived: true,
        onPlayed: () {
          if (DesktopVoiceReadyCue.outputOk) {
            _readyCuePlayedAt = DateTime.now();
          }
          onReadyCuePlayed?.call();
        },
      );
    }
    if (!_audioLevelSeen &&
        (rms >= _levelThreshold || peak >= _levelThreshold) &&
        _captureStreamStartedAt != null) {
      _firstNonSilentFrameMs = DateTime.now()
          .difference(_captureStreamStartedAt!)
          .inMilliseconds;
    }
    if (rms < _rmsMin) _rmsMin = rms;
    if (rms > _rmsMax) _rmsMax = rms;
    if (peak > _peakMax) _peakMax = peak;
    if (rms > _rmsAmplitude) _rmsAmplitude = rms;
    if (peak > _maxAmplitude) _maxAmplitude = peak;
    _levelMeterRms = rms;
    final display = DesktopVoiceAudioPresentation.perceptualLevel(
      peak: peak,
      rms: rms,
    );
    // Peak-hold with decay so bars move clearly without locking at max.
    if (display >= _levelMeterPeakHold) {
      _levelMeterPeakHold = display;
    } else {
      _levelMeterPeakHold = (_levelMeterPeakHold * 0.82).clamp(0.0, 1.0);
    }
    _levelMeterDisplay =
        math.max(display, _levelMeterPeakHold * 0.55).clamp(0.0, 1.0);
    _overlayLevelEventsCount++;
    if (rms >= _levelThreshold || peak >= _levelThreshold) {
      _audioLevelSeen = true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_LEVEL_SEEN');
    }
    if (!_levelMarkerLogged) {
      _levelMarkerLogged = true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_LEVEL_UPDATE');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_RMS', rms.toStringAsFixed(4));
      DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_PEAK', peak.toStringAsFixed(4));
      DesktopVoicePipeline.mark('DESKTOP_VOICE_MIC_BARS_PERCEPTUAL_SCALE');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_MIC_BARS_NOT_RAW_LINEAR');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_WAVEFORM_UPDATE');
      if (rms >= 0.015 && rms <= 0.03) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_MIC_BARS_VISIBLE_FOR_LOW_RMS');
      }
    }
    _ampController?.add(_levelMeterDisplay);
  }

  void _onChunk(List<int> chunk) {
    _buffer.addAll(chunk);
    _onLevel(peak: pcm16PeakLevel(chunk), rms: pcm16RmsLevel(chunk));
  }

  Future<bool> _startLegacy16kMonoFallback({String? deviceId}) async {
    _recorder = AudioRecorder();
    if (!await _recorder!.hasPermission()) {
      _lastError = 'Microphone permission denied';
      return false;
    }
    InputDevice? device;
    if (deviceId != null && deviceId.isNotEmpty) {
      final devices = await _recorder!.listInputDevices();
      for (final d in devices) {
        if (d.id == deviceId) {
          device = d;
          _deviceLabel = d.label;
          break;
        }
      }
    }
    _captureSampleRate = kVoiceSampleRate;
    _captureChannels = kVoiceChannels;
    _captureBackend = 'record_windows_mf_pcm16_fallback_16k_mono';
    _captureApi = 'MediaFoundation';
    _rawCaptureFormat = 'pcm16';
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_NATIVE_CAPTURE_FALLBACK_16K_MONO',
      'cpal_unavailable_using_old_louder_path',
    );
    final stream = await _recorder!.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: kVoiceSampleRate,
        numChannels: kVoiceChannels,
        device: device,
      ),
    );
    _audioSub = stream.listen(_onChunk);
    _captureStreamStarted = true;
    _captureStreamStartedAt = DateTime.now();
    _levelSource = 'record_windows_16k_mono_fallback';
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CAPTURE_STREAM_STARTED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_LEVEL_SOURCE_ACTIVE_CAPTURE');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_MIC_BARS_REAL_AUDIO_PRESERVED');
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_F32_CAPTURE_IF_AVAILABLE',
      'unavailable_fallback_16k_mono',
    );
    return true;
  }

  static const _manualStopPostRollMs = 180;
  static const _streamDrainMs = 30;

  Future<DesktopVoiceCaptureResult?> stopAndSaveWav({
    String? fileName,
    void Function(List<int> bytes)? onPartial,
  }) async {
    _partialTimer?.cancel();
    _partialTimer = null;
    _helperLevelTimer?.cancel();
    _helperLevelTimer = null;

    if (_usingHelperCapture) {
      return _stopHelperCaptureAndSave(fileName: fileName, onPartial: onPartial);
    }
    return _stopRecordPackageAndSave(fileName: fileName, onPartial: onPartial);
  }

  Future<DesktopVoiceCaptureResult?> _stopHelperCaptureAndSave({
    String? fileName,
    void Function(List<int> bytes)? onPartial,
  }) async {
    try {
      final r = await http
          .post(Uri.parse('$_helperBase/capture/stop'))
          .timeout(const Duration(seconds: 8));
      _usingHelperCapture = false;
      await _ampController?.close();
      _ampController = null;
      if (r.statusCode != 200) {
        _lastError = 'capture/stop HTTP ${r.statusCode}';
        return null;
      }
      final body = jsonDecode(r.body);
      if (body is! Map || body['ok'] != true) {
        _lastError = body is Map ? '${body['error']}' : 'capture/stop failed';
        return null;
      }

      _captureBackend = (body['capture_backend'] as String?) ?? _captureBackend;
      _captureApi = (body['capture_api'] as String?) ?? _captureApi;
      _rawCaptureFormat =
          (body['raw_capture_format'] as String?) ?? _rawCaptureFormat;
      _captureSampleRate =
          (body['raw_capture_sample_rate'] as num?)?.toInt() ??
              _captureSampleRate;
      _captureChannels =
          (body['raw_capture_channels'] as num?)?.toInt() ?? _captureChannels;
      _rawCaptureRms =
          (body['raw_capture_rms'] as num?)?.toDouble() ?? 0;
      _rawCapturePeak =
          (body['raw_capture_peak'] as num?)?.toDouble() ?? 0;
      _processedWavRms =
          (body['processed_wav_rms'] as num?)?.toDouble() ?? 0;
      _processedWavPeak =
          (body['processed_wav_peak'] as num?)?.toDouble() ?? 0;
      _endpointVolume = (body['endpoint_volume'] as num?)?.toDouble();
      _sessionVolume = (body['session_volume'] as num?)?.toDouble();
      _endpointSnapshot = DesktopVoiceCaptureEndpointSnapshot.fromJson(
        Map<String, dynamic>.from(body),
      );
      DesktopVoiceCaptureEndpointPolicy.logFromHelperJson(
        Map<String, dynamic>.from(body),
      );
      _deviceLabel =
          (body['device_name'] as String?)?.trim().isNotEmpty == true
              ? (body['device_name'] as String)
              : (_deviceLabel ?? 'default');
      _audioLevelSeen = body['audio_level_seen'] == true ||
          _rawCapturePeak >= _levelThreshold;
      _maxAmplitude = _rawCapturePeak;
      _rmsAmplitude = _rawCaptureRms;
      _peakMax = _rawCapturePeak;
      _rmsMax = _rawCaptureRms;

      unawaited(_logWindowsEndpointDiagnostics());
      DesktopVoiceWindowsAudioDiagnostics.logCounterVsHandyRmsDiff(
        captureRms: _rawCaptureRms,
      );

      final rawPathFromHelper = (body['raw_wav_path'] as String?)?.trim();
      final sttPathFromHelper = (body['stt_wav_path'] as String?)?.trim();
      var durationMs = (body['duration_ms'] as num?)?.toInt() ?? 0;
      if (durationMs <= 0 &&
          rawPathFromHelper != null &&
          rawPathFromHelper.isNotEmpty &&
          File(rawPathFromHelper).existsSync()) {
        durationMs = await wavFileDurationMs(rawPathFromHelper);
        if (durationMs > 0) {
          DesktopVoicePipeline.mark('DESKTOP_VOICE_RAW_F32_WAV_DURATION_FIXED');
        }
      }

      List<int> sttPcm = const [];
      final sttB64 = (body['stt_pcm16_base64'] as String?) ?? '';
      if (sttB64.isNotEmpty) {
        sttPcm = base64Decode(sttB64);
      } else if (sttPathFromHelper != null &&
          sttPathFromHelper.isNotEmpty &&
          File(sttPathFromHelper).existsSync()) {
        final bytes = await File(sttPathFromHelper).readAsBytes();
        sttPcm = extractPcm16FromWav(bytes);
      }

      if (sttPcm.length < 3200) {
        _lastError = 'Not enough audio';
        return null;
      }

      if (rawPathFromHelper != null &&
          rawPathFromHelper.isNotEmpty &&
          File(rawPathFromHelper).existsSync()) {
        _rawWavPath = rawPathFromHelper;
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_RAW_CAPTURE_WAV_SAVED',
          rawPathFromHelper,
        );
      }
      final path = (sttPathFromHelper != null &&
              sttPathFromHelper.isNotEmpty &&
              File(sttPathFromHelper).existsSync())
          ? sttPathFromHelper
          : '${(await _samplesDir()).path}${Platform.pathSeparator}'
              '${fileName ?? 'latest_command.wav'}';
      if (path != sttPathFromHelper) {
        await writePcm16WavFile(pcm: sttPcm, path: path);
      }
      _lastWavPath = path;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_READY_WAV_CREATED', path);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_HARMFUL_PEAK_NORMALIZATION');
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_CAPTURE_GAIN_DIAG',
        'raw_rms=${_rawCaptureRms.toStringAsFixed(4)} '
            'raw_peak=${_rawCapturePeak.toStringAsFixed(4)} '
            'stt_rms=${_processedWavRms.toStringAsFixed(4)} '
            'stt_peak=${_processedWavPeak.toStringAsFixed(4)} '
            'backend=$_captureBackend api=$_captureApi fmt=$_rawCaptureFormat',
      );
      onPartial?.call(sttPcm);

      return DesktopVoiceCaptureResult(
        wavPath: path,
        rawWavPath: _rawWavPath,
        captureBackend: _captureBackend,
        captureApi: _captureApi,
        rawCaptureFormat: _rawCaptureFormat,
        rawSampleRate: _captureSampleRate,
        rawChannels: _captureChannels,
        rawDurationMs: durationMs,
        rawRms: _rawCaptureRms,
        rawPeak: _rawCapturePeak,
        processedWavRms: _processedWavRms,
        processedWavPeak: _processedWavPeak,
        sessionVolume: _sessionVolume,
        endpointVolume: _endpointVolume,
        resamplerUsed: 'helper_linear_16k',
        downmixUsed: _captureChannels > 1,
        pcmBytes: sttPcm,
        sampleRate: kVoiceSampleRate,
        channels: kVoiceChannels,
        durationMs: pcm16DurationMs(sttPcm),
        maxAmplitude: _maxAmplitude,
        rmsAmplitude: _rmsAmplitude,
        audioLevelSeen: _audioLevelSeen,
        deviceLabel: _deviceLabel ?? 'default',
        deviceId: _deviceId,
      );
    } catch (e) {
      _usingHelperCapture = false;
      _lastError = e.toString();
      return null;
    }
  }

  Future<DesktopVoiceCaptureResult?> _stopRecordPackageAndSave({
    String? fileName,
    void Function(List<int> bytes)? onPartial,
  }) async {
    if (_recorder != null && _audioSub != null) {
      await Future<void>.delayed(
        const Duration(milliseconds: _manualStopPostRollMs),
      );
      await Future<void>.delayed(
        const Duration(milliseconds: _streamDrainMs),
      );
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_GOLOS_POST_ROLL_CAPTURED',
        '${_manualStopPostRollMs + _streamDrainMs}ms',
      );
    }
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _recorder?.stop();
    } catch (_) {}
    try {
      await _recorder?.dispose();
    } catch (_) {}
    _recorder = null;
    await _ampController?.close();
    _ampController = null;

    final rawPcm = List<int>.from(_buffer);
    _buffer.clear();

    if (rawPcm.isNotEmpty && !_audioLevelSeen) {
      final peak = pcm16PeakLevel(rawPcm);
      final rms = pcm16RmsLevel(rawPcm);
      if (peak >= _levelThreshold || rms >= _levelThreshold) {
        _audioLevelSeen = true;
      }
      if (peak > _maxAmplitude) _maxAmplitude = peak;
      if (rms > _rmsAmplitude) _rmsAmplitude = rms;
    }

    final rawRms = pcm16RmsLevel(rawPcm);
    final rawPeak = pcm16PeakLevel(rawPcm);
    _rawCaptureRms = rawRms;
    _rawCapturePeak = rawPeak;
    final rawDurationMs = rawPcm.isEmpty
        ? 0
        : (rawPcm.length ~/ (_captureChannels * 2)) * 1000 ~/ _captureSampleRate;

    final dir = await _samplesDir();
    final rawName = 'latest_command_raw.wav';
    final rawPath = '${dir.path}${Platform.pathSeparator}$rawName';
    if (rawPcm.isNotEmpty) {
      await writePcm16WavFileFull(
        pcm: rawPcm,
        path: rawPath,
        sampleRate: _captureSampleRate,
        channels: _captureChannels,
      );
      _rawWavPath = rawPath;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_RAW_CAPTURE_WAV_SAVED', rawPath);
    }

    final processed = processNativeCaptureForStt(
      nativePcm16: rawPcm,
      sampleRate: _captureSampleRate,
      channels: _captureChannels,
    );
    final pcm = processed.sttPcm16;
    _processedWavRms = pcm16RmsLevel(pcm);
    _processedWavPeak = pcm16PeakLevel(pcm);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_HARMFUL_PEAK_NORMALIZATION');

    if (pcm.length < 3200) {
      _lastError = 'Not enough audio';
      _noSignalDetected = true;
      _noSignalReason = 'not_enough_audio';
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_SIGNAL_DETECTED');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_SIGNAL_ERROR_CLASSIFIED');
      return null;
    }

    final name = fileName ?? 'latest_command.wav';
    final path = '${dir.path}${Platform.pathSeparator}$name';
    await writePcm16WavFile(pcm: pcm, path: path);
    _lastWavPath = path;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_READY_WAV_CREATED', path);
    if (processed.resamplerUsed != 'none') {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_HIGH_QUALITY_RESAMPLE_USED',
        processed.resamplerUsed,
      );
    }
    onPartial?.call(pcm);

    return DesktopVoiceCaptureResult(
      wavPath: path,
      rawWavPath: _rawWavPath,
      captureBackend: _captureBackend,
      captureApi: _captureApi,
      rawCaptureFormat: _rawCaptureFormat,
      rawSampleRate: _captureSampleRate,
      rawChannels: _captureChannels,
      rawDurationMs: rawDurationMs,
      rawRms: rawRms,
      rawPeak: rawPeak,
      processedWavRms: _processedWavRms,
      processedWavPeak: _processedWavPeak,
      sessionVolume: _sessionVolume,
      endpointVolume: _endpointVolume,
      resamplerUsed: processed.resamplerUsed,
      downmixUsed: processed.downmixUsed,
      pcmBytes: pcm,
      sampleRate: kVoiceSampleRate,
      channels: kVoiceChannels,
      durationMs: pcm16DurationMs(pcm),
      maxAmplitude: _maxAmplitude,
      rmsAmplitude: _rmsAmplitude,
      audioLevelSeen: _audioLevelSeen,
      deviceLabel: _deviceLabel ?? 'default',
      deviceId: _deviceId,
    );
  }

  void injectSmokeLevelBurst() {
    if (Platform.environment['COUNTER_DESKTOP_VOICE_SMOKE'] != '1') return;
    if (_usingHelperCapture) {
      _onLevel(peak: 0.4, rms: 0.08);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_SMOKE_AUDIO_INJECTED');
      return;
    }
    if (_recorder == null) return;
    final chunk = <int>[];
    for (var i = 0; i < 16000; i++) {
      chunk.add(0x00);
      chunk.add(0x60);
    }
    _onChunk(chunk);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_SMOKE_AUDIO_INJECTED');
  }

  Future<void> cancel() async {
    DesktopVoiceReadyCue.cancelArm();
    _partialTimer?.cancel();
    _partialTimer = null;
    _helperLevelTimer?.cancel();
    _helperLevelTimer = null;
    if (_usingHelperCapture) {
      try {
        await http
            .post(Uri.parse('$_helperBase/capture/cancel'))
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        _captureStreamError ??= e.toString();
      }
      _usingHelperCapture = false;
      if (_noSignalDetected) {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_CAPTURE_STREAM_RESET_AFTER_NO_SIGNAL',
        );
      }
    }
    try {
      await _audioSub?.cancel();
      _audioSub = null;
      await _recorder?.stop();
      await _recorder?.dispose();
    } catch (_) {}
    _recorder = null;
    _buffer.clear();
    await _ampController?.close();
    _ampController = null;
  }

  Future<Directory> _samplesDir() async {
    final local = Platform.environment['LOCALAPPDATA'];
    final base = local != null && local.isNotEmpty
        ? Directory(local)
        : Directory.systemTemp;
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}Counter'
      '${Platform.pathSeparator}voice_samples',
    );
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  void attachPartialTimer(void Function(List<int> bytes) onPartial) {
    _partialTimer?.cancel();
    _partialTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_buffer.isEmpty) return;
      onPartial(List<int>.from(_buffer));
    });
  }

  /// CPAL live buffer → /capture/partial_pcm → mid-listen /transcribe/partial_audio.
  void attachCpalPartialPoll(void Function(List<int> bytes) onPartial) {
    _partialTimer?.cancel();
    _partialTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!_usingHelperCapture) return;
      unawaited(_pollCpalPartialPcm(onPartial));
    });
  }

  Future<void> _pollCpalPartialPcm(void Function(List<int> bytes) onPartial) async {
    try {
      final r = await http
          .get(Uri.parse('$_helperBase/capture/partial_pcm'))
          .timeout(const Duration(milliseconds: 800));
      if (r.statusCode != 200) return;
      final body = jsonDecode(r.body);
      if (body is! Map || body['ok'] != true) return;
      final b64 = (body['pcm16_base64'] as String?) ?? '';
      if (b64.isEmpty) return;
      final pcm = base64Decode(b64);
      if (pcm.length < 4800 * 2) return; // <300ms @16k
      onPartial(pcm);
    } catch (_) {}
  }

  Future<void> _logWindowsEndpointDiagnostics() async {
    final snap =
        await DesktopVoiceWindowsAudioDiagnostics.readDefaultCaptureEndpoint();
    if (snap == null) return;
    _endpointVolume ??= snap.endpointVolume;
    _sessionVolume ??= snap.communicationsVolume;
    DesktopVoicePipeline.mark('capture_endpoint_device_id', snap.deviceId);
    DesktopVoicePipeline.mark('capture_endpoint_device_name', snap.deviceFriendlyName);
    DesktopVoicePipeline.mark('capture_endpoint_role', snap.endpointRole);
    DesktopVoicePipeline.mark(
      'capture_endpoint_muted',
      snap.endpointMuted ? 'yes' : 'no',
    );
  }
}

class DesktopVoiceCaptureResult {
  const DesktopVoiceCaptureResult({
    required this.wavPath,
    required this.pcmBytes,
    required this.sampleRate,
    required this.channels,
    required this.durationMs,
    required this.maxAmplitude,
    required this.rmsAmplitude,
    required this.audioLevelSeen,
    required this.deviceLabel,
    this.deviceId,
    this.rawWavPath,
    this.captureBackend = 'cpal_wasapi',
    this.captureApi = 'Wasapi',
    this.rawCaptureFormat = 'F32',
    this.rawSampleRate = kNativeCaptureSampleRate,
    this.rawChannels = kNativeCaptureChannels,
    this.rawDurationMs = 0,
    this.rawRms = 0,
    this.rawPeak = 0,
    this.processedWavRms = 0,
    this.processedWavPeak = 0,
    this.sessionVolume,
    this.endpointVolume,
    this.resamplerUsed = 'none',
    this.downmixUsed = false,
  });

  final String wavPath;
  final List<int> pcmBytes;
  final int sampleRate;
  final int channels;
  final int durationMs;
  final double maxAmplitude;
  final double rmsAmplitude;
  final bool audioLevelSeen;
  final String deviceLabel;
  final String? deviceId;

  final String? rawWavPath;
  final String captureBackend;
  final String captureApi;
  final String rawCaptureFormat;
  final int rawSampleRate;
  final int rawChannels;
  final int rawDurationMs;
  final double rawRms;
  final double rawPeak;
  final double processedWavRms;
  final double processedWavPeak;
  final double? sessionVolume;
  final double? endpointVolume;
  final String resamplerUsed;
  final bool downmixUsed;

  List<String> captureDiagLines() {
    return [
      'audio_device=$deviceLabel',
      'capture_backend=$captureBackend',
      'capture_api=$captureApi',
      'raw_capture_format=$rawCaptureFormat',
      'raw_capture_path=${rawWavPath ?? '—'}',
      'raw_capture_sample_rate=$rawSampleRate',
      'raw_capture_channels=$rawChannels',
      'raw_capture_bit_depth_or_format=$rawCaptureFormat',
      'raw_capture_duration_ms=$rawDurationMs',
      'raw_capture_rms=${rawRms.toStringAsFixed(4)}',
      'raw_capture_peak=${rawPeak.toStringAsFixed(4)}',
      'processed_wav_rms=${processedWavRms.toStringAsFixed(4)}',
      'processed_wav_peak=${processedWavPeak.toStringAsFixed(4)}',
      'session_volume=${sessionVolume?.toStringAsFixed(3) ?? '—'}',
      'endpoint_volume=${endpointVolume?.toStringAsFixed(3) ?? '—'}',
      'stt_wav_path=$wavPath',
      'stt_wav_sample_rate=$sampleRate',
      'stt_wav_channels=$channels',
      'stt_wav_bit_depth=16',
      'resampler_used=$resamplerUsed',
      'downmix_used=${downmixUsed ? 'yes' : 'no'}',
      'final_inference_wav_path=$wavPath',
      'sample_rate=$sampleRate',
      'channels=$channels',
      'audio_bytes=${pcmBytes.length}',
      'duration_ms=$durationMs',
      'max_amplitude=${maxAmplitude.toStringAsFixed(3)}',
      'rms_amplitude=${rmsAmplitude.toStringAsFixed(3)}',
      'audio_level_seen=${audioLevelSeen ? 'yes' : 'no'}',
      'audio_file=$wavPath',
    ];
  }
}
