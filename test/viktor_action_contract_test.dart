import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:flutter_test/flutter_test.dart';

const planA = 'aaaaabbbbbccccc';
const planB = 'dddddeeeeefffff';
const recordA = 'qqqqqrrrrrsssss';

Map<String, dynamic> action(String name, Map<String, Object?> args) =>
    {'name': name, 'arguments': args};

Map<String, dynamic> batch(List<Map<String, dynamic>> actions) => {
      'version': 1,
      'request_id': 'req_20261017_01',
      'actions': actions,
    };

void main() {
  group('Viktor action proposals', () {
    test('accepts safe two-step plan edit but mandates preview', () {
      final proposal = ViktorActionBatch.fromJson(batch([
        action('update_plan_duration', {
          'plan_id': planA,
          'expected_duration_minutes': 40,
          'duration_minutes': 30,
        }),
        action('move_plan_after', {
          'plan_id': planB,
          'after_plan_id': planA,
          'wall_day': '2026-10-17',
        }),
      ]));
      expect(proposal.hasMutations, true);
      expect(proposal.requiresPreview, true);
      expect(proposal.actions.map((e) => e.name),
          ['update_plan_duration', 'move_plan_after']);
      expect(ViktorActionBatch.fromJson(
        Map<String, dynamic>.from(proposal.toJson()),
      ).actions.length, 2);
    });

    test('single existing plan duration edit does not force preview', () {
      final result = ViktorActionBatch.fromJson(batch([
        action('update_plan_duration', {
          'plan_id': planA,
          'expected_duration_minutes': 40,
          'duration_minutes': 30,
        }),
      ]));
      expect(result.requiresPreview, false);
    });

    test('creates an unscheduled-position day plan', () {
      final result = ViktorActionBatch.fromJson(batch([
        action('create_plan', {
          'title': 'Прогулка с бабушкой',
          'wall_day': '2026-10-17',
          'duration_minutes': 60,
          'start_time': '09:00',
        }),
      ]));
      expect(result.actions.single.name, 'create_plan');
    });

    test('accepts read-only day request', () {
      final result = ViktorActionBatch.fromJson(batch([
        action('list_day_plans', {'wall_day': '2026-10-17'}),
      ]));
      expect(result.hasMutations, false);
      expect(result.requiresPreview, false);
    });

    test('accepts start and stop as distinct supported tools', () {
      expect(
        ViktorActionBatch.fromJson(batch([
          action('start_record', {'title': 'RCC'}),
        ])).actions.single.name,
        'start_record',
      );
      expect(
        ViktorActionBatch.fromJson(batch([
          action('stop_record', {'record_id': recordA}),
        ])).actions.single.name,
        'stop_record',
      );
    });

    test('rejects arbitrary code and network tools', () {
      expect(
        () => ViktorActionBatch.fromJson(batch([
          action('eval_code', {'code': 'delete everything'}),
        ])),
        throwsFormatException,
      );
    });

    test('unknown field reports actionable allowed schema, not field values', () {
      try {
        ViktorActionBatch.fromJson(batch([
          action('create_plan', {
            'title': 'RCC Meeting',
            'wall_day': '2026-10-24',
            'start_time': '20:00',
            'duration_minutes': 30,
            'category_name': 'Private notes data',
          }),
        ]));
        fail('Unknown argument must not pass the typed contract');
      } on FormatException catch (error) {
        final detail = error.message.toString();
        expect(detail, contains('Action 1'));
        expect(detail, contains('Tool create_plan'));
        expect(detail, contains('category_name'));
        expect(detail, contains('Allowed fields'));
        expect(detail, contains('duration_minutes'));
        expect(detail, isNot(contains('Private notes data')),
            reason: 'Repair feedback cannot reveal argument values');
      }
    });

    test('rejects wrong action wrapper with exact safe repair guidance', () {
      try {
        ViktorActionBatch.fromJson(batch([
          {
            'name': 'create_plan',
            'arguments': {
              'title': 'Meeting',
              'wall_day': '2026-10-24',
              'start_time': '20:00',
              'duration_minutes': 30,
            },
            'date': '2026-10-24',
          }
        ]));
        fail('No action wrapper fields may bypass validation');
      } on FormatException catch (error) {
        final detail = error.message.toString();
        expect(detail, contains('Action 1'));
        expect(detail, contains('date'));
        expect(detail, contains('arguments'));
        expect(detail, contains('name'));
      }
    });

    test('rejects unknown fields, including embedded credentials', () {
      expect(
        () => ViktorActionBatch.fromJson(batch([
          action('start_record', {'title': 'RCC', 'api_key': 'SECRET'}),
        ])),
        throwsFormatException,
      );
      expect(
        () => ViktorActionBatch.fromJson({
          ...batch([action('start_record', {'title': 'RCC'})]),
          'execute_immediately': true,
        }),
        throwsFormatException,
      );
    });

    test('rejects unsafe or virtual row ids', () {
      for (final id in ['virt-foo', '123', '../../other', '']) {
        expect(
          () => ViktorActionBatch.fromJson(batch([
            action('stop_record', {'record_id': id}),
          ])),
          throwsFormatException,
        );
      }
    });

    test('rejects invalid dates and clock values', () {
      for (final day in ['2026-02-30', '2026-13-01', 'today']) {
        expect(
          () => ViktorActionBatch.fromJson(batch([
            action('list_day_plans', {'wall_day': day}),
          ])),
          throwsFormatException,
        );
      }
      expect(
        () => ViktorActionBatch.fromJson(batch([
          action('create_plan', {
            'title': 'Breakfast',
            'wall_day': '2026-10-17',
            'duration_minutes': 30,
            'start_time': '25:10',
          }),
        ])),
        throwsFormatException,
      );
    });

    test('rejects conflicting explicit and relative start times', () {
      expect(
        () => ViktorActionBatch.fromJson(batch([
          action('create_plan', {
            'title': 'Breakfast',
            'wall_day': '2026-10-17',
            'duration_minutes': 30,
            'start_time': '09:40',
            'after_plan_id': planA,
          }),
        ])),
        throwsFormatException,
      );
    });

    test('swaps two distinct saved plans with same-day scope', () {
      final result = ViktorActionBatch.fromJson(batch([
        action('swap_plan_positions', {
          'first_plan_id': planA,
          'second_plan_id': planB,
          'wall_day': '2026-10-17',
        }),
      ]));
      expect(result.actions.single.name, 'swap_plan_positions');
      expect(result.requiresPreview, false);
      expect(() => ViktorActionBatch.fromJson(batch([
        action('swap_plan_positions', {
          'first_plan_id': planA,
          'second_plan_id': planA,
          'wall_day': '2026-10-17',
        }),
      ])), throwsFormatException);
    });

    test('rejects self-referential plan moves', () {
      expect(
        () => ViktorActionBatch.fromJson(batch([
          action('move_plan_after', {
            'plan_id': planA,
            'after_plan_id': planA,
            'wall_day': '2026-10-17',
          }),
        ])),
        throwsFormatException,
      );
    });

    test('rejects impossible or fractional durations', () {
      for (final minutes in [0, 9, 1441, 30.5, '30']) {
        expect(
          () => ViktorActionBatch.fromJson(batch([
            action('update_plan_duration', {
              'plan_id': planA,
              'expected_duration_minutes': 40,
              'duration_minutes': minutes,
            }),
          ])),
          throwsFormatException,
        );
      }
    });


    test('normalizes explicit bulk completion synonyms, still rejects unknown', () {
      for (final alias in ['completed', 'done', 'finished', 'выполненные']) {
        final parsed = ViktorAction.fromJson(action('bulk_replan', {
          'operations': [
            {'kind': 'compact', 'status': alias, 'source_day': '2026-10-21'}
          ],
        }));
        final ops = parsed.arguments['operations'] as List;
        expect((ops.single as Map)['status'], 'complete');
      }
      for (final alias in ['not_done', 'not_completed', 'unfinished',
                           'undone', 'невыполненные']) {
        final parsed = ViktorAction.fromJson(action('bulk_replan', {
          'operations': [
            {'kind': 'move', 'status': alias,
             'source_day': '2026-10-21', 'target_day': '2026-10-22',
             'start_time': '09:00', 'timezone': 'New York'}
          ],
        }));
        final ops = parsed.arguments['operations'] as List;
        expect((ops.single as Map)['status'], 'incomplete');
      }
      for (final ambiguous in ['pending', 'active', 'unverified', '']) {
        expect(() => ViktorAction.fromJson(action('bulk_replan', {
          'operations': [
            {'kind': 'compact', 'status': ambiguous, 'source_day': '2026-10-21'}
          ],
        })), throwsFormatException);
      }
      final combined = ViktorAction.fromJson(action('bulk_replan', {
        'operations': [
          {'kind': 'move', 'status': 'unfinished',
           'source_day': '2026-10-21', 'target_day': '2026-10-22',
           'start_time': '09:00'},
          {'kind': 'compact', 'status': 'completed',
           'source_day': '2026-10-21'},
        ],
      }));
      final ops = combined.arguments['operations'] as List;
      expect((ops.first as Map)['status'], 'incomplete');
      expect((ops.last as Map)['status'], 'complete');
    });


    test('Bulk move accepts unambiguous hour, AM/PM, NY and seconds formats', () {
      for (final example in <(String, String, String?)>[
        ('9:00', '09:00', null),
        ('9', '09:00', null),
        ('09:00:00', '09:00', null),
        ('9 am', '09:00', null),
        ('9 утра', '09:00', null),
        ('9:00 pm', '21:00', null),
        ('12:00 AM', '00:00', null),
        ('09:00 NY', '09:00', 'America/New_York'),
        ('9:00 по Нью-Йорку', '09:00', 'America/New_York'),
      ]) {
        final result = ViktorAction.fromJson(action('bulk_replan', {
          'operations': [
            {
              'kind': 'move', 'status': 'incomplete',
              'source_day': '2026-10-21',
              'target_day': '2026-10-22',
              'start_time': example.$1,
            }
          ]
        }));
        final op = (result.arguments['operations'] as List).single as Map;
        expect(op['start_time'], example.$2);
        if (example.$3 != null) expect(op['timezone'], example.$3);
      }
    });

    test('Bulk move rejects missing, ambiguous and invalid start times', () {
      for (final bad in [
        null, '', 'morning', 'nine', '9-ish', '24:00', '12:70',
        '12:00:17', '12 утра', '09:00 NY then 10',
      ]) {
        expect(() => ViktorAction.fromJson(action('bulk_replan', {
          'operations': [
            {
              'kind': 'move', 'status': 'incomplete',
              'source_day': '2026-10-21',
              'target_day': '2026-10-22',
              if (bad != null) 'start_time': bad,
            }
          ]
        })), throwsFormatException);
      }
      expect(() => ViktorAction.fromJson(action('bulk_replan', {
        'operations': [{
          'kind': 'move', 'status': 'incomplete',
          'source_day': '2026-10-21', 'target_day': '2026-10-22',
          'start_time': '09:00 NY', 'timezone': 'Europe/Moscow',
        }]
      })), throwsFormatException);
    });

    test('One bulk move absorbs only redundant source/target day reads', () {
      final normalized = ViktorActionBatch.fromJson(batch([
        action('list_day_plans', {'wall_day': '2026-10-21'}),
        action('bulk_replan', {
          'operations': [{
            'kind': 'move', 'status': 'incomplete',
            'source_day': '2026-10-21',
            'target_day': '2026-10-22',
            'start_time': '9 утра', 'timezone': 'America/New_York',
          }]
        }),
        action('list_day_plans', {'wall_day': '2026-10-22'}),
      ]));
      expect(normalized.actions.length, 1);
      expect(normalized.actions.single.name, 'bulk_replan');
      expect(normalized.requiresPreview, isTrue);
      expect(normalized.isSingleReversibleWrite, isFalse);
      final restored = ViktorActionBatch.fromJson(
        Map<String, dynamic>.from(normalized.toJson()));
      expect(restored.actions.length, 1);
    });

    test('Unrelated reads and multiple mutations never vanish from a batch', () {
      final bulk = action('bulk_replan', {
        'operations': [{
          'kind': 'move', 'status': 'incomplete',
          'source_day': '2026-10-21', 'target_day': '2026-10-22',
          'start_time': '09:00',
        }]
      });
      final unrelated = ViktorActionBatch.fromJson(batch([
        action('list_day_plans', {'wall_day': '2026-10-23'}), bulk,
      ]));
      expect(unrelated.actions.length, 2);
      final extraWrite = ViktorActionBatch.fromJson(batch([
        bulk, action('create_plan', {
          'title': 'Unexpected', 'wall_day': '2026-10-22',
          'duration_minutes': 30, 'start_time': '15:00',
        }),
      ]));
      expect(extraWrite.actions.length, 2);
      final multipleBulk = ViktorActionBatch.fromJson(batch([bulk, bulk]));
      expect(multipleBulk.actions.length, 2);
    });

    test('rejects oversized, empty and unsupported batches', () {
      expect(() => ViktorActionBatch.fromJson(batch([])),
          throwsFormatException);
      expect(
        () => ViktorActionBatch.fromJson(batch(List.generate(
          17,
          (_) => action('list_day_plans', {'wall_day': '2026-10-17'}),
        ))),
        throwsFormatException,
      );
      expect(
        () => ViktorActionBatch.fromJson({
          ...batch([action('list_day_plans', {'wall_day': '2026-10-17'})]),
          'version': 2,
        }),
        throwsFormatException,
      );
    });
  });
}
