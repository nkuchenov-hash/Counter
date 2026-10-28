import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_agent_capabilities.dart';
import 'package:counter/data/ai/viktor_record_tools.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> command(String name, Map<String, Object?> args) =>
    {'name': name, 'arguments': args};

ViktorActionBatch propose(List<Map<String, dynamic>> commands) =>
    ViktorActionBatch.fromJson({
      'version': 1,
      'request_id': 'viktor_record_generic_20261028',
      'actions': commands,
    });

void main() {
  test('Record read and record create are reusable, distinct permissions', () {
    final read = propose([command('read_day_records', {
      'wall_day': '2026-10-28',
    })]);
    expect(read.hasMutations, false);
    expect(read.requiresPreview, false);
    expect(ViktorAgentCapabilities.byName['read_day_records']!
        .requiresApproval, false);
    final create = propose([command('create_completed_records', {
      'wall_day': '2026-10-28',
      'records': [
        {'title': 'Зарядка',
          'start_utc': '2026-10-28T06:00:00Z',
          'end_utc': '2026-10-28T06:15:00Z'},
        {'title': 'Утренний кофе',
          'start_utc': '2026-10-28T06:15:00Z',
          'end_utc': '2026-10-28T06:30:00Z'},
      ],
    })]);
    expect(create.hasMutations, true);
    expect(create.requiresPreview, true);
    expect(create.isSingleReversibleWrite, false);
    expect(create.actions.single.arguments['records'], isA<List>());
  });

  test('Missing, ambiguous, or non-UTC times cannot write records', () {
    for (final start in [null, '08:00',
      '2026-10-28T08:00:00+03:00',
      '2026-10-28 08:00:00', 'not a date',
    ]) {
      expect(() => propose([command('create_completed_records', {
        'wall_day': '2026-10-28',
        'records': [{
          'title': 'Зарядка',
          if (start != null) 'start_utc': start,
          'end_utc': '2026-10-28T06:15:00Z',
        }],
      })]), throwsFormatException);
    }
    expect(ViktorRecordTools.parseUtc('2026-10-28T06:00:00Z'),
        DateTime.utc(2026, 10, 28, 6));
    expect(() => ViktorRecordTools.parseUtc('2026-10-28T09:00:00+03:00'),
        throwsFormatException);
  });

  test('Generic CRUD cannot sneak unapproved fields or oversized batches', () {
    for (final invalid in [
      {'title': 'Душ', 'start_utc': '2026-10-28T06:00:00Z'},
      {'title': 'Душ', 'start_utc': '2026-10-28T06:00:00Z',
       'end_utc': '2026-10-28T06:10:00Z', 'category_id': 'random'},
    ]) {
      expect(() => propose([command('create_completed_records', {
        'wall_day': '2026-10-28', 'records': [invalid],
      })]), throwsFormatException);
    }
    expect(() => propose([command('create_completed_records', {
      'wall_day': '2026-10-28',
      'records': List.generate(13, (_) => {
        'title': 'Зарядка', 'start_utc': '2026-10-28T06:00:00Z',
        'end_utc': '2026-10-28T06:15:00Z',
      }),
    })]), throwsFormatException);
  });

  test('One ordinary composed read can accompany other read actions', () {
    expect(propose([
      command('read_day_records', {'wall_day': '2026-10-28'}),
      command('list_day_plans', {'wall_day': '2026-10-28'}),
    ]).hasMutations, false);
  });
}
