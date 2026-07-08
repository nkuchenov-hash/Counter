import 'dart:io';

import 'package:counter/core/services/desktop_voice_last_attempt_store.dart';
import 'package:counter/core/services/desktop_stt_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('last attempt diag is written under voice_samples', () async {
    final path = DesktopVoiceLastAttemptStore.lastAttemptPath;
    expect(path, contains('voice_samples'));
    expect(path, endsWith('last_attempt_diag.txt'));

    await DesktopVoiceLastAttemptStore.write(
      diag: const DesktopSttDiagnostics(
        transcribeCalled: true,
        delayedTranscribeCalled: true,
        delayedTranscribeResult: 'success',
        finalText: 'probe',
        finalTranscriptSource: 'parakeet_final',
        pendingWavAfterStop: true,
        helperReadyAfterRecording: true,
        overlayRendererActive: 'native_handy_pill',
      ),
      friendlyError: null,
      attemptPlainText: 'status=probe',
    );

    final file = File(path);
    expect(file.existsSync(), isTrue);
    final body = await file.readAsString();
    expect(body, contains('transcribe_called=yes'));
    expect(body, contains('delayed_transcribe_called=yes'));
    expect(body, contains('final_text=probe'));
    expect(body, contains('overlay_renderer_active=native_handy_pill'));
    await file.delete();
  });
}
