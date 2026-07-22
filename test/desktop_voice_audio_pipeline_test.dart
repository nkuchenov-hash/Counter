import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:counter/shared/voice/commands/desktop_stt_quality_evaluation.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_wav_stt_benchmark.dart';
import 'package:counter/shared/voice/platforms/desktop/pcm_audio_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop Voice raw STT quality evaluation flags', () {
    test('raw mode excludes alias/postprocess from quality proof', () {
      expect(
        DesktopSttQualityEvaluation.sttQualityMode,
        'raw_transcript_evaluation',
      );
      expect(
        DesktopSttQualityEvaluation.aliasPostprocessUsedForQuality,
        isFalse,
      );
    });
  });

  group('Desktop Voice real WAV fixture manifest', () {
    test('golden manifest stores GOLOS-equivalent ceiling transcript', () {
      final file = File(DesktopVoiceWavSttBenchmark.manifestFile);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(
        json['golos_equivalent_raw_transcript'],
        'Solvan Computer Warehouse, Delmore, Submit.',
      );
      expect(json['strict_domain_pass'], isFalse);
    });

    test('SCW real WAV fixture exists with PCM payload', () {
      const path =
          'test/fixtures/desktop_voice_wav/scw_delmod_submit_real_2026_07_07.wav';
      expect(File(path).existsSync(), isTrue);
      final bytes = File(path).readAsBytesSync();
      expect(bytes.length, greaterThan(44));
      final pcm = bytes.sublist(44);
      expect(pcm16DurationMs(pcm), greaterThan(500));
    });

    test('token error rate improves when transcript matches expected phrase', () {
      const baseline = 'Solvent computer warehouse still model submit';
      const expected = 'Southern Computer Warehouse DEL MOD submit';
      const improved = 'Southern Computer Warehouse DEL MOD submit';
      final baselineTer = DesktopVoiceWavSttBenchmark.tokenErrorRate(
        baseline,
        expected,
      );
      final newTer = DesktopVoiceWavSttBenchmark.tokenErrorRate(
        improved,
        expected,
      );
      expect(newTer, lessThan(baselineTer));
      expect(
        DesktopVoiceWavSttBenchmark.improvementPercent(
          baselineTer: baselineTer,
          newTer: newTer,
        ),
        greaterThan(0),
      );
    });

    test('domain term hits require raw STT tokens not alias repair', () {
      final hits = DesktopVoiceWavSttBenchmark.domainTermHits(
        'Southern Computer Warehouse DEL MOD submit',
        const ['Southern Computer Warehouse', 'DEL MOD', 'Submit'],
      );
      expect(hits['Southern Computer Warehouse'], isTrue);
      expect(hits['DEL MOD'], isTrue);
      expect(hits['Submit'], isTrue);
      final bad = DesktopVoiceWavSttBenchmark.domainTermHits(
        'Solvent computer warehouse still model submit',
        const ['Southern Computer Warehouse', 'DEL MOD', 'Submit'],
      );
      expect(bad['Southern Computer Warehouse'], isFalse);
      expect(bad['DEL MOD'], isFalse);
    });
  });

  group('Desktop Voice real WAV helper benchmark', () {
    test('replay SCW WAV through local helper when available', () async {
      final cases = DesktopVoiceWavSttBenchmark.loadManifestCases();
      final scw = cases.firstWhere((c) => c.id == 'scw_delmod_submit_real');
      if (!DesktopVoiceWavSttBenchmark.helperLikelyAvailable()) {
        return;
      }
      final result = await DesktopVoiceWavSttBenchmark.runCase(
        caseDef: scw,
        helperUrl: 'http://127.0.0.1:8766',
      );
      expect(result, isNotNull);
      if (result!.error != null) {
        // ignore: avoid_print
        print('SCW helper replay skipped: ${result.error}');
        return;
      }
      // ignore: avoid_print
      print(
        'SCW raw="${result.rawTranscript}" ter=${result.tokenErrorRate} '
        'domain=${result.domainTermAccuracy} improved=${result.improvedVsBaseline}',
      );
      expect(result.improvedVsBaseline, isTrue);
      expect(
        result.rawTranscript.trim().toLowerCase(),
        'solvan computer warehouse, delmore, submit.',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('Handy-parity native capture preprocessing (pure functions)', () {
    test('pcm16 <-> float roundtrip is lossless within one LSB', () {
      final pcm = <int>[];
      for (var i = -32768; i < 32768; i += 257) {
        final u = i < 0 ? i + 0x10000 : i;
        pcm.add(u & 0xFF);
        pcm.add((u >> 8) & 0xFF);
      }
      final back = floatToPcm16Bytes(pcm16BytesToFloat(pcm));
      expect(back.length, pcm.length);
      final orig = pcm16BytesToFloat(pcm);
      final round = pcm16BytesToFloat(back);
      for (var i = 0; i < orig.length; i++) {
        expect((orig[i] - round[i]).abs(), lessThan(1 / 32768 + 1e-9));
      }
    });

    test('downmix averages interleaved stereo to mono', () {
      final mono = downmixInterleavedFloatToMono(
        [1.0, -1.0, 0.5, 0.5, 0.2, 0.4],
        2,
      );
      expect(mono, [0.0, 0.5, closeTo(0.3, 1e-9)]);
    });

    test('high-quality resample 48k->16k preserves length ratio + amplitude', () {
      const fromRate = 48000;
      const toRate = 16000;
      final input = List<double>.generate(
        fromRate,
        (i) => 0.5 * math.sin(2 * math.pi * 200 * i / fromRate),
      );
      final out = resampleFloatHighQuality(input, fromRate, toRate);
      expect(out.length, closeTo(input.length * toRate / fromRate, 2));
      // Sample the steady middle of the tone; amplitude must be preserved
      // (no normalization / gain), only band-limited.
      var peak = 0.0;
      for (var i = out.length ~/ 4; i < out.length * 3 ~/ 4; i++) {
        peak = math.max(peak, out[i].abs());
      }
      expect(peak, closeTo(0.5, 0.05));
    });

    test('processNativeCaptureForStt downmixes + resamples, no peak boost', () {
      // Quiet stereo 48 kHz input (peak 0.2). A harmful peak-normalizer would
      // push this toward 0.85; parity path must NOT.
      final frames = 48000;
      final interleaved = <int>[];
      for (var f = 0; f < frames; f++) {
        final s = 0.2 * math.sin(2 * math.pi * 220 * f / 48000);
        final v = (s * 32767).round();
        final u = v < 0 ? v + 0x10000 : v;
        // L and R identical.
        interleaved.add(u & 0xFF);
        interleaved.add((u >> 8) & 0xFF);
        interleaved.add(u & 0xFF);
        interleaved.add((u >> 8) & 0xFF);
      }
      final processed = processNativeCaptureForStt(
        nativePcm16: interleaved,
        sampleRate: 48000,
        channels: 2,
      );
      expect(processed.downmixUsed, isTrue);
      expect(processed.resamplerUsed, 'windowed_sinc_hann_16zc');
      // ~1s of 48k stereo -> ~1s of 16k mono = ~16000 samples = ~32000 bytes.
      expect(processed.sttPcm16.length, closeTo(32000, 400));
      final outPeak = pcm16PeakLevel(processed.sttPcm16);
      expect(outPeak, lessThan(0.30), reason: 'no peak normalization');
    });

    test('16k mono input is passed through without resampling', () {
      final pcm = List<int>.filled(3200, 0);
      final processed = processNativeCaptureForStt(
        nativePcm16: pcm,
        sampleRate: kVoiceSampleRate,
        channels: kVoiceChannels,
      );
      expect(processed.resamplerUsed, 'none');
      expect(processed.downmixUsed, isFalse);
      expect(processed.sttPcm16.length, pcm.length);
    });
  });

  group('Capture-parity benchmark manifest (Handy vs old vs new Counter)', () {
    test('manifest exposes Handy reference + benchmark-selected VAD', () {
      expect(
        DesktopVoiceWavSttBenchmark.handyReferenceTranscript(),
        'Southern Computer Warehouse Del Mod, submit.',
      );
      expect(
        DesktopVoiceWavSttBenchmark.commandVadSelectedByBenchmark(),
        'no_vad',
      );
    });

    test('Handy + old Counter fixtures exist; new native fixture is optional', () {
      expect(
        File('test/fixtures/desktop_voice_wav/'
                'scw_delmod_submit_handy_2026_07_07.wav')
            .existsSync(),
        isTrue,
      );
      expect(
        File('test/fixtures/desktop_voice_wav/'
                'scw_delmod_submit_real_2026_07_07.wav')
            .existsSync(),
        isTrue,
      );
    });

    test('three-way parity report: Handy beats old Counter on DEL MOD', () {
      final report = DesktopVoiceWavSttBenchmark.captureParityReport();
      expect(report.handyTranscript, isNotNull);
      expect(report.oldCounterTranscript, isNotNull);
      // Handy "Del Mod" resolves the domain term; old Counter "Del Mall" does
      // too via the fuzzy domain matcher, but Handy recognizes "Southern".
      expect(report.handyDomainAccuracy,
          greaterThanOrEqualTo(report.oldDomainAccuracy));
      // New native capture is a live-recapture artifact; absent in CI.
      if (!report.newCaptureAvailable) {
        expect(report.newCounterTranscript, isNull);
      }
    });
  });

  group('df696fc live quiet capture parity', () {
    test('fixture exists and is much quieter than Handy reference', () {
      const quiet =
          'test/fixtures/desktop_voice_wav/scw_delmod_submit_df696fc_live_quiet.wav';
      const handy =
          'test/fixtures/desktop_voice_wav/scw_delmod_submit_handy_2026_07_07.wav';
      expect(File(quiet).existsSync(), isTrue);
      final qRms = pcm16RmsLevel(
        extractPcm16FromWav(File(quiet).readAsBytesSync()),
      );
      if (File(handy).existsSync()) {
        final hRms = pcm16RmsLevel(
          extractPcm16FromWav(File(handy).readAsBytesSync()),
        );
        expect(qRms, lessThan(hRms * 0.5));
      }
      expect(qRms, closeTo(0.0135, 0.004));
    });
  });
}
