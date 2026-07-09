import 'dart:math' as math;

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_audio_presentation.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';

/// STT-only audio processing variants for quiet live command WAVs.
///
/// Raw capture WAV is never modified; only the PCM16 sent to whisper-tiny.
enum DesktopVoiceSttProcessingVariant {
  /// No STT-only processing (current processed WAV as captured).
  current,

  /// RMS-target gain tuned for whisper on quiet takes (~0.013 RMS).
  whisperRmsTarget055,

  /// Moderate RMS target when 0.055 over-boosts consonants.
  whisperRmsTarget040,

  /// Soft compressor + RMS lift (AGC-style, peak-limited).
  whisperCompressorAgc,

  /// Light noise gate then RMS-target gain.
  whisperNoiseGateGain,

  /// Command endpoint trim only (latency; no level change).
  commandTrimOnly,
}

/// Offline-selected variant for production whisper-tiny command path.
abstract final class DesktopVoiceSttProcessingPolicy {
  /// Set true only after [DesktopVoiceQuietWhisperBenchmark] proves improvement
  /// on `scw_delmod_submit_df696fc_live_quiet.wav`.
  static const bool applyWhisperProcessingInProduction = false;

  /// Offline whisper-tiny bench (2026-07-08): RMS gain variants do **not**
  /// recover "Southern" on df696fc live quiet fixture — capture level gap.
  /// fefb502 live quiet (2026-07-09): mangled to "All-in-computer Warehouse…"
  /// at RMS 0.015 — still STT-only unrecoverable; ready-cue/pre-roll is the
  /// first-word timing experiment, not a fake gain fix.
  static const String offlineBlocker =
      'whisper_tiny_df696fc_all_stt_gain_variants_missing_southern';

  static const String fefb502OfflineBlocker =
      'whisper_tiny_fefb502_all_in_computer_missing_southern_rms_0_015';

  static const String productionSelectionReason = offlineBlocker;

  /// Recorded whisper-tiny transcripts per variant (warm helper, same fixture).
  static const Map<String, String> offlineBenchmarkTranscripts = {
    'current': 'Computer Warehouse, DEL MOD, Submit.',
    'whisperRmsTarget055': 'Computer Warehouse, DEL MOD, Submit.',
    'whisperRmsTarget040': 'Computer Warehouse, DEL MOD, Submit.',
    'whisperRmsTarget030': 'Computer Warehouse, DEL MOD, Submit.',
  };

  static const Map<String, String> fefb502OfflineBenchmarkTranscripts = {
    'current': 'All-in-computer Warehouse, DEL MOD, Submit.',
  };

  static const double df696fcFixtureInputRms = 0.0135;
  static const double fefb502FixtureInputRms = 0.0150;
  static const double handyReferenceCaptureRms = 0.058;

  static const DesktopVoiceSttProcessingVariant productionVariant =
      DesktopVoiceSttProcessingVariant.whisperRmsTarget055;

  static const String expectedPhrase =
      'Southern Computer Warehouse, DEL MOD, Submit.';
}

class DesktopVoiceSttProcessingResult {
  const DesktopVoiceSttProcessingResult({
    required this.variant,
    required this.pcm,
    required this.inputRms,
    required this.inputPeak,
    required this.outputRms,
    required this.outputPeak,
    required this.gainDb,
    required this.compressorEnabled,
    required this.agcEnabled,
    required this.clippedSamples,
    required this.applied,
  });

  final DesktopVoiceSttProcessingVariant variant;
  final List<int> pcm;
  final double inputRms;
  final double inputPeak;
  final double outputRms;
  final double outputPeak;
  final double gainDb;
  final bool compressorEnabled;
  final bool agcEnabled;
  final int clippedSamples;
  final bool applied;
}

/// Domain-term score for SCW / DEL MOD / Submit (higher = better).
int scoreScwCommandTranscript(String transcript) {
  final t = transcript.toLowerCase();
  var score = 0;
  if (t.contains('southern')) score += 30;
  if (t.contains('computer warehouse') || t.contains('computer wear')) {
    score += 10;
  }
  if (RegExp(r'del\s*mod').hasMatch(t)) score += 20;
  if (t.contains('submit')) score += 10;
  if (t.contains('here.')) score -= 50;
  return score;
}

bool transcriptRecoversSouthern(String transcript) {
  return transcript.toLowerCase().contains('southern');
}

DesktopVoiceSttProcessingResult applySttProcessingVariant(
  List<int> pcm16, {
  required DesktopVoiceSttProcessingVariant variant,
  double whisperTargetRms = DesktopVoiceSttGain.whisperQuietTargetRms,
  double peakCeiling = DesktopVoiceSttGain.peakCeiling,
}) {
  final inputRms = pcm16RmsLevel(pcm16);
  final inputPeak = pcm16PeakLevel(pcm16);

  switch (variant) {
    case DesktopVoiceSttProcessingVariant.current:
      return DesktopVoiceSttProcessingResult(
        variant: variant,
        pcm: pcm16,
        inputRms: inputRms,
        inputPeak: inputPeak,
        outputRms: inputRms,
        outputPeak: inputPeak,
        gainDb: 0,
        compressorEnabled: false,
        agcEnabled: false,
        clippedSamples: 0,
        applied: false,
      );
    case DesktopVoiceSttProcessingVariant.commandTrimOnly:
      final trimmed = DesktopVoiceCommandEndpoint.trimSilencePcm16(pcm16);
      return DesktopVoiceSttProcessingResult(
        variant: variant,
        pcm: trimmed,
        inputRms: inputRms,
        inputPeak: inputPeak,
        outputRms: pcm16RmsLevel(trimmed),
        outputPeak: pcm16PeakLevel(trimmed),
        gainDb: 0,
        compressorEnabled: false,
        agcEnabled: false,
        clippedSamples: 0,
        applied: trimmed.length != pcm16.length,
      );
    case DesktopVoiceSttProcessingVariant.whisperRmsTarget055:
      return _fromGainResult(
        variant,
        applyCalibratedRmsGainForStt(
          pcm16,
          targetRms: DesktopVoiceSttGain.handyTargetRms,
          peakCeiling: peakCeiling,
        ),
        compressorEnabled: false,
        agcEnabled: false,
      );
    case DesktopVoiceSttProcessingVariant.whisperRmsTarget040:
      return _fromGainResult(
        variant,
        applyCalibratedRmsGainForStt(
          pcm16,
          targetRms: whisperTargetRms,
          peakCeiling: peakCeiling,
        ),
        compressorEnabled: false,
        agcEnabled: false,
      );
    case DesktopVoiceSttProcessingVariant.whisperCompressorAgc:
      return _fromGainResult(
        variant,
        _compressorAgcPcm16(
          pcm16,
          targetRms: whisperTargetRms,
          peakCeiling: peakCeiling,
        ),
        compressorEnabled: true,
        agcEnabled: true,
      );
    case DesktopVoiceSttProcessingVariant.whisperNoiseGateGain:
      final gated = _noiseGatePcm16(pcm16, threshold: 0.006);
      return _fromGainResult(
        variant,
        applyCalibratedRmsGainForStt(
          gated,
          targetRms: whisperTargetRms,
          peakCeiling: peakCeiling,
        ),
        compressorEnabled: false,
        agcEnabled: false,
      );
  }
}

DesktopVoiceSttProcessingResult _fromGainResult(
  DesktopVoiceSttProcessingVariant variant,
  CalibratedSttGainResult gain, {
  required bool compressorEnabled,
  required bool agcEnabled,
}) {
  return DesktopVoiceSttProcessingResult(
    variant: variant,
    pcm: gain.pcm,
    inputRms: gain.rawRms,
    inputPeak: gain.rawPeak,
    outputRms: gain.processedRms,
    outputPeak: gain.processedPeak,
    gainDb: gain.gainDb,
    compressorEnabled: compressorEnabled,
    agcEnabled: agcEnabled,
    clippedSamples: gain.clippedSamples,
    applied: gain.applied,
  );
}

List<int> _noiseGatePcm16(List<int> pcm, {required double threshold}) {
  if (pcm.length < 4) return pcm;
  const frameMs = 20;
  const sampleRate = 16000;
  final frameSamples = (sampleRate * frameMs) ~/ 1000;
  final out = List<int>.from(pcm);
  final samples = pcm.length ~/ 2;
  for (var f = 0; f * frameSamples < samples; f++) {
    final start = f * frameSamples;
    final end = math.min(start + frameSamples, samples);
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      final b = i * 2;
      final sample = out[b] | (out[b + 1] << 8);
      final signed = sample >= 0x8000 ? sample - 0x10000 : sample;
      final n = signed / 32768.0;
      sum += n * n;
    }
    final count = end - start;
    if (count <= 0) continue;
    final rms = math.sqrt(sum / count);
    if (rms >= threshold) continue;
    for (var i = start; i < end; i++) {
      final b = i * 2;
      out[b] = 0;
      out[b + 1] = 0;
    }
  }
  return out;
}

CalibratedSttGainResult _compressorAgcPcm16(
  List<int> pcm, {
  required double targetRms,
  required double peakCeiling,
}) {
  if (pcm.length < 2) {
    return applyCalibratedRmsGainForStt(pcm, targetRms: targetRms);
  }
  final floats = pcm16BytesToFloat(pcm);
  var maxAbs = 0.0;
  for (final f in floats) {
    final a = f.abs();
    if (a > maxAbs) maxAbs = a;
  }
  const ratio = 3.0;
  const knee = 0.02;
  final outFloats = List<double>.filled(floats.length, 0);
  for (var i = 0; i < floats.length; i++) {
    final x = floats[i];
    final ax = x.abs();
    if (ax <= knee) {
      outFloats[i] = x;
      continue;
    }
    final over = ax - knee;
    final compressed = knee + over / ratio;
    outFloats[i] = x.sign * compressed;
  }
  final compressedPcm = floatToPcm16Bytes(outFloats);
  return applyCalibratedRmsGainForStt(
    compressedPcm,
    targetRms: targetRms,
    peakCeiling: peakCeiling,
  );
}

/// Applies production whisper STT processing when policy enables it.
DesktopVoiceSttProcessingResult applyProductionWhisperSttProcessing(
  List<int> pcm16,
) {
  if (!DesktopVoiceSttProcessingPolicy.applyWhisperProcessingInProduction) {
    return applySttProcessingVariant(
      pcm16,
      variant: DesktopVoiceSttProcessingVariant.current,
    );
  }
  DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_PROCESSING_SELECTED_BY_TRANSCRIPT');
  DesktopVoicePipeline.mark(
    'stt_processing_variant',
    DesktopVoiceSttProcessingPolicy.productionVariant.name,
  );
  return applySttProcessingVariant(
    pcm16,
    variant: DesktopVoiceSttProcessingPolicy.productionVariant,
  );
}
