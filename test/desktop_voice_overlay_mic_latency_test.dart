import 'dart:typed_data';

import 'package:counter/core/services/desktop_voice_audio_presentation.dart';
import 'package:counter/core/services/desktop_voice_overlay_constants.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('overlay font hard rule', () {
    test('no font below 16pt and cards are large', () {
      expect(DesktopVoiceOverlayConstants.minFontPt, greaterThanOrEqualTo(16));
      expect(DesktopVoiceOverlayConstants.detailFontPt, greaterThanOrEqualTo(16));
      expect(DesktopVoiceOverlayConstants.titleFontPt, inInclusiveRange(18, 20));
      expect(DesktopVoiceOverlayConstants.listeningWidthPx, inInclusiveRange(300, 360));
      expect(DesktopVoiceOverlayConstants.listeningHeightPx, inInclusiveRange(64, 72));
      expect(DesktopVoiceOverlayConstants.errorWidthPx, inInclusiveRange(420, 520));
      expect(DesktopVoiceOverlayConstants.errorHeightPx, inInclusiveRange(120, 150));
      expect(DesktopVoiceOverlayConstants.pendingWidthPx, inInclusiveRange(420, 520));
      expect(DesktopVoiceOverlayConstants.pendingHeightPx, inInclusiveRange(110, 140));
      expect(DesktopVoiceOverlayConstants.closeHitPx, greaterThanOrEqualTo(32));
    });
  });

  group('mic bars perceptual scale', () {
    test('RMS ~0.019 yields clearly visible display level', () {
      final display = DesktopVoiceAudioPresentation.perceptualLevel(
        peak: 0.36,
        rms: 0.0189,
      );
      expect(display, greaterThan(0.25));
      expect(display, lessThan(1.01));
      // Not raw linear peak/RMS.
      expect(display, isNot(closeTo(0.0189, 0.01)));
    });

    test('near-silence stays near idle', () {
      final display = DesktopVoiceAudioPresentation.perceptualLevel(
        peak: 0.002,
        rms: 0.001,
      );
      expect(display, lessThan(0.15));
    });
  });

  group('calibrated STT RMS gain', () {
    test('boosts quiet speech toward Handy target without peak-norm stretch', () {
      // Sparse quiet bursts ≈ live CPAL (RMS ~0.019).
      final bytes = <int>[];
      void push(int s) {
        bytes.add(s & 0xff);
        bytes.add((s >> 8) & 0xff);
      }
      for (var i = 0; i < 16000; i++) {
        push(((i % 200) < 2) ? 11000 : 40);
      }
      final beforeRms = pcm16RmsLevel(bytes);
      expect(beforeRms, inInclusiveRange(0.010, 0.035));
      final gained = applyCalibratedRmsGainForStt(bytes);
      expect(gained.applied, isTrue);
      expect(gained.mode, 'rms_target_peak_ceiling');
      expect(gained.processedPeak, lessThanOrEqualTo(0.91));
      expect(gained.processedRms, greaterThan(beforeRms));
      expect(gained.gainDb, greaterThan(0.5));
      expect(DesktopVoiceSttGain.applyCalibratedGainInProduction, isFalse);
      // Blind peak-norm helper must stay deprecated / unused in production path.
      // ignore: deprecated_member_use_from_same_package
      final peakNorm = normalizePcm16PeakForStt(bytes);
      expect(pcm16PeakLevel(peakNorm), greaterThan(0.7));
    });
  });

  group('raw WAV duration (stereo / fmt aware)', () {
    test('stereo 48k PCM16 reports correct duration', () {
      final pcm = Uint8List(48000 * 2 * 2); // 1s stereo
      final wav = pcm16ToWavBytesFull(
        pcm,
        sampleRate: 48000,
        channels: 2,
      );
      expect(wavBytesDurationMs(wav), closeTo(1000, 5));
      final info = parseWavHeader(wav)!;
      expect(info.channels, 2);
      expect(info.sampleRate, 48000);
      expect(info.durationMs, closeTo(1000, 5));
    });
  });

  group('command endpoint trim', () {
    test('trims leading/trailing silence while keeping speech', () {
      final pcm = <int>[];
      void push(int s) {
        pcm.add(s & 0xff);
        pcm.add((s >> 8) & 0xff);
      }
      // 1s silence + 1s speech + 1s silence @16kHz
      for (var i = 0; i < 16000; i++) {
        push(0);
      }
      for (var i = 0; i < 16000; i++) {
        push(8000);
      }
      for (var i = 0; i < 16000; i++) {
        push(0);
      }
      final trimmed = DesktopVoiceCommandEndpoint.trimSilencePcm16(pcm);
      expect(trimmed.length, lessThan(pcm.length));
      expect(pcm16DurationMs(trimmed), lessThan(2500));
      expect(pcm16DurationMs(trimmed), greaterThan(1000));
    });
  });
}
