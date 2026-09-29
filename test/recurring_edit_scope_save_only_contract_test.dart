import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recurring edit scope is requested only from explicit Save', () {
    final source = File(
      'lib/features/shared/planning_task_edit_sheet.dart',
    ).readAsStringSync();

    final fieldStart = source.indexOf(
      'void _onPlanFieldChanged({bool immediate = false})',
    );
    final fieldEnd = source.indexOf(
      'bool _planDraftsSemanticallyEqual',
      fieldStart,
    );
    expect(fieldStart, greaterThanOrEqualTo(0));
    expect(fieldEnd, greaterThan(fieldStart));
    final fieldBlock = source.substring(fieldStart, fieldEnd);

    expect(fieldBlock, contains('if (_baselineIsRecurring)'));
    expect(fieldBlock, contains('_planAutosaveGate.markDirty();'));
    expect(fieldBlock, isNot(contains('_recurrenceScopeGate.resolve(')));

    final saveStart = source.indexOf('Future<void> _commitSaveAsync() async');
    final saveEnd = source.indexOf('PlanningTask? _buildDraftTask()', saveStart);
    expect(saveStart, greaterThanOrEqualTo(0));
    expect(saveEnd, greaterThan(saveStart));
    final saveBlock = source.substring(saveStart, saveEnd);

    expect(
      saveBlock,
      contains('final scope = await _recurrenceScopeGate.resolve('),
    );
  });
}
