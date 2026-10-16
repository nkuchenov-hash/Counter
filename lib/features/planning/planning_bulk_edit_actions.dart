// Planning bulk-edit logic, separate from the oversized page widget.
part of 'planning_page.dart';

extension PlanningBulkEditActions on _PlanningPageState {
  Future<void> _openBulkPlanningEditImpl(List<PlanningTask> tasks) async {
    if (_selectedPlanKeys.isEmpty) return;
    final loc = currentLocale.value;
    final initial = widget.selectedDate ?? _PlanningPageState._today;

    // Use the visible source order, never the order in which checkboxes were
    // clicked (which is how the Set of keys is ordered).
    final selected = tasks
        .where((t) => _selectedPlanKeys.contains(_planKey(t)))
        .where((t) {
          final pbId = t.pocketRecordId?.trim() ?? '';
          return pbId.isNotEmpty &&
              !t.planRowIdForBackend.startsWith('optimistic-') &&
              !t.planRowIdForBackend.startsWith('virt-');
        })
        .toList(growable: false);
    if (selected.isEmpty) return;
    final result = await showBulkPlanningEditSheet(
      context,
      initialDay: initial,
      selectedTasks: selected,
    );
    if (result == null || !mounted) return;
    final refDay = widget.selectedDate ?? _PlanningPageState._today;
    final sameDay = result.targetDate.year == refDay.year &&
        result.targetDate.month == refDay.month &&
        result.targetDate.day == refDay.day;
    if (sameDay && !result.applyTargetTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(loc, 'plan_bulk_edit_no_changes'))),
      );
      return;
    }

    final db = DatabaseService.instance;
    final placements = computeSequentialBulkEditWallTimes(
      selected,
      result,
      durationMinutesForTask: (task) =>
          db.resolvePlanDurationMinutesFromTags(task.tags),
    );
    // The source block has priority from the user-selected clock time.
    // Cascade only destination-day incumbents it would otherwise overlap.
    final destinationMoves =
        <({PlanningTask task, BulkEditWallTimes times})>[];
    if (result.applyTargetTime && placements.isNotEmpty) {
      final movingKeys =
          selected.map((t) => t.planRowIdForBackend).toSet();
      final incumbents = db
          .planningDayTasksSnapshot(result.targetDate)
          .where((t) => !movingKeys.contains(t.planRowIdForBackend))
          .toList(growable: false);
      final shifts = computeBulkDestinationConflictShifts(
        blockStart: placements.first.start,
        blockEnd: placements.last.end!,
        existingDestinationPlans: incumbents,
        durationMinutesForTask: (task) =>
            db.resolvePlanDurationMinutesFromTags(task.tags),
      );
      // A recurring virtual instance or still-unsaved optimistic plan cannot
      // be reliably PATCHed. Abort before changing *any* plans.
      if (shifts.any((shift) =>
          shift.task.planRowIdForBackend.startsWith('virt-') ||
          shift.task.planRowIdForBackend.startsWith('optimistic-') ||
          (shift.task.pocketRecordId?.trim().isEmpty ?? true))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(loc, 'plan_save_failed'))),
        );
        return;
      }
      destinationMoves.addAll(shifts);
    }

    final patches = <PlanningBulkPatch>[];
    void stage(PlanningTask task, BulkEditWallTimes wall) {
      final d = DateTime(wall.start.year, wall.start.month, wall.start.day);
      final newKey = _dateKeyFromDate(d);
      final anchor = db.planningAuditAnchorDateKey(task);
      final initForPatch = anchor.length >= 10
          ? anchor
          : db.planningWallScheduleDateKey(task);
      final initialKey = initForPatch.length >= 10 ? initForPatch : newKey;
      final postponed = !task.isDone && db.planningShouldMarkPostponed(
        anchorKey: initialKey,
        newScheduleKey: newKey,
      );
      final endKey = wall.end != null
          ? _dateKeyFromDate(wall.end!)
          : null;
      db.applyOptimisticPlanningTask(task.copyWith(
        dateKey: newKey,
        date: DateTime.utc(d.year, d.month, d.day),
        startTime: wall.start,
        endDateTime: wall.end,
        endDateKey: endKey,
        clearEnd: wall.end == null,
        initialDateKey: initialKey,
        isPostponed: postponed,
      ));
      patches.add(PlanningBulkPatch(
        planRowId: task.planRowIdForBackend,
        planBusinessId: task.planRowId,
        startTimeDisplay: wall.start,
        endDateTimeDisplay: wall.end,
        clearEnd: wall.end == null,
        initialDateKey: initialKey,
        isPostponed: postponed,
      ));
    }

    // Apply the complete coherent block before persistence. Single refresh,
    // not a per-row cascade that can reshuffle equal timestamps.
    for (var i = 0; i < selected.length; i++) {
      stage(selected[i], placements[i]);
    }
    for (final move in destinationMoves) {
      stage(move.task, move.times);
    }
    if (patches.isEmpty) return;
    db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
    if (mounted) setState(() {});
    final ok = await db.bulkUpdatePlans(patches, suppressAppSnack: true);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _selectedPlanKeys.clear();
        _planSelectMode = false;
      });
      _syncPlanningShellFabBulkReserve();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        ok ? t(loc, 'plan_bulk_edit_success') : t(loc, 'plan_save_failed'),
      )),
    );
  }
}
