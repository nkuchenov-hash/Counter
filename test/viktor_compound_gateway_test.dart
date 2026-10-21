import 'package:counter/data/ai/viktor_gateway.dart';
import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final oldActions = <dynamic>[
    {'name': 'bulk_replan', 'arguments': {
      'operations': [{
        'kind': 'move', 'status': 'incomplete',
        'source_day': '2026-10-20',
        'target_day': '2026-10-21',
        'start_time': '09:00', 'timezone': 'New York',
      }],
    }},
    {'name': 'create_plan', 'arguments': {
      'title': 'Price Reporter Case Study', 'wall_day': '2026-10-21',
      'duration_minutes': 60, 'start_time': '11:00',
    }},
    {'name': 'create_plan', 'arguments': {
      'title': 'MISSION IT Authorized Negotiator',
      'wall_day': '2026-10-21', 'duration_minutes': 30,
      'start_time': '13:00',
    }},
    {'name': 'create_plan', 'arguments': {
      'title': 'LAREDO TS Weekly Call',
      'wall_day': '2026-10-21', 'duration_minutes': 30,
      'start_time': '15:00',
    }},
  ];

  test('normalizes YandexGPT legacy mixed response to ONE proposal', () {
    final actions = normalizeViktorCompoundActions(
      actions: oldActions,
      input: 'Перенеси все невыполненные планы Price Reporter со вчерашнего дня '
        'на сегодня начиная с 9:00 NY, при этом срочные ставь первыми. '
        'И поставь встречи сегодня с 11 до 12, с 13 till 13:30 и 15:00–15:30.',
      previousDay: '2026-10-20',
      targetDay: '2026-10-21',
      knownFilters: const ['Price Reporter', 'Work'],
    );
    expect(actions.length, 1);
    final batch = ViktorActionBatch.fromJson({
      'version': 1,
      'request_id': 'req_compose_day_test',
      'actions': actions,
    });
    final one = batch.actions.single;
    expect(one.name, 'compose_day');
    expect(one.arguments['source_filter'], 'Price Reporter');
    expect(one.arguments['urgent_first'], true);
    expect((one.arguments['meetings'] as List).length, 3);
  });

  test('preserves old actions if destination or day does not match', () {
    final result = normalizeViktorCompoundActions(
      actions: oldActions,
      input: 'Сдвинь другие планы',
      previousDay: '2026-10-19',
      targetDay: '2026-10-21',
      knownFilters: const ['Price Reporter'],
    );
    expect(result.length, 4);
  });

  test('does not invent category if no source group is identifiable', () {
    final result = normalizeViktorCompoundActions(
      actions: oldActions,
      input: 'Перенеси задачи вчера и поставь встречи',
      previousDay: '2026-10-20',
      targetDay: '2026-10-21',
      knownFilters: const [],
    );
    expect(result.length, 4);
  });
}
