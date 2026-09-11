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
    final time10 = _mockTask(
      title: 'Price Reporter Email Check',
      start: DateTime(2026, 6, 15, 14, 0),
      end: DateTime(2026, 6, 15, 14, 10),
      tags: const [
        Tag(tagId: 2, name: 'встречи', color: '#F55D88', icon: 'label'),
        Tag(tagId: 3, name: 'gsa / co', color: '#7118E5', icon: 'label'),
      ],
    );
    final time30 = time10.copyWith(
      endDateTime: DateTime(2026, 6, 15, 14, 30),
    );
    final time45 = time10.copyWith(
      endDateTime: DateTime(2026, 6, 15, 14, 45),
    );
    final time60 = time10.copyWith(
      endDateTime: DateTime(2026, 6, 15, 15, 0),
    );
    final time90 = time10.copyWith(
      endDateTime: DateTime(2026, 6, 15, 15, 30),
      notesPlain: 'Focus session',
      checklist: const [
        {'text': 'Outline', 'done': true},
        {'text': 'Draft', 'done': false},
      ],
    );

    Widget timeExample({
      required String title,
      required PlanningTask task,
      required int durationMinutes,
      int trackedSeconds = 0,
      bool completed = false,
      bool running = false,
    }) {
      final height = planTimeCardRenderedHeightPxForDuration(durationMinutes);
      return _LabExample(
        title: title,
        flutterMapping:
            'PlanCard(timelineBlock: true, timelineBlockHeightPx: '
            '${height.toStringAsFixed(2)})',
        variant: 'time / ${durationMinutes}min',
        state: completed ? 'completed' : (running ? 'running' : 'default'),
        fullWidth: true,
        note:
            'Canonical duration-responsive Time View card. Category watermark '
            'comes from the category presentation.',
        child: SizedBox(
          height: height,
          child: PlanCard(
            task: completed ? task.copyWith(isDone: true) : task,
            planTrackedSeconds: trackedSeconds,
            planEstimatedSeconds: durationMinutes * 60,
            displayIsDone: completed,
            selectMode: false,
            isSelected: false,
            highlightAsRunning: running,
            toggleDoneEnabled: true,
            timelineBlock: true,
            timelineBlockHeightPx: height,
            onToggleDone: _noop,
            onBodyTap: _noop,
            onPlay: _noop,
            onOpenMenu: (_) {},
          ),
        ),
      );
    }

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
        timeExample(
          title: 'PlanCard / Time / 10 min',
          task: time10,
          durationMinutes: 10,
        ),
        const SizedBox(height: 12),
        timeExample(
          title: 'PlanCard / Time / 30 min',
          task: time30,
          durationMinutes: 30,
          trackedSeconds: 600,
        ),
        const SizedBox(height: 12),
        timeExample(
          title: 'PlanCard / Time / 45 min',
          task: time45,
          durationMinutes: 45,
          trackedSeconds: 900,
        ),
        const SizedBox(height: 12),
        timeExample(
          title: 'PlanCard / Time / 60 min / Running',
          task: time60,
          durationMinutes: 60,
          trackedSeconds: 1200,
          running: true,
        ),
        const SizedBox(height: 12),
        timeExample(
          title: 'PlanCard / Time / 90 min',
          task: time90,
          durationMinutes: 90,
          trackedSeconds: 2700,
        ),
        const SizedBox(height: 12),
        timeExample(
          title: 'PlanCard / Time / 30 min / Completed',
          task: time30,
          durationMinutes: 30,
          trackedSeconds: 1800,
          completed: true,
        ),
      ],
    );
  }
}
