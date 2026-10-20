part of 'planning_page.dart';

/// Assistant navigation stays outside the oversized canonical Planning shell.
/// Only persisted current-day selected IDs can enter Viktor's command context.
extension PlanningViktorNavigation on _PlanningPageState {
  void _openViktorChatImpl() {
    final day = widget.selectedDate ??
        DateTime.tryParse(widget.selectedDateString) ?? DateTime.now();
    final selectedIds = _latestPlanningDayTasks
        .where((task) => _selectedPlanKeys.contains(_PlanningPageState._planKey(task)))
        .map((task) => task.pocketRecordId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => ViktorChatPage(
        wallDay: day,
        selectedPlanIds: selectedIds,
      ),
    )).then((_) {
      if (mounted && _selectedPlanKeys.isNotEmpty) _exitSelectMode();
    });
  }
}
