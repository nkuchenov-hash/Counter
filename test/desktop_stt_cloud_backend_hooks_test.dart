import 'package:counter/core/services/desktop_stt_cloud_service.dart';
import 'package:counter/core/services/desktop_stt_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    DesktopSttCloudBackendHooks.isSessionReady = null;
    DesktopSttCloudBackendHooks.postTranscribeCommand = null;
  });

  test('unwired cloud backend hooks report auth_required', () async {
    DesktopSttCloudBackendHooks.isSessionReady = null;
    DesktopSttCloudBackendHooks.postTranscribeCommand = null;

    expect(await DesktopSttCloudService.instance.isConfigured(), isFalse);

    final result = await DesktopSttCloudService.instance.transcribeCommandWav(
      const DesktopSttEngineContext(
        wavPath: 'missing.wav',
        pcmBytes: <int>[],
      ),
    );
    expect(result.engineId, 'cloud_best_quality');
    expect(result.errorKind, 'auth_required');
    expect(result.isSuccess, isFalse);
    expect(DesktopSttCloudService.instance.lastError, 'auth_required');
  });

  test('injected session-ready false maps to auth_required without POST',
      () async {
    var postCalled = false;
    DesktopSttCloudBackendHooks.isSessionReady = () async => false;
    DesktopSttCloudBackendHooks.postTranscribeCommand = ({
      required String audioBase64,
      required String languageHint,
      required List<String> glossaryTerms,
      required String glossaryPrompt,
    }) async {
      postCalled = true;
      return const DesktopSttCloudHttpResult(statusCode: 200, body: '{}');
    };

    final result = await DesktopSttCloudService.instance.transcribeCommandWav(
      const DesktopSttEngineContext(
        wavPath: 'missing.wav',
        pcmBytes: <int>[],
      ),
    );
    expect(result.errorKind, 'auth_required');
    expect(postCalled, isFalse);
  });
}
