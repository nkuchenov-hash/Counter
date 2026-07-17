import 'package:counter/services/plan_alarm_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('planAlarmOccurrenceKey / notification id', () {
    test('deterministic id per plan occurrence (stable across calls)', () {
      final keyA = planAlarmOccurrenceKey(
        stablePlanKey: 'abc1234567890xy',
        wallDateKey: '2026-07-20',
      );
      final keyB = planAlarmOccurrenceKey(
        stablePlanKey: 'abc1234567890xy',
        wallDateKey: '2026-07-20',
      );
      final keyOtherDay = planAlarmOccurrenceKey(
        stablePlanKey: 'abc1234567890xy',
        wallDateKey: '2026-07-21',
      );
      final virt = planAlarmOccurrenceKey(
        stablePlanKey: 'virt-parentpb15char-2026-07-20',
        wallDateKey: '2026-07-20',
      );

      expect(keyA, keyB);
      expect(keyA, 'abc1234567890xy|2026-07-20');
      expect(keyOtherDay, isNot(keyA));
      expect(virt, 'virt-parentpb15char-2026-07-20');

      final idA = planAlarmNotificationIdFromStableKey(keyA);
      final idB = planAlarmNotificationIdFromStableKey(keyB);
      final idOther = planAlarmNotificationIdFromStableKey(keyOtherDay);
      expect(idA, idB);
      expect(idA, isNot(idOther));
      expect(idA, greaterThan(0));
      expect(idA, lessThanOrEqualTo(0x7fffffff));
    });
  });

  group('tryBuildPlanAlarmSpec skip rules', () {
    final futureWall = DateTime(2099, 1, 15, 10, 0);
    final futureUtc = DateTime.utc(2099, 1, 15, 7, 0); // Moscow +3 wall 10:00
    final nowUtc = DateTime.utc(2026, 7, 17, 12, 0);

    test('past / completed / deleted plans are not scheduled', () {
      final done = tryBuildPlanAlarmSpec(
        stablePlanKey: 'planDone0000001',
        wallDateKey: '2099-01-15',
        startWall: futureWall,
        startUtcInstant: futureUtc,
        reminderOffsetMinutes: 15,
        isDone: true,
        isDeletedOrOptimistic: false,
        nowUtc: nowUtc,
        profileOffsetHours: 3,
        preferredTimezoneLabel: 'Moscow',
        title: 'Done',
      );
      expect(done.rejectReason, PlanAlarmRejectReason.done);
      expect(done.spec, isNull);

      final deleted = tryBuildPlanAlarmSpec(
        stablePlanKey: 'optimistic-xyz',
        wallDateKey: '2099-01-15',
        startWall: futureWall,
        startUtcInstant: futureUtc,
        reminderOffsetMinutes: 15,
        isDone: false,
        isDeletedOrOptimistic: true,
        nowUtc: nowUtc,
        profileOffsetHours: 3,
        preferredTimezoneLabel: 'Moscow',
        title: 'Opt',
      );
      expect(
        deleted.rejectReason,
        PlanAlarmRejectReason.deletedOrOptimistic,
      );

      final past = tryBuildPlanAlarmSpec(
        stablePlanKey: 'planPast0000001',
        wallDateKey: '2020-01-15',
        startWall: DateTime(2020, 1, 15, 10, 0),
        startUtcInstant: DateTime.utc(2020, 1, 15, 7, 0),
        reminderOffsetMinutes: 15,
        isDone: false,
        isDeletedOrOptimistic: false,
        nowUtc: nowUtc,
        profileOffsetHours: 3,
        preferredTimezoneLabel: 'Moscow',
        title: 'Past',
      );
      expect(past.rejectReason, PlanAlarmRejectReason.past);

      final ok = tryBuildPlanAlarmSpec(
        stablePlanKey: 'planOk000000001',
        wallDateKey: '2099-01-15',
        startWall: futureWall,
        startUtcInstant: futureUtc,
        reminderOffsetMinutes: 15,
        isDone: false,
        isDeletedOrOptimistic: false,
        nowUtc: nowUtc,
        profileOffsetHours: 3,
        preferredTimezoneLabel: 'Moscow',
        title: 'Future',
      );
      expect(ok.spec, isNotNull);
      expect(
        ok.spec!.fireUtc,
        DateTime.utc(2099, 1, 15, 6, 45), // 07:00 UTC start − 15m
      );
    });
  });

  group('finalizePlanAlarmSpecs replace without duplication', () {
    test('changed time same occurrence id keeps one entry (latest earliest sort)', () {
      const key = 'planReplace00001|2026-07-20';
      final id = planAlarmNotificationIdFromStableKey(key);
      final early = PlanAlarmSpec(
        notificationId: id,
        occurrenceKey: key,
        fireUtc: DateTime.utc(2026, 7, 20, 8, 0),
        title: 'A',
        reminderMinutes: 15,
      );
      final lateSameId = PlanAlarmSpec(
        notificationId: id,
        occurrenceKey: key,
        fireUtc: DateTime.utc(2026, 7, 20, 9, 0),
        title: 'A moved',
        reminderMinutes: 15,
      );
      final other = PlanAlarmSpec(
        notificationId: planAlarmNotificationIdFromStableKey(
          'planOther0000001|2026-07-20',
        ),
        occurrenceKey: 'planOther0000001|2026-07-20',
        fireUtc: DateTime.utc(2026, 7, 20, 10, 0),
        title: 'B',
        reminderMinutes: 5,
      );

      // Reconcile feeds the replacement after cancelAll; finalize must not
      // emit two pending rows for the same notification id.
      final out = finalizePlanAlarmSpecs([early, lateSameId, other]);
      expect(out.length, 2);
      expect(out.where((s) => s.notificationId == id).length, 1);
      expect(
        out.firstWhere((s) => s.notificationId == id).fireUtc,
        DateTime.utc(2026, 7, 20, 8, 0),
      );
    });
  });
}
