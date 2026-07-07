import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// PCM16 mono capture constants (GOLOS-compatible).
const int kVoiceSampleRate = 16000;
const int kVoiceChannels = 1;

/// Handy-parity native capture request: device-native rate + stereo. Media
/// Foundation (record package) exposes PCM16 only, but requesting 48 kHz
/// stereo avoids MF's forced 16 kHz downsample so we control the resample.
const int kNativeCaptureSampleRate = 48000;
const int kNativeCaptureChannels = 2;

/// Computes normalized RMS level (0..1) from PCM16 LE mono bytes.
double pcm16RmsLevel(List<int> bytes) {
  if (bytes.length < 2) return 0;
  var sum = 0.0;
  var count = 0;
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    final sample = bytes[i] | (bytes[i + 1] << 8);
    final signed = sample >= 0x8000 ? sample - 0x10000 : sample;
    sum += signed * signed;
    count++;
  }
  if (count == 0) return 0;
  return (math.sqrt(sum / count) / 32768.0).clamp(0.0, 1.0);
}

/// Peak normalized amplitude (0..1) from PCM16 LE bytes.
double pcm16PeakLevel(List<int> bytes) {
  if (bytes.length < 2) return 0;
  var peak = 0;
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    final sample = bytes[i] | (bytes[i + 1] << 8);
    final signed = sample >= 0x8000 ? sample - 0x10000 : sample;
    final abs = signed < 0 ? -signed : signed;
    if (abs > peak) peak = abs;
  }
  return (peak / 32768.0).clamp(0.0, 1.0);
}

/// Wrap raw PCM16 LE mono bytes as a WAV file.
Uint8List pcm16ToWavBytes(List<int> pcm, {int sampleRate = kVoiceSampleRate}) {
  final dataSize = pcm.length;
  final buffer = ByteData(44 + dataSize);
  void writeStr(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      buffer.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeStr(0, 'RIFF');
  buffer.setUint32(4, 36 + dataSize, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, kVoiceChannels, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * kVoiceChannels * 2, Endian.little);
  buffer.setUint16(32, kVoiceChannels * 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);
  writeStr(36, 'data');
  buffer.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < dataSize; i++) {
    buffer.setUint8(44 + i, pcm[i]);
  }
  return buffer.buffer.asUint8List();
}

Future<File> writePcm16WavFile({
  required List<int> pcm,
  required String path,
  int sampleRate = kVoiceSampleRate,
}) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(pcm16ToWavBytes(pcm, sampleRate: sampleRate));
  return file;
}

int pcm16DurationMs(List<int> pcm, {int sampleRate = kVoiceSampleRate}) {
  if (pcm.isEmpty) return 0;
  return (pcm.length ~/ (kVoiceChannels * 2)) * 1000 ~/ sampleRate;
}

/// STT-only peak normalization — boosts quiet captures without changing capture path.
List<int> normalizePcm16PeakForStt(
  List<int> pcm, {
  double targetPeak = 0.85,
  double minPeakToBoost = 0.05,
}) {
  if (pcm.length < 2) return pcm;
  final peak = pcm16PeakLevel(pcm);
  if (peak < minPeakToBoost || peak >= targetPeak) return pcm;
  final gain = targetPeak / peak;
  final out = List<int>.from(pcm);
  for (var i = 0; i + 1 < out.length; i += 2) {
    final sample = out[i] | (out[i + 1] << 8);
    final signed = sample >= 0x8000 ? sample - 0x10000 : sample;
    final scaled = (signed * gain).round().clamp(-32768, 32767);
    final u = scaled < 0 ? scaled + 0x10000 : scaled;
    out[i] = u & 0xFF;
    out[i + 1] = (u >> 8) & 0xFF;
  }
  return out;
}

/// Extract PCM payload from a standard 44-byte-header PCM16 WAV file.
List<int> extractPcm16FromWav(List<int> wavBytes) {
  if (wavBytes.length <= 44) return const [];
  return wavBytes.sublist(44);
}

/// Duration in ms from a PCM16 LE mono WAV file on disk or bytes.
int wavBytesDurationMs(List<int> wavBytes) {
  final pcm = extractPcm16FromWav(wavBytes);
  if (pcm.isNotEmpty) {
    return pcm16DurationMs(pcm);
  }
  return 0;
}

Future<int> wavFileDurationMs(String path) async {
  final file = File(path);
  if (!file.existsSync()) return 0;
  return wavBytesDurationMs(await file.readAsBytes());
}

// ---------------------------------------------------------------------------
// Handy-parity capture preprocessing: native PCM16 (any rate/channels) ->
// float -> mono downmix -> high-quality resample -> PCM16 16 kHz mono.
// Kept as pure functions so the whole chain is unit-testable without a mic.
// ---------------------------------------------------------------------------

/// Decode PCM16 LE bytes to normalized float samples in [-1, 1].
List<double> pcm16BytesToFloat(List<int> bytes) {
  final n = bytes.length ~/ 2;
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final lo = bytes[i * 2];
    final hi = bytes[i * 2 + 1];
    final u = lo | (hi << 8);
    final signed = u >= 0x8000 ? u - 0x10000 : u;
    out[i] = signed / 32768.0;
  }
  return out;
}

/// Encode normalized float samples [-1, 1] to PCM16 LE bytes (hard clip only).
List<int> floatToPcm16Bytes(List<double> samples) {
  final out = List<int>.filled(samples.length * 2, 0);
  for (var i = 0; i < samples.length; i++) {
    var s = samples[i];
    if (s > 1.0) s = 1.0;
    if (s < -1.0) s = -1.0;
    final v = (s * 32767.0).round().clamp(-32768, 32767);
    final u = v < 0 ? v + 0x10000 : v;
    out[i * 2] = u & 0xFF;
    out[i * 2 + 1] = (u >> 8) & 0xFF;
  }
  return out;
}

/// Average interleaved multi-channel float frames down to mono.
///
/// Matches Handy's `recorder.rs` downmix (sum channels / channel count).
List<double> downmixInterleavedFloatToMono(
  List<double> interleaved,
  int channels,
) {
  if (channels <= 1) return List<double>.from(interleaved);
  final frames = interleaved.length ~/ channels;
  final out = List<double>.filled(frames, 0);
  for (var f = 0; f < frames; f++) {
    var sum = 0.0;
    for (var c = 0; c < channels; c++) {
      sum += interleaved[f * channels + c];
    }
    out[f] = sum / channels;
  }
  return out;
}

double _sinc(double x) {
  if (x == 0) return 1.0;
  final px = math.pi * x;
  return math.sin(px) / px;
}

/// High-quality windowed-sinc (Hann) resampler for arbitrary rate conversion.
///
/// Anti-aliased on downsample (cutoff scaled to the lower Nyquist). This is the
/// float, high-quality resample Counter previously delegated to Media
/// Foundation's fixed 16 kHz PCM16 conversion, brought into our control to
/// match Handy's `rubato`-based resample stage.
List<double> resampleFloatHighQuality(
  List<double> input,
  int fromRate,
  int toRate, {
  int zeroCrossings = 16,
}) {
  if (fromRate == toRate || input.isEmpty) return List<double>.from(input);
  final ratio = toRate / fromRate; // output samples per input sample
  final step = fromRate / toRate; // input samples per output sample
  final cutoff = ratio < 1.0 ? ratio : 1.0; // normalized cutoff (anti-alias)
  final halfWidth = zeroCrossings / cutoff; // support radius in input samples
  final outLen = (input.length * ratio).floor();
  final out = List<double>.filled(outLen, 0);
  for (var o = 0; o < outLen; o++) {
    final center = o * step;
    final iMin = (center - halfWidth).ceil();
    final iMax = (center + halfWidth).floor();
    var acc = 0.0;
    var wsum = 0.0;
    for (var i = iMin; i <= iMax; i++) {
      if (i < 0 || i >= input.length) continue;
      final dist = center - i;
      final wpos = dist / halfWidth; // [-1, 1] window position
      if (wpos <= -1 || wpos >= 1) continue;
      final hann = 0.5 * (1 + math.cos(math.pi * wpos));
      final k = _sinc(dist * cutoff) * cutoff * hann;
      acc += input[i] * k;
      wsum += k;
    }
    out[o] = wsum != 0 ? acc / wsum : acc;
  }
  return out;
}

/// Full PCM16 WAV writer supporting arbitrary sample rate and channel count
/// (used for the raw native-capture diagnostic file).
Uint8List pcm16ToWavBytesFull(
  List<int> pcm, {
  required int sampleRate,
  required int channels,
}) {
  final dataSize = pcm.length;
  final blockAlign = channels * 2;
  final byteRate = sampleRate * blockAlign;
  final buffer = ByteData(44 + dataSize);
  void writeStr(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      buffer.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeStr(0, 'RIFF');
  buffer.setUint32(4, 36 + dataSize, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little); // PCM
  buffer.setUint16(22, channels, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, byteRate, Endian.little);
  buffer.setUint16(32, blockAlign, Endian.little);
  buffer.setUint16(34, 16, Endian.little);
  writeStr(36, 'data');
  buffer.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < dataSize; i++) {
    buffer.setUint8(44 + i, pcm[i]);
  }
  return buffer.buffer.asUint8List();
}

Future<File> writePcm16WavFileFull({
  required List<int> pcm,
  required String path,
  required int sampleRate,
  required int channels,
}) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    pcm16ToWavBytesFull(pcm, sampleRate: sampleRate, channels: channels),
  );
  return file;
}

/// STT-ready processing result: raw native PCM16 -> mono 16 kHz PCM16.
class ProcessedSttAudio {
  const ProcessedSttAudio({
    required this.sttPcm16,
    required this.downmixUsed,
    required this.resamplerUsed,
    required this.fromSampleRate,
    required this.fromChannels,
  });

  final List<int> sttPcm16;
  final bool downmixUsed;
  final String resamplerUsed;
  final int fromSampleRate;
  final int fromChannels;
}

/// Handy-parity chain: native interleaved PCM16 -> float -> mono downmix ->
/// high-quality resample to 16 kHz -> PCM16. No peak normalization (proven
/// harmful for Parakeet on the SCW fixture: Solvan -> Solvent).
ProcessedSttAudio processNativeCaptureForStt({
  required List<int> nativePcm16,
  required int sampleRate,
  required int channels,
}) {
  final floats = pcm16BytesToFloat(nativePcm16);
  final downmixUsed = channels > 1;
  final mono = downmixInterleavedFloatToMono(floats, channels);
  final needsResample = sampleRate != kVoiceSampleRate;
  final resampled = needsResample
      ? resampleFloatHighQuality(mono, sampleRate, kVoiceSampleRate)
      : mono;
  return ProcessedSttAudio(
    sttPcm16: floatToPcm16Bytes(resampled),
    downmixUsed: downmixUsed,
    resamplerUsed: needsResample ? 'windowed_sinc_hann_16zc' : 'none',
    fromSampleRate: sampleRate,
    fromChannels: channels,
  );
}
