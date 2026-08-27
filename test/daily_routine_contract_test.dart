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

  test('backend purges and permanently blocks legacy seeded routines', () {
    final hook = File(
      'pb_hooks/zz_google_fit_final_normalize_once.pb.js',
    ).readAsStringSync();

    expect(hook, contains('LIFEOS_DAILY_ROUTINE_V1|'));
    expect(hook, contains('lifeos-routine-v1-'));
    expect(hook, contains('onRecordCreateRequest('));
    expect(hook, contains('onRecordUpdateRequest('));
    expect(hook, contains('BadRequestError'));
    expect(hook, contains('onBootstrap('));
    expect(hook, contains('e.app.delete(rows[i])'));
  });
}
