import 'dart:async';
import 'dart:io';

import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';
import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_view.dart';
import 'package:counter/features/timeline/timeline_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final List<String> _perfLogs = [];

void _capturePrint(String line) => _perfLogs.add(line);

/// Shell-shaped harness: shared [selectedDate], [IndexedStack], both swipe wrappers.
class _ShellDateHarness extends StatefulWidget {
  const _ShellDateHarness({required this.activeTab});
  final int activeTab;

  @override
  State<_ShellDateHarness> createState() => _ShellDateHarnessState();
}

class _ShellDateHarnessState extends State<_ShellDateHarness> {
  DateTime _selectedDate = DateTime(2026, 6, 15);
  late final TextEditingController _titleCtrl;
  late final FocusNode _titleFocus;
  late final ShellLayoutController _shellLayout;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _titleFocus = FocusNode();
    _shellLayout = ShellLayoutController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    _shellLayout.dispose();
    super.dispose();
  }

  void _onDateChanged(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.year == _selectedDate.year &&
        day.month == _selectedDate.month &&
        day.day == _selectedDate.day) {
      return;
    }
    RebuildMetrics.instance.stateChange(
      source: 'ShellHarness',
      field: 'selectedDate',
      duringSwipe: true,
    );
    setState(() => _selectedDate = day);
  }

  @override
  Widget build(BuildContext context) {
    rebuildMetricsTick('AppShell');
    _shellLayout.applyShellFrame(widget.activeTab);
    final pages = <Widget>[
      TimelineSwipeWrapper(
        selectedDate: _selectedDate,
        shellTabActive: widget.activeTab == 0,
        onDateChanged: _onDateChanged,
        onJumpToConflict: null,
        tasks: const <Task>[],
        tasksLoading: false,
        titleController: _titleCtrl,
        titleFocus: _titleFocus,
        selectedCategoryId: null,
        onCategoryChanged: (_) {},
        onStart: () async {},
        onPlan: () async {},
        onNewTaskForPastDate: () {},
        onStopRecord: (_) async {},
        onDeleteRecord: (_) async {},
        rules: const <CategoryRule>[],
        onShowEditRecordSheet: (_, _) {},
      ),
      PlanningSwipeWrapper(
        selectedDate: _selectedDate,
        shellTabActive: widget.activeTab == 1,
        onDateChanged: _onDateChanged,
        selectedCategoryId: null,
        onCategoryChanged: (_) {},
        onStartRecordFromTask:
            (_, _, _, {String? sourcePlanPocketRecordId}) async {},
        onEditTask: (_) {},
      ),
    ];
    return ShellLayoutScope(
      controller: _shellLayout,
      child: IndexedStack(index: widget.activeTab, children: pages),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Shell harness — Timeline tab swipe rebuild fan-out', (
    WidgetTester tester,
  ) async {
    await runZoned(
      () async {
        _perfLogs.clear();
        RebuildMetrics.instance.attachIfNeeded();
        await tester.pumpWidget(
          const MaterialApp(home: _ShellDateHarness(activeTab: 0)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.fling(
          find.byType(PageView).first,
          const Offset(-800, 0),
          2500,
        );
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }

        final logs = List<String>.from(_perfLogs);
        File(
          'shell_timeline_swipe_capture.txt',
        ).writeAsStringSync(logs.join('\n'));
        if (kRebuildMetricsEnabled) {
          expect(
            logs.any((l) => l.contains('PERF_REBUILD_SUMMARY')),
            isTrue,
            reason: logs.join('\n'),
          );
          expect(
            logs.any(
              (l) =>
                  l.contains(
                    'DATE_SWIPE_PAGER section=Planning op=jumpToPage',
                  ) &&
                  l.contains('hidden=true'),
            ),
            isFalse,
            reason: 'Hidden Planning must not jumpToPage: ${logs.join('\n')}',
          );
          expect(
            logs.any(
              (l) => l.contains(
                'DATE_SWIPE_PAGER section=Planning op=deferHidden',
              ),
            ),
            isTrue,
            reason: logs.join('\n'),
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => _capturePrint(line),
      ),
    );
  });
}
