import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';

void main() {
  final source = File('lib/data/db_core.dart').readAsStringSync();

  test('cold start arms live sync without waiting for a user gesture', () {
    final ready = source.indexOf('unawaited(refreshForegroundData());');
    final deferred = source.indexOf(
      "StartupLog.scheduleAfterFirstFrame(\n      'deferredBootWork'",
    );
    expect(ready, greaterThanOrEqualTo(0));
    expect(deferred, greaterThan(ready));
  });

  test('temporary startup backoff schedules one automatic retry', () {
    expect(source, contains('_scheduleAppOpenSyncRetry();'));
    expect(source, contains('delay + const Duration(milliseconds: 250)'));
  });

  test('app-open sync is push-first and contains no periodic polling', () {
    final body = source.substring(
      source.indexOf('Future<void> _refreshForegroundDataBody()'),
    );
    final subscribe = body.indexOf('await Future.wait<void>');
    final outbox = body.indexOf('await offlineSync.bootstrapFromOutboxes');
    expect(subscribe, greaterThanOrEqualTo(0));
    expect(outbox, greaterThan(subscribe));
    expect(source, isNot(contains('Timer.periodic')));
  });

  testWidgets('quick entry supports mouse Start and keyboard Enter', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var submitted = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppQuickEntryRow(
              controller: controller,
              focusNode: focus,
              hintText: 'Record title',
              actionLabel: 'Start',
              actionIcon: Icons.play_arrow,
              onAction: () => submitted++,
              onSubmitted: (_) => submitted++,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'first record');
    await tester.tap(find.text('Start'));
    expect(submitted, 1);
    expect(controller.text, 'first record');

    await tester.tap(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, 2);
  });

  testWidgets('busy Start is disabled but input remains editable', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var submitted = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppQuickEntryRow(
            controller: controller,
            focusNode: focus,
            hintText: 'Record title',
            actionLabel: 'Start',
            actionIcon: Icons.play_arrow,
            loading: true,
            onAction: () => submitted++,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'draft while saving');
    expect(controller.text, 'draft while saving');
    expect(submitted, 0);
  });

  test('Timeline attaches quick-entry FocusNode only on active page', () {
    final header = File(
      'lib/features/timeline/timeline_header_controls.dart',
    ).readAsStringSync();
    expect(
      header,
      contains('if (!showStatsView && isActivePage && shellTabActive)'),
    );
    expect(header, contains('valueListenable: quickEntryStartPending'));
  });

  test('Start reaches durable Brain staging without waiting for draft backup', () {
    final shell = File(
      'lib/app/shell/shared/shell_task_actions.dart',
    ).readAsStringSync();
    final start = shell.indexOf('Future<void> startTaskFromInput() async');
    final end = shell.indexOf('Future<void> planTaskFromInput() async', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final handler = shell.substring(start, end);
    expect(handler, contains('quickEntryStartPending.value = true'));
    expect(handler, contains('unawaited(persistQuickEntryDraft(title))'));
    expect(handler, isNot(contains('await persistQuickEntryDraft(title)')));
    expect(handler, contains('stableCreateBusinessId: attemptId'));
    expect(handler, contains('if (mounted) quickEntryStartPending.value = false'));
  });

  test('unapplied record and plan SSE events recover via authoritative pull', () {
    final realtime = File(
      'lib/data/records/record_realtime.dart',
    ).readAsStringSync();
    final plans = File('lib/data/plan_service.dart').readAsStringSync();
    expect(realtime, contains('void _reconcileUnappliedRealtimeEvent()'));
    expect(realtime, contains('_scheduleRealtimeGapCatchUp()'));
    expect(realtime, contains('_realtimeRecoverySubscribeRetryTimer'));
    expect(plans, contains('_reconcileUnappliedRealtimeEvent();'));
  });

}
