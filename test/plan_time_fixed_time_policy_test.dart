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
