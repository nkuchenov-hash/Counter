import 'package:counter/shared/voice/commands/desktop_voice_install_smoke_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop voice install smoke policy', () {
    test('662ms useful candidate is not latency pass', () {
      expect(
        DesktopVoiceInstallSmokePolicy.isUsefulCandidateLatencyPass(
          candidateUseful: true,
          stopToUsefulCandidateMs: 662,
        ),
        isFalse,
      );
    });

    test('499ms useful candidate is latency pass', () {
      expect(
        DesktopVoiceInstallSmokePolicy.isUsefulCandidateLatencyPass(
          candidateUseful: true,
          stopToUsefulCandidateMs: 499,
        ),
        isTrue,
      );
    });

    test('500ms useful candidate is not latency pass', () {
      expect(
        DesktopVoiceInstallSmokePolicy.isUsefulCandidateLatencyPass(
          candidateUseful: true,
          stopToUsefulCandidateMs: 500,
        ),
        isFalse,
      );
    });

    test('non-useful candidate is never latency pass', () {
      expect(
        DesktopVoiceInstallSmokePolicy.isUsefulCandidateLatencyPass(
          candidateUseful: false,
          stopToUsefulCandidateMs: 200,
        ),
        isFalse,
      );
    });

    test('endpoint diag fields present when populated', () {
      final lines = [
        'endpoint_id={0.0.1.00000000}.{abc}',
        'endpoint_role=console',
        'endpoint_volume=0.714',
        'console_default_device=Mic (Realtek)',
        'communications_default_device=Mic (Realtek)',
        'selected_capture_endpoint=Mic (Realtek)',
        'capture_mix_format=48000Hz 2ch pcm',
        'capture_backend=cpal_wasapi',
        'capture_api=Wasapi',
        'raw_capture_rms=0.0165',
        'raw_capture_peak=0.2602',
        'processed_wav_rms=0.0166',
        'processed_wav_peak=0.2561',
        'capture_gain_mode=off',
      ];
      expect(
        DesktopVoiceInstallSmokePolicy.endpointDiagFieldsPresent(lines),
        isTrue,
      );
    });

    test('endpoint diag fails when endpoint_id missing', () {
      final lines = [
        'endpoint_role=console',
        'endpoint_volume=0.714',
      ];
      expect(
        DesktopVoiceInstallSmokePolicy.endpointDiagFieldsPresent(lines),
        isFalse,
      );
    });

    test('install identity fails on sha mismatch', () {
      expect(
        DesktopVoiceInstallSmokePolicy.installIdentityPass(
          expectedBuildSha: '9e564be',
          runningBuildSha: 'df696fc',
          counterExeReplaced: true,
          helperExeReplaced: true,
          staleProcessAbsent: true,
          runningPathMatchesInstalled: true,
        ),
        isFalse,
      );
    });

    test('install identity fails when only helper replaced', () {
      expect(
        DesktopVoiceInstallSmokePolicy.installIdentityPass(
          expectedBuildSha: '9e564be',
          runningBuildSha: '9e564be',
          counterExeReplaced: false,
          helperExeReplaced: true,
          staleProcessAbsent: true,
          runningPathMatchesInstalled: true,
        ),
        isFalse,
      );
    });

    test('install identity passes when app and helper match', () {
      final buildAt = DateTime.utc(2026, 7, 9, 20, 0);
      expect(
        DesktopVoiceInstallSmokePolicy.installIdentityPass(
          expectedBuildSha: '9e564be',
          runningBuildSha: '9e564be',
          counterExeReplaced: true,
          helperExeReplaced: true,
          staleProcessAbsent: true,
          runningPathMatchesInstalled: true,
          buildStartedAt: buildAt,
          appFileTime: buildAt.add(const Duration(minutes: 2)),
        ),
        isTrue,
      );
    });

    test('df696fc is stale blocked sha', () {
      expect(DesktopVoiceInstallSmokePolicy.isStaleBuildSha('df696fc'), isTrue);
      expect(DesktopVoiceInstallSmokePolicy.isStaleBuildSha('dev'), isTrue);
    });

    test('desktop shortcut must point to installed exe not dev build', () {
      const installed =
          r'C:\Users\me\AppData\Local\Programs\Counter\counter.exe';
      expect(
        DesktopVoiceInstallSmokePolicy.desktopShortcutPointsToInstalled(
          shortcutTarget: installed,
          installedExePath: installed,
        ),
        isTrue,
      );
      expect(
        DesktopVoiceInstallSmokePolicy.desktopShortcutPointsToInstalled(
          shortcutTarget:
              r'C:\Users\me\Development\Apps\counter\build\windows\x64\runner\Release\counter.exe',
          installedExePath: installed,
        ),
        isFalse,
      );
      expect(
        DesktopVoiceInstallSmokePolicy.isStaleShortcutTarget(
          r'C:\Users\me\Development\Apps\counter\build\windows\x64\runner\Release\counter.exe',
        ),
        isTrue,
      );
      expect(
        DesktopVoiceInstallSmokePolicy.isStaleShortcutTarget(installed),
        isFalse,
      );
    });
  });
}
