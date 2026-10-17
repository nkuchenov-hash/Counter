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
