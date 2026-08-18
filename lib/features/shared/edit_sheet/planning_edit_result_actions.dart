import 'dart:async';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class PlanningEditResultActions {
  static const String _optimisticPurgeDateKey = '2099-12-31';

  static DateTime? _dateFromKey(String raw) {
    final parts = raw.trim().split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static Future<bool> createNewDraft(
    BuildContext context,
    PlanningTask edited,
  ) async {
    final db = DatabaseService.instance;
    final day = _dateFromKey(edited.dateKey) ?? db.getTimelineDeviceLocalToday();
    final nextOrder = await db.nextPlanningOrderForDate(day);
    final collision = db.resolvePlanningCreateCollision(
      task: edited.copyWith(order: nextOrder),
      wallDay: day,
      existingDayPlans: db
          .planningDayTasksSnapshot(day)
          .where((candidate) => candidate.startTime != null)
          .toList(),
    );
    final toCreate = collision.task;
    final ok = await db.addPlanningTask(toCreate);
    if (!context.mounted) return ok;

    final loc = currentLocale.value;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
      return false;
    }

    if (collision.adjusted && toCreate.startTime != null) {
      final movedTo =
          '${toCreate.startTime!.hour.toString().padLeft(2, '0')}:'
          '${toCreate.startTime!.minute.toString().padLeft(2, '0')}';
      AppSnack.warning(
        t(loc, 'plan_schedule_adjusted').replaceFirst('%s', movedTo),
      );
    }
    HapticFeedback.heavyImpact();
    return true;
  }

  static void deletePersisted(BuildContext context, PlanningTask task) {
    final backup = PlanningTask(
      id: 0,
      title: task.title,
      categoryId: task.categoryId,
      isDone: task.isDone,
      dateKey: task.dateKey,
      order: task.order,
      startTime: task.startTime,
      date: task.date,
      tags: task.tags,
    );
    final db = DatabaseService.instance;
    db.applyOptimisticPlanningTask(
      task.copyWith(dateKey: _optimisticPurgeDateKey),
    );
    db.notifyPlanningRefresh();
    unawaited(_deletePersistedFollowUp(context, task, backup));
  }

  static Future<void> _deletePersistedFollowUp(
    BuildContext context,
    PlanningTask task,
    PlanningTask backup,
  ) async {
    final db = DatabaseService.instance;
    final backendId = task.recordIdForBackend.trim();
    if (backendId.isEmpty) {
      if (!context.mounted) return;
      db.applyOptimisticPlanningTask(task);
      db.notifyPlanningRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
      );
      return;
    }

    final ok = await db.deletePlanningTasksBulk([backendId]);
    if (!context.mounted) return;
    db.clearOptimisticPlanningForPlanRow(task.planRowIdForBackend);
    db.notifyPlanningRefresh();

    final loc = currentLocale.value;
    if (!ok) {
      db.applyOptimisticPlanningTask(task);
      db.notifyPlanningRefresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(loc, 'task_deleted')),
        action: SnackBarAction(
          label: t(loc, 'undo'),
          onPressed: () async {
            await db.addPlanningTask(backup);
          },
        ),
      ),
    );
  }
}
