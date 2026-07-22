import 'dart:math' as math;

import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_capture_ready_policy.dart';

/// Perceptual / command-latency / STT-gain helpers for Desktop Voice.
///
/// UI level meters may amplify for visibility; STT gain must be benchmarked and
/// must never reintroduce blind peak normalization that harm domain terms.
abstract final class DesktopVoiceAudioPresentation {
  /// Map raw capture peak/RMS (0..1) to a visible 0..1 meter reading.
  /// Normal speech around RMS 0.015–0.02 must move bars clearly.
  /// Independent of STT gain — display-only.
  static double perceptualLevel({
    required double peak,
    required double rms,
  }) {
    final p = peak.clamp(0.0, 1.0);
    final r = rms.clamp(0.0, 1.0);
    // Prefer peak for bursts; fold RMS so steady quiet speech still registers.
    final energy = math.max(p, r * 1.85).clamp(0.0, 1.0);
    if (energy < 0.004) return 0.0;
    // Approximate dBFS from linear amplitude, then map –42..–6 dB → 0..1.
    final db = 20.0 * math.log(energy) / math.ln10;
    final mapped = ((db + 42.0) / 36.0).clamp(0.0, 1.0);
    // Floor so RMS ≈0.019 (~peak 0.02) sits clearly above idle.
    final floored = math.max(mapped, energy >= 0.012 ? 0.28 : 0.0);
    return floored.clamp(0.0, 1.0);
  }

  /// Reported display gain used when converting energy → visible bars.
  static const double levelMeterGain = 4.5;
}

/// Calibrated STT gain policy. Prefer RMS target + peak ceiling over peak-norm.
abstract final class DesktopVoiceSttGain {
  static const double handyTargetRms = 0.055;
  static const double peakCeiling = 0.90;

  /// Applied only when offline benchmark proves domain-term improvement.
  /// Parakeet 32ed528 take: gain did **not** change transcript — reject for Parakeet.
  static const bool applyCalibratedGainInProduction = false;

  /// Whisper-tiny quiet-live target (df696fc RMS ~0.0135). Selected only when
  /// offline bench on `scw_delmod_submit_df696fc_live_quiet.wav` improves transcript.
  static const double whisperQuietTargetRms = 0.040;

  static const String rejectedReason =
      'offline_replay_identical_transcript_after_rms_target_gain_parakeet_baseline';

  static const String whisperGainRejectedReason =
      'whisper_tiny_df696fc_all_stt_gain_variants_missing_southern';
}

/// Light energy-based trim for command-length audio. Keeps speech body plus
/// pads so final words (Submit / Del Mod) are not clipped. Used to cut
/// 5s+ idle audio before Parakeet without GOLOS VAD damage.
abstract final class DesktopVoiceCommandEndpoint {
  static const int prePadMs = DesktopVoiceCaptureReadyPolicy.preRollMs;
  static const int postPadMs = 350;
  static const double rmsThreshold = 0.008;
  static const int frameMs = 20;

  /// Returns a sublist of [pcm16] (16 kHz mono) covering speech + pads.
  /// Start trim is guarded so first phonemes ("Southern") are not cut.
  /// If speech cannot be found or span is almost full, returns [pcm16] unchanged.
  static List<int> trimSilencePcm16(
    List<int> pcm16, {
    int sampleRate = 16000,
  }) {
    if (pcm16.length < sampleRate) return pcm16;
    final samples = pcm16.length ~/ 2;
    final frameSamples = (sampleRate * frameMs) ~/ 1000;
    if (frameSamples <= 0) return pcm16;

    int? firstSpeech;
    int? lastSpeech;
    for (var f = 0; f * frameSamples < samples; f++) {
      final start = f * frameSamples;
      final end = (start + frameSamples).clamp(0, samples);
      var sum = 0.0;
      for (var i = start; i < end; i++) {
        final b = i * 2;
        if (b + 1 >= pcm16.length) break;
        final sample = pcm16[b] | (pcm16[b + 1] << 8);
        final signed = sample >= 0x8000 ? sample - 0x10000 : sample;
        final n = signed / 32768.0;
        sum += n * n;
      }
      final count = end - start;
      if (count <= 0) continue;
      final meanSq = sum / count;
      final level = meanSq <= 0 ? 0.0 : math.sqrt(meanSq);
      if (level >= rmsThreshold) {
        firstSpeech ??= start;
        lastSpeech = end;
      }
    }
    if (firstSpeech == null || lastSpeech == null) return pcm16;

    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerPreRoll,
      '${prePadMs}ms',
    );
    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerStartTrimGuard,
    );

    final post = (sampleRate * postPadMs) ~/ 1000;
    final a = DesktopVoiceCaptureReadyPolicy.guardedTrimStartSample(
      firstSpeechSample: firstSpeech,
      sampleRate: sampleRate,
      prePadMs: prePadMs,
    );
    final b = (lastSpeech + post).clamp(0, samples);
    if (a == 0) {
      DesktopVoicePipeline.mark(
        DesktopVoiceCaptureReadyPolicy.markerFirstPhonemeNotTrimmed,
      );
      DesktopVoicePipeline.mark(
        DesktopVoiceCaptureReadyPolicy.markerLeadingAudioPreserved,
      );
    }
    if (b - a < sampleRate ~/ 2) return pcm16; // keep at least ~0.5s
    // Always apply end-silence trim when it removes ≥120ms (latency win).
    if ((samples - (b - a)) < (sampleRate * 120) ~/ 1000) return pcm16;
    return pcm16.sublist(a * 2, b * 2);
  }
}
