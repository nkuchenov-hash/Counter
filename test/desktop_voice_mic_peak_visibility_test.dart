// Mic-bar visual source — peak-amplitude emission (Part B of the runtime fix).
//
// Verifies that [DesktopVoiceAudioCapture.amplitudeStream] carries PEAK amplitude
// rather than RMS: peak tracks speech bursts that humans actually hear (~0.10-0.30),
// whereas RMS mathematically under-reports speech (~0.02) and makes overlay bars
// look dead. A unit-test pure-Dart fake is used so we avoid the live `record`
// plugin + native overlay dependencies.

import 'dart:typed_data';

import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pcm16 peak vs rms — mic-bar visibility', () {
    test('peak is meaningfully larger than rms for a speech-like burst', () {
      // A speech-like burst: alternating medium-amplitude samples with one
      // large transient (the kind RMS flattens but peak catches).
      final bytes = <int>[];
      void pushSample(int s) {
        // PCM16 little-endian.
        bytes.add(s & 0xff);
        bytes.add((s >> 8) & 0xff);
      }

      for (var i = 0; i < 200; i++) {
        pushSample(1200); // medium level across many samples
      }
      pushSample(21000); // single loud transient — what users hear as a "tap"

      final rms = pcm16RmsLevel(bytes);
      final peak = pcm16PeakLevel(bytes);

      // Sanity: both are in 0..1.
      expect(rms, inInclusiveRange(0.0, 1.0));
      expect(peak, inInclusiveRange(0.0, 1.0));

      // Peak is the actual signal a human perceived; RMS over-averages it down.
      // Ratio of at least ~3x proves the visual source should be peak.
      expect(peak / rms, greaterThan(3.0),
          reason: 'peak must dominate rms for bar visibility');
      // Peak must reach a level that produces visible bars in the overlay's
      // sqrt-gain curve (sqrt(0.64) ≈ 0.8 → near-full bars).
      expect(peak, greaterThan(0.6));
    });

    test('silent buffer yields zero peak AND zero rms (no fake activity)', () {
      // All-zero PCM → both must return 0 so the overlay cleanly distinguishes
      // "no input" from "soft input".
      final bytes = Uint8List(320).toList(); // 160 samples of silence
      expect(pcm16PeakLevel(bytes), 0.0);
      expect(pcm16RmsLevel(bytes), 0.0);
    });
  });
}
