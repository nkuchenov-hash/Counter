import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy daily routine service can never create plans', () {
    final source = File(
      'lib/data/plans/daily_routine_service.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> ensureDailyRoutineV6() async {}'));
    expect(source, isNot(contains('addPlanningTask(')));
    expect(source, isNot(contains('FREQ=DAILY')));
    expect(source, isNot(contains('Утренние процедуры')));
    expect(source, isNot(contains('Завтрак')));
    expect(source, isNot(contains('Зарядка')));
    expect(source, isNot(contains('Обед')));
    expect(source, isNot(contains('Ужин')));
    expect(source, isNot(contains('Подготовка ко сну')));
  });

  test('ordinary Planning startup never seeds user plans', () {
    final lifecycle = File(
      'lib/app/shell/shared/shell_lifecycle.dart',
    ).readAsStringSync();
    final startup = File(
      'lib/data/plans/planner_startup_service.dart',
    ).readAsStringSync();

    expect(
      lifecycle,
      contains('await PlannerStartupService.instance.ensureBaseline();'),
    );
    expect(startup, contains('refreshCategoryRulesFromServer'));
    expect(startup, isNot(contains('daily_routine_service.dart')));
    expect(startup, isNot(contains('ensureDailyRoutineV6')));
    expect(startup, isNot(contains('addPlanningTask(')));
  });

  test('backend removes and permanently blocks legacy seeded routines', () {
    final hook = File(
      'pb_hooks/plans.forbid_legacy_daily_routine.pb.js',
    ).readAsStringSync();
    final migration = File(
      'pb_migrations/1787829600_remove_legacy_daily_routines.js',
    ).readAsStringSync();

    for (final source in [hook, migration]) {
      expect(source, contains('LIFEOS_DAILY_ROUTINE_V1|'));
      expect(source, contains('lifeos-routine-v1-'));
    }
    expect(hook, contains('onRecordCreate('));
    expect(hook, contains('onRecordUpdate('));
    expect(hook, contains('BadRequestError'));
    expect(migration, contains('app.delete(row)'));
  });
}
