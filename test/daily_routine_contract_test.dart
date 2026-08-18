import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily routine uses one deterministic recurring series per anchor', () {
    final source = File(
      'lib/data/plans/daily_routine_service.dart',
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
    expect(source, contains("rrule: 'FREQ=DAILY'"));
    expect(source, contains("planRrule: 'FREQ=DAILY'"));
    expect(source, contains('clientPlanId: deterministicPlanId'));
    expect(source, contains("'lifeos-routine-v1-"));
    expect(source, contains('_dailyRoutineEnsureInFlightV7'));
    expect(source, contains('startTime: start'));
    expect(source, contains('endDateTime: end'));
    expect(source, isNot(contains('backendId = businessId')));
  });

  test(
    'path actions use unique deterministic plan ids and normal scheduling does not clean duplicates',
    () {
      final source = File(
        'lib/data/paths/compatibility/path_governance_service.dart',
      ).readAsStringSync();

      expect(source, contains('_canonicalActivePathRootsV6'));
      expect(source, contains('_pathActionBusinessIdV7'));
      expect(source, contains("'lifeos-path-action-v1-"));
      expect(source, contains('existingBusinessIds.contains(planBusinessId)'));
      expect(source, contains('clientPlanId: planBusinessId'));
      expect(source, contains('_currentWeekApprovalCategoryIdsV7'));
      expect(source, isNot(contains('_dedupeCurrentWeekApprovalPlansV6')));
      expect(source, contains('_migrateLegacyApprovalDuplicatesV7'));
      expect(source, contains('_plannerBaselineMigrationV7'));
    },
  );

  test(
    'ordinary shell startup ensures planner baseline without scheduling project actions',
    () {
      final lifecycle = File(
        'lib/app/shell/shared/shell_lifecycle.dart',
      ).readAsStringSync();
      final shell = File('lib/app/shell/app_shell.dart').readAsStringSync();
      final governance = File(
        'lib/data/paths/compatibility/path_governance_service.dart',
      ).readAsStringSync();

      expect(shell, contains('initializeShellLifecycle();'));
      expect(lifecycle, contains('await ensurePlannerBaselineV7();'));
      expect(lifecycle, isNot(contains('planCurrentWeekFromPathsV4')));
      expect(governance, contains('Future<void> ensurePlannerBaselineV7()'));
      final start = governance.indexOf(
        'Future<void> ensurePlannerBaselineV7()',
      );
      final body = governance.substring(
        start,
        governance.indexOf('\n}', start) + 2,
      );
      expect(body, contains('ensureDailyRoutineV6'));
      expect(body, contains('_migrateLegacyApprovalDuplicatesV7'));
      expect(body, isNot(contains('planCurrentWeekFromPathsV4')));
    },
  );
}
