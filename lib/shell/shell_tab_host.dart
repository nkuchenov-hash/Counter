part of 'life_os_dashboard.dart';

mixin ShellTabHost on ShellCoreLogic {
  Widget buildTimelineSwipeTab() {
    final sw = Stopwatch()..start();
    final child = TimelineSwipeWrapper(
      selectedDate: selectedDate,
      shellTabActive: shellPageIndex == 0,
      onDateChanged: (d) => applySharedSelectedDate(
        shellDateOnly(d),
        loadTimelineTasks: true,
      ),
      onJumpToConflict: jumpToConflictDate,
      tasks: tasks,
      tasksLoading: tasksLoading,
      titleController: titleController,
      titleFocus: titleFocus,
      selectedCategoryId: selectedCategoryId,
      onCategoryChanged: (id) => setState(() => selectedCategoryId = id),
      onStart: startTaskFromInput,
      onPlan: planTaskFromInput,
      onNewTaskForPastDate: (this as ShellDashboardState).openNewTaskForPastDate,
      onStopRecord: stopRecordByDocId,
      onDeleteRecord: deleteRecordByDocId,
      rules: rules,
      onShowEditRecordSheet: (this as ShellDashboardState).showEditRecordSheetForTimeline,
    );
    sw.stop();
    StartupLog.tabBuild(
      tab: 'Timeline',
      active: shellPageIndex == 0,
      ms: sw.elapsedMilliseconds,
    );
    return child;
  }

  Widget buildPlanningSwipeTab() {
    final sw = Stopwatch()..start();
    final child = PlanningSwipeWrapper(
      selectedDate: selectedDate,
      shellTabActive: shellPageIndex == 1,
      onDateChanged: (d) => applySharedSelectedDate(shellDateOnly(d)),
      selectedCategoryId: selectedCategoryId,
      onCategoryChanged: (id) => setState(() => selectedCategoryId = id),
      onStartRecordFromTask: startRecordFromPlanning,
      onEditTask: (task) => (this as ShellDashboardState).openEditDialog(task),
    );
    sw.stop();
    StartupLog.tabBuild(
      tab: 'Plans',
      active: shellPageIndex == 1,
      ms: sw.elapsedMilliseconds,
    );
    return child;
  }

  Widget buildCalendarTab() {
    return CalendarView(
      selectedDate: selectedDate,
      focusedDay: focusedDay,
      onSelectDate: (d, f) async {
        setState(() {
          selectedDate = shellDateOnly(d);
          focusedDay = shellDateOnly(f);
        });
        selectedDateListenable.value = selectedDate;
      },
      onEditTask: (this as ShellDashboardState).openEditDialog,
      onStartRecordFromTask: startRecordFromPlanning,
    );
  }

  Widget buildListsTab() {
    return ListsPage(
      selectedDate: selectedDate,
      onDateChanged: (d) {
        final day = shellDateOnly(d);
        setState(() => selectedDate = day);
        selectedDateListenable.value = day;
      },
      onEditTask: (this as ShellDashboardState).openEditDialog,
    );
  }
}
