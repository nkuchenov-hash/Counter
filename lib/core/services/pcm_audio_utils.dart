import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// PCM16 mono capture constants (GOLOS-compatible).
const int kVoiceSampleRate = 16000;
const int kVoiceChannels = 1;

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
