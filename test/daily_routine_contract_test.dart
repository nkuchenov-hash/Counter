import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily routine bootstrap defines six daily recurring anchors', () {
    final source = File(
      'lib/app/shell/shared/shell_daily_routine.dart',
    ).readAsStringSync();

    for (final title in <String>[
      'Утренние процедуры',
      'Завтрак',
      'Зарядка',
      'Обед',
      'Ужин',
      'Подготовка ко сну',
    ]) {
      expect(source, contains("title: '$title'"));
    }
    expect(RegExp(r"rrule: 'FREQ=DAILY'").allMatches(source).length, 1);
    expect(source, contains("planRrule: 'FREQ=DAILY'"));
    expect(source, contains('dateKey: dateKey'));
    expect(source, contains('startTime: start'));
    expect(source, contains('endDateTime: end'));
    expect(source, contains('initialDateKey: dateKey'));
    expect(source, isNot(contains('backendId = businessId')));
    expect(source, contains('recurringTitles.contains'));
  });

  test('weekly planner canonicalizes roots and de-duplicates approvals', () {
    final source = File(
      'lib/app/shell/shared/shell_path_governance.dart',
    ).readAsStringSync();

    expect(source, contains('_canonicalActivePathRootsV6'));
    expect(source, contains('_dedupeCurrentWeekApprovalPlansV6'));
    expect(source, contains('_projectPlanApprovalStageIdV5'));
    expect(source, contains('_projectPlanApprovalActionIdV5'));
    expect(source, contains('existingApprovalCategoryIds'));
    expect(source, contains('repairPlannerBaselineV7'));
    expect(source, contains("endsWith('согласоватьпланпроекта')"));
  });

  test('ordinary shell startup runs the planner baseline repair', () {
    final source = File('lib/app/shell/app_shell.dart').readAsStringSync();
    expect(source, contains('await repairPlannerBaselineV7();'));
  });
}
