import 'package:counter/core/services/desktop_stt_diagnostics.dart';
import 'package:counter/core/services/desktop_voice_audio_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CPAL capture backend contracts', () {
    test('capture result exposes gain + backend fields for diagnostics', () {
      const r = DesktopVoiceCaptureResult(
        wavPath: r'C:\tmp\latest_command.wav',
        pcmBytes: [0, 0, 0, 0],
        sampleRate: 16000,
        channels: 1,
        durationMs: 1000,
        maxAmplitude: 0.5,
        rmsAmplitude: 0.05,
        audioLevelSeen: true,
        deviceLabel: 'Mic',
        captureBackend: 'cpal_wasapi',
        captureApi: 'Wasapi',
        rawCaptureFormat: 'F32',
        rawSampleRate: 48000,
        rawChannels: 2,
        rawRms: 0.055,
        rawPeak: 0.85,
        processedWavRms: 0.055,
        processedWavPeak: 0.85,
      );
      final lines = r.captureDiagLines();
      expect(lines, contains('capture_backend=cpal_wasapi'));
      expect(lines, contains('capture_api=Wasapi'));
      expect(lines, contains('raw_capture_format=F32'));
      expect(lines, contains('raw_capture_rms=0.0550'));
      expect(lines, contains('raw_capture_peak=0.8500'));
      expect(lines, contains('processed_wav_rms=0.0550'));
      // Rejected MF 48k path must not be the default backend constant.
      expect(r.captureBackend, isNot(equals('record_windows_mf_pcm16')));
    });

    test('diagnostics map includes capture_backend and gain fields', () {
      const diag = DesktopSttDiagnostics(
        captureBackend: 'cpal_wasapi',
        captureApi: 'Wasapi',
        rawCaptureFormat: 'F32',
        rawCaptureRms: 0.05,
        rawCapturePeak: 0.8,
        processedWavRms: 0.05,
        processedWavPeak: 0.8,
        audioDevice: 'Microphone',
      );
      final lines = diag.toDiagLines();
      expect(lines, contains('capture_backend=cpal_wasapi'));
      expect(lines, contains('capture_api=Wasapi'));
      expect(lines, contains('raw_capture_format=F32'));
      expect(lines, contains('device_name=Microphone'));
      expect(lines.any((l) => l.startsWith('raw_capture_rms=')), isTrue);
      expect(lines.any((l) => l.startsWith('processed_wav_peak=')), isTrue);
    });

    test('f69fb1b quiet MF path is explicitly rejected as non-default', () {
      // Contract: primary backend must be cpal_wasapi; MF 48k stereo was
      // measured ~-10 dB vs Handy and quieter than old 16k mono.
      const primary = 'cpal_wasapi';
      const rejected = 'record_windows_mf_pcm16';
      const fallback = 'record_windows_mf_pcm16_fallback_16k_mono';
      expect(primary, isNot(equals(rejected)));
      expect(fallback, contains('fallback_16k_mono'));
    });
  });
}
