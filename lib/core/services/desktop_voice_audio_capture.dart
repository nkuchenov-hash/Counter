import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:counter/core/services/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_voice_engine.dart';
import 'package:counter/core/services/desktop_win_speech_service.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

/// Live microphone capture for desktop voice — PCM16 16 kHz mono + WAV save.
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
  String? _lastError;

  Stream<double>? get amplitudeStream => _ampController?.stream;
  int get capturedBytes => _buffer.length;
  bool get audioLevelSeen => _audioLevelSeen;
  double get maxAmplitude => _maxAmplitude;
  double get rmsAmplitude => _rmsAmplitude;
  String? get audioDeviceLabel => _deviceLabel;
  String? get audioDeviceId => _deviceId;
  String? get lastWavPath => _lastWavPath;
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

      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: kVoiceSampleRate,
        numChannels: kVoiceChannels,
        device: device,
      );

      final stream = await _recorder!.startStream(config);
      _audioSub = stream.listen(_onChunk);
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  void _onChunk(List<int> chunk) {
    _buffer.addAll(chunk);
    final rms = pcm16RmsLevel(chunk);
    final peak = pcm16PeakLevel(chunk);
    if (rms > _rmsAmplitude) _rmsAmplitude = rms;
    if (peak > _maxAmplitude) _maxAmplitude = peak;
    if (rms >= _levelThreshold || peak >= _levelThreshold) {
      _audioLevelSeen = true;
    }
    _ampController?.add(rms.clamp(0.0, 1.0));
  }

  Future<DesktopVoiceCaptureResult?> stopAndSaveWav({
    String? fileName,
    void Function(List<int> bytes)? onPartial,
  }) async {
    _partialTimer?.cancel();
    _partialTimer = null;
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

    final pcm = List<int>.from(_buffer);
    _buffer.clear();

    if (pcm.isNotEmpty && !_audioLevelSeen) {
      final peak = pcm16PeakLevel(pcm);
      final rms = pcm16RmsLevel(pcm);
      if (peak >= _levelThreshold || rms >= _levelThreshold) {
        _audioLevelSeen = true;
      }
      if (peak > _maxAmplitude) _maxAmplitude = peak;
      if (rms > _rmsAmplitude) _rmsAmplitude = rms;
    }

    if (pcm.length < 3200) {
      _lastError = 'Not enough audio';
      return null;
    }

    final dir = await _samplesDir();
    final name = fileName ?? 'latest_command.wav';
    final path = '${dir.path}${Platform.pathSeparator}$name';
    await writePcm16WavFile(pcm: pcm, path: path);
    _lastWavPath = path;
    onPartial?.call(pcm);

    return DesktopVoiceCaptureResult(
      wavPath: path,
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

  List<String> captureDiagLines() {
    return [
      'audio_device=$deviceLabel',
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
