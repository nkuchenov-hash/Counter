import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily routine uses one deterministic recurring series per anchor', () {
    final source = File(
      'lib/data/plans/daily_routine_service.dart',
    ).readAsStringSync();

    expect(source, contains('_dailyRoutineMarkerV6'));
    expect(source, contains('_routineSeriesPlanIdV7'));
    expect(source, contains('FREQ=DAILY'));
    expect(source, contains('clientPlanId: deterministicPlanId'));
  });

  test(
    'path actions use unique deterministic plan ids and migration cleanup stays isolated',
    () {
      final source = File(
        'lib/data/paths/compatibility/path_governance_service.dart',
      ).readAsStringSync();

      expect(source, contains('_pathActionBusinessIdV7'));
      expect(source, contains('clientPlanId: planBusinessId'));
      expect(source, contains('_migrateLegacyApprovalDuplicatesV7'));
      expect(source, contains('_plannerBaselineMigrationV7'));
    },
  );

  test(
    'ordinary shell startup delegates Planning baseline without scheduling project actions',
    () {
      final lifecycle = File(
        'lib/app/shell/shared/shell_lifecycle.dart',
      ).readAsStringSync();
      final shell = File('lib/app/shell/app_shell.dart').readAsStringSync();
      final startup = File(
        'lib/data/plans/planner_startup_service.dart',
      ).readAsStringSync();
      final governance = File(
        'lib/data/paths/compatibility/path_governance_service.dart',
      ).readAsStringSync();

      expect(shell, contains('initializeShellLifecycle();'));
      expect(
        shell,
        contains("package:counter/data/plans/planner_startup_service.dart"),
      );
      expect(
        shell,
        isNot(
          contains(
            "package:counter/data/paths/compatibility/path_governance_service.dart",
          ),
        ),
      );
      expect(
        lifecycle,
        contains('await PlannerStartupService.instance.ensureBaseline();'),
      );
      expect(lifecycle, isNot(contains('planCurrentWeekFromPathsV4')));

      expect(startup, contains('await ensureDailyRoutineV6();'));
      expect(startup, contains('await runLegacyPathPlannerCleanupV7();'));
      expect(startup, isNot(contains('planCurrentWeekFromPathsV4')));

      expect(
        governance,
        contains('Future<void> runLegacyPathPlannerCleanupV7()'),
      );
      final start = governance.indexOf(
        'Future<void> runLegacyPathPlannerCleanupV7()',
      );
      final body = governance.substring(
        start,
        governance.indexOf('\n}', start) + 2,
      );
      expect(body, contains('_migrateLegacyApprovalDuplicatesV7'));
      expect(body, isNot(contains('planCurrentWeekFromPathsV4')));
    },
  );
}
