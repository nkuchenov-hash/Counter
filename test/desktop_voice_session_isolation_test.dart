import 'package:counter/shared/voice/platforms/desktop/desktop_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop voice session isolation', () {
    tearDown(() {
      DesktopVoiceSessionRegistry.end(reason: 'test_teardown');
    });

    test('only one active session; new session invalidates prior', () {
      final a = DesktopVoiceSessionRegistry.begin();
      expect(DesktopVoiceSessionRegistry.activeCount, 1);
      expect(DesktopVoiceSessionRegistry.active?.id, a.id);

      final b = DesktopVoiceSessionRegistry.begin();
      expect(DesktopVoiceSessionRegistry.priorSessionId, a.id);
      expect(DesktopVoiceSessionRegistry.active?.id, b.id);
      expect(b.generation, greaterThan(a.generation));
    });

    test('stale async result from prior session is discarded', () {
      final a = DesktopVoiceSessionRegistry.begin();
      DesktopVoiceSessionRegistry.begin();
      expect(
        DesktopVoiceSessionRegistry.acceptResult(
          resultSessionId: a.id,
          source: 'unit_test',
        ),
        isFalse,
      );
    });

    test('matching session result is accepted', () {
      final s = DesktopVoiceSessionRegistry.begin();
      expect(
        DesktopVoiceSessionRegistry.acceptResult(
          resultSessionId: s.id,
          source: 'unit_test',
        ),
        isTrue,
      );
    });

    test('session generation increments', () {
      final a = DesktopVoiceSessionRegistry.begin();
      final b = DesktopVoiceSessionRegistry.begin();
      expect(b.generation, greaterThan(a.generation));
      expect(DesktopVoiceSessionRegistry.priorSessionId, a.id);
    });
  });
}
