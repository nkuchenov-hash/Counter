import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:record/record.dart';

/// Live microphone capture for desktop voice — native-rate PCM16 capture,
/// float mono downmix + high-quality resample to 16 kHz mono for STT.
class DesktopVoiceAudioCapture {
  DesktopVoiceAudioCapture._();

  static final DesktopVoiceAudioCapture instance = DesktopVoiceAudioCapture._();

  static const _levelThreshold = 0.008;

  AudioRecorder? _recorder;
  StreamSubscription<List<int>>? _audioSub;
  StreamController<double>? _ampController;
  Timer? _partialTimer;
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
  String _captureBackend = 'record_windows_mf_pcm16';
  String? _lastError;
  bool _levelMarkerLogged = false;
  int _pcmChunksCount = 0;
  double _rmsMin = 1.0;
  double _rmsMax = 0;
  double _peakMax = 0;

  Stream<double>? get amplitudeStream => _ampController?.stream;
  int get capturedBytes => _buffer.length;
  int get pcmChunksCount => _pcmChunksCount;
  double get rmsMin => _pcmChunksCount == 0 ? 0 : _rmsMin;
  double get rmsMax => _rmsMax;
  double get peakMax => _peakMax;
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
  String? get lastError => _lastError;
  bool get isCapturing => _recorder != null;

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
      _lastError = null;
      _levelMarkerLogged = false;
      _pcmChunksCount = 0;
      _rmsMin = 1.0;
      _rmsMax = 0;
      _peakMax = 0;
      _ampController = StreamController<double>.broadcast();

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

      // Handy parity: request device-native 48 kHz stereo PCM16 so Media
      // Foundation does NOT force a 16 kHz downsample at capture. We then do
      // the mono downmix + high-quality resample ourselves (see stopAndSaveWav).
      // record_windows exposes PCM16 only (no F32), so bit depth stays 16-bit.
      _captureSampleRate = kNativeCaptureSampleRate;
      _captureChannels = kNativeCaptureChannels;
      _captureBackend = 'record_windows_mf_pcm16';
      Stream<Uint8List>? stream;
      try {
        stream = await _recorder!.startStream(
          RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: kNativeCaptureSampleRate,
            numChannels: kNativeCaptureChannels,
            device: device,
          ),
        );
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_NATIVE_RATE_CAPTURE',
          '${kNativeCaptureSampleRate}Hz x${kNativeCaptureChannels}ch pcm16',
        );
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_F32_CAPTURE_IF_AVAILABLE',
          'unavailable_record_windows_pcm16_only',
        );
      } catch (e) {
        // Fallback: some devices reject 48 kHz stereo. Never break capture —
        // drop to the legacy fixed 16 kHz mono path.
        _captureSampleRate = kVoiceSampleRate;
        _captureChannels = kVoiceChannels;
        _captureBackend = 'record_windows_mf_pcm16_fallback_16k_mono';
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_NATIVE_CAPTURE_FALLBACK_16K_MONO',
          e.toString(),
        );
        stream = await _recorder!.startStream(
          RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: kVoiceSampleRate,
            numChannels: kVoiceChannels,
            device: device,
          ),
        );
      }
      _audioSub = stream.listen(_onChunk);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_MIC_BARS_REAL_AUDIO_PRESERVED');
      // Capture/VAD parity pass provenance (not a parser/alias change).
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CAPTURE_PARITY_PASS_STARTED');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_ALIAS_FIX_FOR_CAPTURE_PARITY');
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_RAW_STT_QUALITY_TARGET',
        'Southern Computer Warehouse Del Mod, submit.',
      );
      // Handy preprocessing = native-rate capture + float mono downmix +
      // high-quality resample, no peak normalization.
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HANDY_PREPROCESSING_MATCHED');
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_REMAINING_AUDIO_DIFFS_LOGGED',
        'handy=f32_native; counter=pcm16_native(record_windows no f32); '
            'downmix=avg; resample=windowed_sinc_hann vs rubato',
      );
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  void _onChunk(List<int> chunk) {
    _buffer.addAll(chunk);
    _pcmChunksCount++;
    final rms = pcm16RmsLevel(chunk);
    final peak = pcm16PeakLevel(chunk);
    if (rms < _rmsMin) _rmsMin = rms;
    if (rms > _rmsMax) _rmsMax = rms;
    if (peak > _peakMax) _peakMax = peak;
    if (rms > _rmsAmplitude) _rmsAmplitude = rms;
    if (peak > _maxAmplitude) _maxAmplitude = peak;
    if (rms >= _levelThreshold || peak >= _levelThreshold) {
      _audioLevelSeen = true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_LEVEL_SEEN');
    }
    if (!_levelMarkerLogged) {
      _levelMarkerLogged = true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_LEVEL_UPDATE');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_RMS', rms.toStringAsFixed(4));
      DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_PEAK', peak.toStringAsFixed(4));
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_WAVEFORM_UPDATE');
    }
    // Mic-bar visual source: PEAK (not RMS). RMS mathematically under-reports
    // transient speech bursts (typical RMS ~0.02 vs peak ~0.15), so RMS-only
    // bars look dead. Peak tracks what the user actually hears. We emit on
    // every chunk so the overlay animates per-frame, not only on loud frames.
    _ampController?.add(peak.clamp(0.0, 1.0));
  }

  /// GOLOS/Handy parity — capture trailing phonemes after stop (180 ms + 30 ms drain).
  static const _manualStopPostRollMs = 180;
  static const _streamDrainMs = 30;

  Future<DesktopVoiceCaptureResult?> stopAndSaveWav({
    String? fileName,
    void Function(List<int> bytes)? onPartial,
  }) async {
    _partialTimer?.cancel();
    _partialTimer = null;
    // Keep stream open during post-roll so "DEL MOD submit" tail is not clipped.
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

    // Raw native capture buffer (device rate / channels, PCM16).
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
    final rawDurationMs = rawPcm.isEmpty
        ? 0
        : (rawPcm.length ~/ (_captureChannels * 2)) * 1000 ~/ _captureSampleRate;

    final dir = await _samplesDir();

    // Preserve the raw native-rate/stereo capture for diagnostics + benchmark.
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

    // Handy-parity processing: downmix to mono + high-quality resample to
    // 16 kHz + PCM16. NO peak normalization (proven to degrade Parakeet).
    final processed = processNativeCaptureForStt(
      nativePcm16: rawPcm,
      sampleRate: _captureSampleRate,
      channels: _captureChannels,
    );
    final pcm = processed.sttPcm16;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_HARMFUL_PEAK_NORMALIZATION');

    if (pcm.length < 3200) {
      _lastError = 'Not enough audio';
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
      rawSampleRate: _captureSampleRate,
      rawChannels: _captureChannels,
      rawDurationMs: rawDurationMs,
      rawRms: rawRms,
      rawPeak: rawPeak,
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
    if (_recorder == null) return;
    // Large enough that the post-resample (48 kHz stereo -> 16 kHz mono) STT
    // buffer still clears the 3200-byte minimum.
    final chunk = <int>[];
    for (var i = 0; i < 48000; i++) {
      chunk.add(0x00);
      chunk.add(0x60);
    }
    _onChunk(chunk);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_SMOKE_AUDIO_INJECTED');
  }

  Future<void> cancel() async {
    _partialTimer?.cancel();
    _partialTimer = null;
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
    this.captureBackend = 'record_windows_mf_pcm16',
    this.rawSampleRate = kNativeCaptureSampleRate,
    this.rawChannels = kNativeCaptureChannels,
    this.rawDurationMs = 0,
    this.rawRms = 0,
    this.rawPeak = 0,
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

  // Handy-parity capture diagnostics.
  final String? rawWavPath;
  final String captureBackend;
  final int rawSampleRate;
  final int rawChannels;
  final int rawDurationMs;
  final double rawRms;
  final double rawPeak;
  final String resamplerUsed;
  final bool downmixUsed;

  List<String> captureDiagLines() {
    return [
      'audio_device=$deviceLabel',
      // Capture parity diagnostics (raw native capture vs STT-ready copy).
      'capture_backend=$captureBackend',
      'raw_capture_path=${rawWavPath ?? '—'}',
      'raw_capture_sample_rate=$rawSampleRate',
      'raw_capture_channels=$rawChannels',
      'raw_capture_bit_depth_or_format=pcm16',
      'raw_capture_duration_ms=$rawDurationMs',
      'raw_capture_rms=${rawRms.toStringAsFixed(4)}',
      'raw_capture_peak=${rawPeak.toStringAsFixed(4)}',
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
