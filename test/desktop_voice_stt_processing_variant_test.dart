import 'dart:io';

import 'package:counter/core/services/desktop_voice_stt_processing.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('STT processing variants — df696fc fixture', () {
    late List<int> pcm;

    setUp(() {
      final bytes = File(
        'test/fixtures/desktop_voice_wav/scw_delmod_submit_df696fc_live_quiet.wav',
      ).readAsBytesSync();
      pcm = bytes.sublist(44);
    });

    test('current variant is no-op', () {
      final r = applySttProcessingVariant(
        pcm,
        variant: DesktopVoiceSttProcessingVariant.current,
      );
      expect(r.applied, isFalse);
      expect(r.outputRms, closeTo(r.inputRms, 0.0001));
      expect(r.clippedSamples, 0);
    });

    test('RMS-target variants boost without clipping', () {
      for (final variant in [
        DesktopVoiceSttProcessingVariant.whisperRmsTarget055,
        DesktopVoiceSttProcessingVariant.whisperRmsTarget040,
      ]) {
        final r = applySttProcessingVariant(pcm, variant: variant);
        expect(r.applied, isTrue);
        expect(r.outputRms, greaterThan(r.inputRms));
        expect(r.outputPeak, lessThanOrEqualTo(0.91));
        expect(r.clippedSamples, 0);
      }
    });

    test('compressor/AGC and noise-gate variants stay peak-limited', () {
      for (final variant in [
        DesktopVoiceSttProcessingVariant.whisperCompressorAgc,
        DesktopVoiceSttProcessingVariant.whisperNoiseGateGain,
      ]) {
        final r = applySttProcessingVariant(pcm, variant: variant);
        expect(r.outputPeak, lessThanOrEqualTo(0.91));
        expect(r.clippedSamples, 0);
      }
    });

    test('command trim reduces duration without zeroing body', () {
      final r = applySttProcessingVariant(
        pcm,
        variant: DesktopVoiceSttProcessingVariant.commandTrimOnly,
      );
      expect(pcm16DurationMs(r.pcm), lessThanOrEqualTo(pcm16DurationMs(pcm)));
      expect(pcm16DurationMs(r.pcm), greaterThan(2000));
    });

    test('score ranks Southern transcript above truncated', () {
      const truncated = 'Computer Warehouse, DEL MOD, Submit.';
      const full = 'Southern Computer Warehouse, DEL MOD, Submit.';
      expect(scoreScwCommandTranscript(full), greaterThan(
        scoreScwCommandTranscript(truncated),
      ));
      expect(transcriptRecoversSouthern(full), isTrue);
      expect(transcriptRecoversSouthern(truncated), isFalse);
    });

    test('production policy stays off until Southern recovered offline', () {
      expect(DesktopVoiceSttProcessingPolicy.applyWhisperProcessingInProduction,
          isFalse);
      final prod = applyProductionWhisperSttProcessing(pcm);
      expect(prod.variant, DesktopVoiceSttProcessingVariant.current);
      expect(prod.applied, isFalse);
    });
  });
}
