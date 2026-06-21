import 'dart:async';
import 'dart:io';

import 'package:counter/core/perf_diag.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_view.dart';
import 'package:counter/features/timeline/timeline_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures [PerfDiag] print output during programmatic date swipes.
final List<String> _perfLogs = [];

void _capturePrint(String line) {
  _perfLogs.add(line);
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 30}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _perfLogs.clear();
    PerfDiag.instance.attachIfNeeded();
  });

  testWidgets('TimelineSwipeWrapper — one-day drag emits perf logs', (
    WidgetTester tester,
  ) async {
    await runZoned(
      () async {
        final titleCtrl = TextEditingController();
        final titleFocus = FocusNode();
        addTearDown(titleCtrl.dispose);
        addTearDown(titleFocus.dispose);

        DateTime? lastDate;
        await tester.pumpWidget(
          MaterialApp(
            home: TimelineSwipeWrapper(
              selectedDate: DateTime(2026, 6, 15),
              shellTabActive: true,
              onDateChanged: (d) => lastDate = d,
              onJumpToConflict: null,
              tasks: const <Task>[],
              tasksLoading: false,
              titleController: titleCtrl,
              titleFocus: titleFocus,
              selectedCategoryId: null,
              onCategoryChanged: (_) {},
              onStart: () async {},
              onPlan: () async {},
              onNewTaskForPastDate: () {},
              onStopRecord: (_) async {},
              onDeleteRecord: (_) async {},
              rules: const <CategoryRule>[],
              onShowEditRecordSheet: (_, __) {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pageView = find.byType(PageView);
        expect(pageView, findsOneWidget);

        await tester.fling(pageView, const Offset(-800, 0), 2500);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // ignore: avoid_print
        print('--- TIMELINE PERF LOGS (${_perfLogs.length}) ---\n${_perfLogs.join('\n')}');

        final logsCopy = List<String>.from(_perfLogs);
        expect(logsCopy.length, greaterThan(3), reason: logsCopy.join('\n'));
        File('timeline_perf_capture.txt').writeAsStringSync(logsCopy.join('\n'));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => _capturePrint(line),
      ),
    );
  });

  testWidgets('PlanningSwipeWrapper — one-day drag emits perf logs', (
    WidgetTester tester,
  ) async {
    await runZoned(
      () async {
        DateTime? lastDate;
        await tester.pumpWidget(
          MaterialApp(
            home: PlanningSwipeWrapper(
              selectedDate: DateTime(2026, 6, 15),
              shellTabActive: true,
              onDateChanged: (d) => lastDate = d,
              selectedCategoryId: null,
              onCategoryChanged: (_) {},
              onStartRecordFromTask:
                  (_, __, ___, {String? sourcePlanPocketRecordId}) async {},
              onEditTask: (_) {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pageView = find.byType(PageView);
        expect(pageView, findsOneWidget);

        await tester.fling(pageView, const Offset(-800, 0), 2500);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final logsCopy = List<String>.from(_perfLogs);
        File('planning_perf_capture.txt').writeAsStringSync(logsCopy.join('\n'));
        expect(
          logsCopy.any((l) => l.contains('DATE_SWIPE_START section=Planning')) ||
              logsCopy.any((l) => l.contains('DATE_SWIPE_DRAG section=Planning')),
          isTrue,
          reason: logsCopy.join('\n'),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => _capturePrint(line),
      ),
    );
  });
}
