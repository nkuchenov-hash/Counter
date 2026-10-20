import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

const viktorAudioSampleRate = 16000;
const viktorVoiceMaxSeconds = 60;
const viktorVoiceMaxPcmBytes = viktorAudioSampleRate * 2 * viktorVoiceMaxSeconds;

/// A genuine audio capture, independent of the browser's SpeechRecognition
/// service (which can claim to be listening without returning any transcript).
/// Matches the proven PCM16 capture used by the LIFE OS Notes recorder.
class ViktorVoiceRecorder extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final List<int> _pcm = <int>[];
  final Stopwatch _clock = Stopwatch();
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _ticker;
  bool _active = false;
  bool _disposed = false;
  bool limitReached = false;
  String? captureError;
  double level = 0;

  bool get isRecording => _active;
  int get durationMs => _clock.elapsedMilliseconds;
  int get capturedBytes => _pcm.length;
  bool get hasAudio => _pcm.isNotEmpty;

  Future<void> start() async {
    if (_active) return;
    captureError = null;
    limitReached = false;
    level = 0;
    _pcm.clear();
    if (!await _recorder.hasPermission()) {
      throw StateError('microphone_permission_denied');
    }
    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: viktorAudioSampleRate,
        numChannels: 1,
      ));
      _active = true;
      _audioSubscription = stream.listen((chunk) {
        if (chunk.isEmpty || limitReached || _disposed) return;
        final remaining = viktorVoiceMaxPcmBytes - _pcm.length;
        if (chunk.length >= remaining) {
          if (remaining > 0) _pcm.addAll(chunk.sublist(0, remaining));
          limitReached = true;
        } else {
          _pcm.addAll(chunk);
        }
        if (!_disposed) notifyListeners();
      }, onError: (Object error, StackTrace trace) {
        captureError = error.toString();
        if (!_disposed) notifyListeners();
      });
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 90))
          .listen((amplitude) {
        if (_disposed) return;
        level = ((amplitude.current + 60) / 60).clamp(0.0, 1.0).toDouble();
        notifyListeners();
      }, onError: (Object error) {
        // The PCM stream may still record correctly without the meter.
      });
      _clock
        ..reset()
        ..start();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (_disposed) return;
        if (durationMs >= viktorVoiceMaxSeconds * 1000) limitReached = true;
        notifyListeners();
      });
      notifyListeners();
    } catch (_) {
      await discard();
      rethrow;
    }
  }

  /// Stop recording; return a complete 16kHz mono PCM16 WAV.
  /// Never return a silent success when the recorder captured zero samples.
  Future<Uint8List> stop() async {
    if (!_active) throw StateError('voice_not_recording');
    _active = false;
    _clock.stop();
    _ticker?.cancel();
    _ticker = null;
    try {
      await _recorder.stop();
    } finally {
      await _audioSubscription?.cancel();
      await _amplitudeSubscription?.cancel();
      _audioSubscription = null;
      _amplitudeSubscription = null;
      level = 0;
      if (!_disposed) notifyListeners();
    }
    if (captureError != null) throw StateError('voice_capture_failed');
    if (_pcm.length < 16000) throw StateError('recording_too_short');
    return buildViktorWav(Uint8List.fromList(_pcm));
  }

  Future<void> discard() async {
    _clock.stop();
    _ticker?.cancel();
    _ticker = null;
    if (_active) {
      _active = false;
      try { await _recorder.stop(); } catch (_) {}
    }
    await _audioSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
    _audioSubscription = null;
    _amplitudeSubscription = null;
    _pcm.clear();
    level = 0;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    unawaited(_recorder.stop().catchError((Object _) {}));
    unawaited(_audioSubscription?.cancel());
    unawaited(_amplitudeSubscription?.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }
}

@visibleForTesting
Uint8List buildViktorWav(Uint8List pcm) {
  if (pcm.isEmpty || pcm.length.isOdd || pcm.length > viktorVoiceMaxPcmBytes) {
    throw ArgumentError.value(pcm.length, 'pcm', 'Invalid PCM16 audio size');
  }
  final wav = Uint8List(44 + pcm.length);
  final data = ByteData.sublistView(wav);
  void fourCc(int offset, String ascii) {
    for (var i = 0; i < 4; i++) wav[offset + i] = ascii.codeUnitAt(i);
  }
  fourCc(0, 'RIFF');
  data.setUint32(4, 36 + pcm.length, Endian.little);
  fourCc(8, 'WAVE');
  fourCc(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, viktorAudioSampleRate, Endian.little);
  data.setUint32(28, viktorAudioSampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  fourCc(36, 'data');
  data.setUint32(40, pcm.length, Endian.little);
  wav.setRange(44, wav.length, pcm);
  return wav;
}
