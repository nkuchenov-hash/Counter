import 'package:counter/core/services/desktop_voice_capture_endpoint.dart';
import 'package:counter/core/services/desktop_voice_windows_audio_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windows endpoint diagnostics contracts', () {
    test('capture endpoint policy exposes auto role and markers', () {
      expect(DesktopVoiceCaptureEndpointPolicy.defaultRole, 'auto');
      expect(
        DesktopVoiceCaptureEndpointPolicy.startRequestBody()['endpoint_role'],
        'auto',
      );
      expect(
        DesktopVoiceCaptureEndpointPolicy.markerEndpointSelected,
        'DESKTOP_VOICE_CAPTURE_ENDPOINT_SELECTED',
      );
      expect(
        DesktopVoiceCaptureEndpointPolicy.markerRoleSelected,
        'DESKTOP_VOICE_CAPTURE_ENDPOINT_ROLE_SELECTED',
      );
      expect(
        DesktopVoiceCaptureEndpointPolicy.markerFallbackReady,
        'DESKTOP_VOICE_CAPTURE_ENDPOINT_FALLBACK_READY',
      );
    });

    test('snapshot parses helper endpoint JSON fields', () {
      final snap = DesktopVoiceCaptureEndpointSnapshot.fromJson({
        'endpoint_id': '{0.0.1.00000000}.{guid}',
        'endpoint_role': 'console',
        'endpoint_volume': 0.82,
        'endpoint_muted': false,
        'session_volume': 0.82,
        'console_default_device': 'Microphone (Realtek)',
        'communications_default_device': 'Microphone (Realtek)',
        'mix_sample_rate': 48000,
        'mix_channels': 2,
        'mix_sample_format': 'F32',
        'capture_gain_mode': 'off',
        'capture_gain_db': 0.0,
        'selected_gain_reason': 'capture_gain_experiment_disabled',
      });
      expect(snap, isNotNull);
      expect(snap!.endpointId, contains('guid'));
      expect(snap.endpointRole, 'console');
      expect(snap.endpointVolume, closeTo(0.82, 0.001));
      expect(snap.consoleDefaultDevice, contains('Realtek'));
      expect(snap.mixSampleRate, 48000);
    });

    test('Handy vs Counter RMS baseline constants documented', () {
      expect(
        DesktopVoiceWindowsAudioDiagnostics.handyReferenceCaptureRms,
        closeTo(0.058, 0.01),
      );
      expect(
        DesktopVoiceWindowsAudioDiagnostics.df696fcLiveQuietRms,
        closeTo(0.0135, 0.005),
      );
    });
  });
}
