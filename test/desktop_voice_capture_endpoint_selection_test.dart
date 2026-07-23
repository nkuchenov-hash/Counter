import 'package:counter/shared/voice/platforms/desktop/desktop_voice_capture_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('capture endpoint selection', () {
    test('auto role is default start request', () {
      final body = DesktopVoiceCaptureEndpointPolicy.startRequestBody();
      expect(body['endpoint_role'], 'auto');
    });

    test('communications role can be requested explicitly', () {
      final body = DesktopVoiceCaptureEndpointPolicy.startRequestBody(
        role: 'communications',
      );
      expect(body['endpoint_role'], 'communications');
    });

    test('helper JSON logging does not throw on partial payload', () {
      expect(
        () => DesktopVoiceCaptureEndpointPolicy.logFromHelperJson({
          'endpoint_id': 'id',
          'endpoint_role': 'console',
          'endpoint_volume': 1.0,
          'console_default_device': 'Mic A',
          'communications_default_device': 'Mic B',
        }),
        returnsNormally,
      );
    });

    test('capture gain experiment fields parse when present', () {
      final snap = DesktopVoiceCaptureEndpointSnapshot.fromJson({
        'capture_gain_mode': 'stt_copy_rms_target_058',
        'capture_gain_db': 8.5,
        'agc_enabled': false,
        'limiter_enabled': true,
        'clipped_samples': 0,
        'selected_gain_reason': 'handy_baseline_rms_experiment_new_capture_only',
      });
      expect(snap?.captureGainMode, 'stt_copy_rms_target_058');
      expect(snap?.limiterEnabled, isTrue);
      expect(snap?.selectedGainReason, contains('new_capture_only'));
    });
  });
}
