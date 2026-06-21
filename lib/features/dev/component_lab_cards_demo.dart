part of 'component_lab_view.dart';

class ComponentLabPlanCardsDemo extends StatelessWidget {
  const ComponentLabPlanCardsDemo({super.key});

  static PlanningTask _mockTask({
    required String title,
    String dateKey = '2026-06-15',
    DateTime? start,
    DateTime? end,
    bool isDone = false,
    String? rrule,
    List<Tag> tags = const [],
    String? notesPlain,
    List<Map<String, dynamic>> checklist = const [],
  }) {
    return PlanningTask(
      id: 1,
      planRowId: 'lab-mock-plan',
      pocketRecordId: 'labpb0000000001',
      title: title,
      categoryId: 1,
      isDone: isDone,
      dateKey: dateKey,
      startTime: start,
      endDateTime: end,
      rrule: rrule,
      tags: tags,
      notesPlain: notesPlain,
      checklist: checklist,
    );
  }

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final listTask = _mockTask(
      title: 'Review weekly priorities',
      start: DateTime(2026, 6, 15, 9, 30),
      end: DateTime(2026, 6, 15, 10, 30),
      tags: const [
        Tag(tagId: 1, name: 'V7', color: '#1565C0', icon: 'label'),
      ],
    );
    final recurringTask = _mockTask(
      title: 'Daily standup',
      start: DateTime(2026, 6, 15, 10, 0),
      end: DateTime(2026, 6, 15, 10, 15),
      rrule: 'FREQ=DAILY',
    );
    final timeShort = _mockTask(
      title: 'Quick sync',
      start: DateTime(2026, 6, 15, 14, 0),
      end: DateTime(2026, 6, 15, 14, 30),
    );
    final timeLong = _mockTask(
      title: 'Deep work block',
      start: DateTime(2026, 6, 15, 11, 0),
      end: DateTime(2026, 6, 15, 14, 0),
      notesPlain: 'Focus session',
      checklist: const [
        {'text': 'Outline', 'done': true},
        {'text': 'Draft', 'done': false},
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabExample(
          title: 'PlanCard / List / Default',
          flutterMapping: 'PlanCard(timelineBlock: false) → PlanTimeTaskCard list',
          variant: 'list',
          state: 'default',
          fullWidth: true,
          note: 'Same widget as Planning Category/Tags/Custom modes.',
          child: PlanCard(
            task: listTask,
            planTrackedSeconds: 900,
            planEstimatedSeconds: 3600,
            displayIsDone: false,
            selectMode: false,
            isSelected: false,
            highlightAsRunning: false,
            toggleDoneEnabled: true,
            onToggleDone: _noop,
            onBodyTap: _noop,
            onPlay: _noop,
            onOpenMenu: (_) {},
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'PlanCard / List / Selected + recurring',
          flutterMapping: 'PlanCard(isSelected: true)',
          variant: 'list',
          state: 'selected',
          fullWidth: true,
          child: PlanCard(
            task: recurringTask,
            planTrackedSeconds: 0,
            planEstimatedSeconds: 900,
            displayIsDone: false,
            selectMode: false,
            isSelected: true,
            highlightAsRunning: false,
            toggleDoneEnabled: true,
            onToggleDone: _noop,
            onBodyTap: _noop,
            onPlay: _noop,
            onOpenMenu: (_) {},
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'PlanCard / List / Completed',
          flutterMapping: 'PlanCard(displayIsDone: true)',
          variant: 'list',
          state: 'completed',
          fullWidth: true,
          child: PlanCard(
            task: listTask.copyWith(isDone: true),
            planTrackedSeconds: 3600,
            planEstimatedSeconds: 3600,
            displayIsDone: true,
            selectMode: false,
            isSelected: false,
            highlightAsRunning: false,
            toggleDoneEnabled: true,
            onToggleDone: _noop,
            onBodyTap: _noop,
            onPlay: _noop,
            onOpenMenu: (_) {},
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'PlanCard / Time / Short block',
          flutterMapping:
              'PlanCard(timelineBlock: true, timelineBlockHeightPx: 64)',
          variant: 'time',
          state: 'compact',
          fullWidth: true,
          note: 'Same widget as Planning Time mode duration blocks.',
          child: SizedBox(
            height: 64,
            child: PlanCard(
              task: timeShort,
              planTrackedSeconds: 600,
              planEstimatedSeconds: 1800,
              displayIsDone: false,
              selectMode: false,
              isSelected: false,
              highlightAsRunning: false,
              toggleDoneEnabled: true,
              timelineBlock: true,
              timelineBlockHeightPx: 64,
              onToggleDone: _noop,
              onBodyTap: _noop,
              onPlay: _noop,
              onOpenMenu: (_) {},
            ),
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'PlanCard / Time / Long block + progress',
          flutterMapping:
              'PlanCard(timelineBlock: true, timelineBlockHeightPx: 180)',
          variant: 'time',
          state: 'medium',
          fullWidth: true,
          child: SizedBox(
            height: 180,
            child: PlanCard(
              task: timeLong,
              planTrackedSeconds: 5400,
              planEstimatedSeconds: 10800,
              displayIsDone: false,
              selectMode: false,
              isSelected: false,
              highlightAsRunning: true,
              toggleDoneEnabled: true,
              timelineBlock: true,
              timelineBlockHeightPx: 180,
              onToggleDone: _noop,
              onBodyTap: _noop,
              onPlay: _noop,
              onOpenMenu: (_) {},
            ),
          ),
        ),
      ],
    );
  }
}
