import 'package:counter/core/services/desktop_voice_correction_flow.dart';
import 'package:counter/core/services/desktop_voice_install_smoke_policy.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _scwTree() {
  return CategoryRule(
    id: 10,
    name: 'Work',
    backendRowId: 'workroot1234567',
    children: [
      CategoryRule(
        id: 100,
        name: 'Price Reporter',
        backendRowId: 'prroot123456789',
        children: [
          CategoryRule(
            id: 103,
            name: 'Southern Computer Warehouse',
            backendRowId: 'scwclient123456',
            keywords: {
              'en': ['southern computer warehouse', 'scw'],
            },
            children: [
              CategoryRule(
                id: 104,
                name: 'DEL MOD',
                backendRowId: 'scwdelmod123456',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('Desktop voice command lifecycle after correction', () {
    test('pending id preserved across correction session', () {
      final session = DesktopVoiceCorrectionSession(
        pendingCommandId: 'pending_abc',
      );
      expect(session.tryBeginOpen(), isTrue);
      session.markConfirmed(
        text: 'Southern Computer Warehouse, DEL MOD, Submit.',
        title: 'Submit',
        path: 'Work > Price Reporter > SOUTHERN COMPUTER warehouse',
        parserResult: 'exact',
      );
      expect(session.pendingCommandId, 'pending_abc');
      expect(session.confirmed, isTrue);
      session.markWrite(success: true);
      expect(session.writeRequested, isTrue);
      expect(session.writeSuccess, isTrue);
      expect(session.pendingStateCleared, isTrue);
    });

    test('cancel clears pending and never writes', () {
      final session = DesktopVoiceCorrectionSession(
        pendingCommandId: 'pending_x',
      );
      session.tryBeginOpen();
      session.markCancelled();
      expect(session.cancelled, isTrue);
      expect(session.writeRequested, isFalse);
      expect(session.pendingStateCleared, isTrue);
      expect(
        DesktopVoiceCorrectionFlow.cancelRequestsWrite(cancelled: true),
        isFalse,
      );
    });

    test('exact SCW parse remains safe to start (no lost command)', () {
      final parsed = parseVoiceCommand(
        rules: [_scwTree()],
        transcript: 'Southern Computer Warehouse, DEL MOD, Submit.',
      );
      expect(parsed.isSafeToStart, isTrue);
      expect(parsed.recordTitle.toLowerCase(), contains('submit'));
    });

    test('lifecycle markers are stable', () {
      expect(
        DesktopVoiceCorrectionFlow.markerNoLostPending,
        'DESKTOP_VOICE_NO_LOST_PENDING_COMMAND_AFTER_CORRECTION',
      );
      expect(
        DesktopVoiceCorrectionFlow.markerConfirmNotNoop,
        'DESKTOP_VOICE_CORRECTION_CONFIRM_NOT_NOOP',
      );
      expect(
        DesktopVoiceCorrectionFlow.markerNoDuplicateWrite,
        'DESKTOP_VOICE_NO_DUPLICATE_WRITE_AFTER_CORRECTION',
      );
      expect(
        DesktopVoiceInstallSmokePolicy.isUsefulCandidateLatencyPass(
          candidateUseful: true,
          stopToUsefulCandidateMs: 592,
        ),
        isFalse,
      );
    });
  });
}
