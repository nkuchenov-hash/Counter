// Scheduled quick add / Smart Plan create: keep DateKey and UTC placement
// aligned when a workday spills into the next available work window.
part of 'planning_page.dart';

extension PlanningQuickAddScheduling on _PlanningPageState {
  String _planWallDateKey(DateTime wall) =>
      '${wall.year}-${wall.month.toString().padLeft(2, '0')}-'
      '${wall.day.toString().padLeft(2, '0')}';

  String _planRolloverLabel(DateTime wall) =>
      '${_planWallDateKey(wall)} ${wall.hour.toString().padLeft(2, '0')}:'
      '${wall.minute.toString().padLeft(2, '0')}';

  void _maybeShowPlanScheduleOverloadWarning({
    required List<PlanningTask> dayPlans,
  }) {
    final report = DatabaseService.instance.evaluatePlanDayScheduleOverload(
      dayPlans: dayPlans,
      timelineStartHour: timeView.timelineHourStart,
      timelineEndHour: timeView.timelineHourEnd,
    );
    if (!report.shouldWarn) return;
    AppSnack.warning(t(currentLocale.value, 'plan_schedule_overload_warning'));
  }

  Future<void> _addTaskImpl() async {
    final taskDateKey = widget.selectedDateString;
    final raw = _textController.text;
    final baseDay = widget.selectedDate ?? _today;
    final wallDay = DateTime(baseDay.year, baseDay.month, baseDay.day);

    final range = SmartInputParser.parseTitleForTimeRange(raw);
    SmartTimeParseResult? parsed;
    final title = SmartInputParser.preservedTitleFromRaw(raw);
    if (title.isEmpty) return;

    if (range == null) {
      parsed = SmartInputParser.parseTitleForScheduledTime(raw);
    }

    final match = DatabaseService.instance.identifyCategory(title);
    final categoryId =
        match?.id ??
        widget.selectedCategoryId ??
        DatabaseService.instance.defaultCategoryId ??
        (DatabaseService.instance.rules.isNotEmpty
            ? DatabaseService.instance.rules.first.id
            : 0);
    final tagsForCreate = List<Tag>.from(_quickAddTags.creationSelectedTags);
    final existingDay = [
      ..._latestPlanningDayTasks,
      ..._optimisticTasks.where(
        (t) => t.dateKey == taskDateKey || t.startTime != null,
      ),
    ];
    final explicitStartWall = range != null
        ? range.startWallOn(wallDay)
        : parsed?.wallDateTimeOn(wallDay);
    final explicitEndWall = range?.endWallOn(wallDay);
    final schedule = DatabaseService.instance.resolveAutoPlanScheduleWithRollover(
      wallDay: wallDay,
      categoryId: categoryId,
      tags: tagsForCreate,
      existingDayPlans: existingDay,
      explicitStartWall: explicitStartWall,
      explicitEndWall: explicitEndWall,
      hasExplicitTimeRange: range != null,
      timelineDayStartHour: timeView.timelineHourStart,
      timelineDayEndHour: timeView.timelineHourEnd,
    );
    if (schedule == null) {
      AppSnack.warning(t(currentLocale.value, 'plan_auto_schedule_no_work_slot'));
      return;
    }
    final plannedWalls = DatabaseService.instance
        .profileDisplayWallsFromAutoSchedule(schedule);
    final scheduledDateKey = _planWallDateKey(plannedWalls.startWall);
    final rolledOver = scheduledDateKey.compareTo(taskDateKey) > 0;
    var nextOrder = _nextPlanOrderForQuickAdd();
    final clientPlanId = DatabaseService.newClientUuid();
    if (_planQuickAddInFlight) return;
    _planQuickAddInFlight = true;
    unawaited(() async {
      try {
        final ok = await DatabaseService.instance.addPlanningTask(
          DatabaseService.instance.planningTaskWithAutoSchedule(
            PlanningTask(
              id: 0,
              title: title,
              categoryId: categoryId,
              isDone: false,
              dateKey: scheduledDateKey,
              initialDateKey: taskDateKey,
              isPostponed: rolledOver,
              order: nextOrder,
              checklist: const [],
              parentPlanId: null,
              tags: tagsForCreate,
              isSynced: false,
            ),
            schedule,
          ),
          clientPlanId: clientPlanId,
        );
        if (!mounted) return;
        if (ok) {
          _textController.clear();
          setState(() {
            _quickAddTags.clearCreationSelectedTags();
          });
          if (rolledOver) {
            AppSnack.show(
              t(currentLocale.value, 'plan_auto_schedule_moved_to')
                  .replaceFirst('%s', _planRolloverLabel(plannedWalls.startWall)),
            );
          } else {
            _maybeShowPlanScheduleOverloadWarning(
              dayPlans: [
                ...existingDay,
                PlanningTask(
                  id: 0,
                  title: title,
                  categoryId: categoryId,
                  isDone: false,
                  dateKey: scheduledDateKey,
                  order: nextOrder,
                  startTime: plannedWalls.startWall,
                  endDateTime: plannedWalls.endWall,
                  tags: tagsForCreate,
                ),
              ],
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PLAN_ADD_UI: $e');
        }
      } finally {
        _planQuickAddInFlight = false;
      }
    }());
  }

  /// Smart Plan: append AI-parsed tasks sequentially on [widget.selectedDateString].
  Future<int> _injectSmartPlanTasksImpl(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return 0;
    final taskDateKey = widget.selectedDateString;
    final baseDay = widget.selectedDate ?? _today;
    final wallDay = DateTime(baseDay.year, baseDay.month, baseDay.day);

    var nextOrder = _nextPlanOrderForQuickAdd();
    var cursorPlans = [
      ..._latestPlanningDayTasks,
      ..._optimisticTasks.where(
        (t) => t.dateKey == taskDateKey || t.startTime != null,
      ),
    ];

    var created = 0;
    PlanningTask? lastCreated;
    DateTime? lastRolledTo;
    for (var i = 0; i < items.length; i++) {
      final m = items[i];
      final title = (m['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final durRaw = m['durationMinutes'];
      int? explicitDuration;
      if (durRaw != null) {
        explicitDuration = durRaw is int
            ? durRaw
            : (durRaw is num ? durRaw.round() : int.tryParse('$durRaw'));
        if (explicitDuration != null && explicitDuration < 1) {
          explicitDuration = null;
        }
      }

      final aiCategoryStr = m['category']?.toString().trim();
      final fromAiId = DatabaseService.instance
          .resolveCategoryIdFromSmartPlanLabel(aiCategoryStr);
      final fromTitle = DatabaseService.instance.identifyCategory(title);
      final categoryId =
          fromAiId ??
          fromTitle?.id ??
          widget.selectedCategoryId ??
          DatabaseService.instance.defaultCategoryId ??
          (DatabaseService.instance.rules.isNotEmpty
              ? DatabaseService.instance.rules.first.id
              : 0);

      final schedule = DatabaseService.instance.resolveAutoPlanScheduleWithRollover(
        wallDay: wallDay,
        categoryId: categoryId,
        tags: const [],
        existingDayPlans: cursorPlans,
        timelineDayStartHour: timeView.timelineHourStart,
        timelineDayEndHour: timeView.timelineHourEnd,
        explicitDurationMinutes: explicitDuration,
      );
      if (schedule == null) {
        AppSnack.warning(t(currentLocale.value, 'plan_auto_schedule_no_work_slot'));
        break;
      }
      final plannedWalls = DatabaseService.instance
          .profileDisplayWallsFromAutoSchedule(schedule);
      final scheduledDateKey = _planWallDateKey(plannedWalls.startWall);
      final rolledOver = scheduledDateKey.compareTo(taskDateKey) > 0;

      final order = nextOrder + i;
      final clientPlanId = DatabaseService.newClientUuid();

      try {
        final ok = await DatabaseService.instance.addPlanningTask(
          DatabaseService.instance.planningTaskWithAutoSchedule(
            PlanningTask(
              id: 0,
              title: title,
              categoryId: categoryId,
              isDone: false,
              dateKey: scheduledDateKey,
              initialDateKey: taskDateKey,
              isPostponed: rolledOver,
              order: order,
              checklist: const [],
              parentPlanId: null,
              tags: const [],
              isSynced: false,
            ),
            schedule,
          ),
          clientPlanId: clientPlanId,
        );
        if (!mounted) return created;
        if (ok) {
          created++;
          if (rolledOver) lastRolledTo = plannedWalls.startWall;
          lastCreated = PlanningTask(
            id: 0,
            title: title,
            categoryId: categoryId,
            isDone: false,
            dateKey: scheduledDateKey,
            order: order,
            startTime: plannedWalls.startWall,
            endDateTime: plannedWalls.endWall,
            tags: const [],
          );
          cursorPlans = [...cursorPlans, lastCreated];
        }
      } catch (_) {}
    }
    if (lastRolledTo != null) {
      AppSnack.show(
        t(currentLocale.value, 'plan_auto_schedule_moved_to')
            .replaceFirst('%s', _planRolloverLabel(lastRolledTo)),
      );
    } else if (created > 0 && lastCreated != null) {
      _maybeShowPlanScheduleOverloadWarning(dayPlans: cursorPlans);
    }
    return created;
  }

}
