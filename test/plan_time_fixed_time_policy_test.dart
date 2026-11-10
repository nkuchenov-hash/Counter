import 'package:counter/data/models.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPlanFixedInTimeView', () {
    test('plan with fixed pb tag id is fixed', () {
      const fixedIds = {'abc123456789012'};
      final task = PlanningTask(
        id: 1,
        title: 'Meeting',
        dateKey: '2026-06-15',
        order: 0,
        isDone: false,
        categoryId: 1,
        tags: const [
          Tag(
            tagId: 1,
            name: 'Meeting',
            pbRecordId: 'abc123456789012',
          ),
        ],
      );
      expect(isPlanFixedInTimeView(task, fixedIds), isTrue);
    });

    test('meeting is fixed even with empty local preferences', () {
      for (final tag in ['Meeting', 'MEETINGS', 'Встречи', 'созвон', 'call']) {
        final plan = PlanningTask(
          id: 8, title: '13:30 appointment', dateKey: '2026-11-10',
          order: 1, isDone: false, categoryId: 1,
          startTime: DateTime(2026, 11, 10, 13, 30),
          endDateTime: DateTime(2026, 11, 10, 14, 0),
          tags: [Tag(tagId: 0, name: tag)],
        );
        expect(isPlanFixedInTimeView(plan, const {}), isTrue,
          reason: 'An appointment tag must be iron-locked: $tag');
      }
    });

    test('automatic shift of fixed meeting start OR end is denied', () {
      final meeting = PlanningTask(
        id: 10, planRowId: 'meeting', title: 'Client meeting',
        categoryId: 1, dateKey: '2026-11-10', order: 0, isDone: false,
        startTime: DateTime(2026, 11, 10, 13, 30),
        endDateTime: DateTime(2026, 11, 10, 14, 0),
        tags: const [Tag(tagId: 7, name: 'meeting')],
      );
      final shifted = meeting.copyWith(
        startTime: DateTime(2026, 11, 10, 14, 0),
        endDateTime: DateTime(2026, 11, 10, 14, 30));
      final resized = meeting.copyWith(
        endDateTime: DateTime(2026, 11, 10, 14, 10));
      expect(firstAutomaticallyChangedFixedPlan(
        before: [meeting], after: [shifted]), same(meeting));
      expect(firstAutomaticallyChangedFixedPlan(
        before: [meeting], after: [resized]), same(meeting));
      expect(firstAutomaticallyChangedFixedPlan(
        before: [meeting], after: [meeting]), isNull);
      expect(firstAutomaticallyChangedFixedPlan(
        before: [meeting], after: [shifted],
        explicitlyEditedPlanIds: {'meeting'}), isNull);
    });

    test('chain preserves protected end even when tag duration differs', () {
      final meeting = PlanningTask(
        id: 11, planRowId: 'meeting', title: 'Fixed 13:30',
        categoryId: 1, dateKey: '2026-11-10', order: 0, isDone: false,
        startTime: DateTime(2026, 11, 10, 13, 30),
        endDateTime: DateTime(2026, 11, 10, 14, 0),
        tags: const [Tag(tagId: 7, name: 'meeting')],
      );
      final result = cascadeTimeViewAffectedChain(
        orderedTasks: [meeting], draggedPlanIds: const {},
        fixedPlanIds: const {},
        durationMinutes: (_) => 90);
      expect(result, isNotNull);
      expect(result!.single.startTime, meeting.startTime);
      expect(result.single.endDateTime, meeting.endDateTime);
    });

    test('plan without fixed tag is flexible', () {
      final task = PlanningTask(
        id: 1,
        title: 'Work',
        dateKey: '2026-06-15',
        order: 0,
        isDone: false,
        categoryId: 1,
        tags: const [Tag(tagId: 2, name: 'Work', pbRecordId: 'other12345678901')],
      );
      expect(isPlanFixedInTimeView(task, {'abc123456789012'}), isFalse);
    });
  });
}
