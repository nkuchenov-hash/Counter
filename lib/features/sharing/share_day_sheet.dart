import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/sharing/share_service.dart';
import 'package:counter/features/sharing/shared_detail_page.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Opened only by a visible-day Share action; no offscreen day loads.
Future<void> showSharePlanningDaySheet(
  BuildContext context, {
  required String dayKey,
  required List<PlanningTask> tasks,
}) async {
  final shareable = tasks.where((task) =>
      RegExp(r'^[a-z0-9]{15}$').hasMatch(task.planRowIdForBackend)).toList();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ShareDayPicker(dayKey: dayKey, tasks: shareable),
  );
}

class _ShareDayPicker extends StatefulWidget {
  const _ShareDayPicker({required this.dayKey, required this.tasks});
  final String dayKey;
  final List<PlanningTask> tasks;
  @override
  State<_ShareDayPicker> createState() => _ShareDayPickerState();
}

class _ShareDayPickerState extends State<_ShareDayPicker> {
  late final Set<String> _selected;
  bool _busy = false;
  String? _error;

  bool get _ru => currentLocale.value == 'ru';
  String l(String ru, String en) => _ru ? ru : en;

  @override
  void initState() {
    super.initState();
    _selected = widget.tasks.map((t) => t.planRowIdForBackend).toSet();
  }

  Future<void> _create() async {
    if (_busy || _selected.isEmpty) return;
    setState(() {_busy = true; _error = null;});
    try {
      final share = await ShareService.instance.createDay(
        wallDay: widget.dayKey,
        title: l('План на ${widget.dayKey}', 'Plan for ${widget.dayKey}'),
        planIds: widget.tasks
            .map((t) => t.planRowIdForBackend)
            .where(_selected.contains)
            .toList(),
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => SharedDetailPage(shareId: share.id),
      )));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(child: Padding(
      padding: EdgeInsets.fromLTRB(
        16, 8, 16, 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * .72).clamp(280.0, 680.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l('Поделиться планом', 'Share a plan'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l('Выбери только те задачи, которые увидит друг. '
                    'После создания выбери контакт из раздела «Люди».',
                    'Select only tasks the recipient may see. '
                    'Then invite a contact from People.'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Expanded(
              child: widget.tasks.isEmpty
                  ? Center(child: Text(l('Нет сохранённых задач для отправки.',
                      'No saved plans available to share.')))
                  : ListView.builder(
                      itemCount: widget.tasks.length,
                      itemBuilder: (ctx, index) {
                        final task = widget.tasks[index];
                        final id = task.planRowIdForBackend;
                        return CheckboxListTile(
                          value: _selected.contains(id),
                          title: Text(task.title),
                          onChanged: _busy ? null : (checked) => setState(() {
                            if (checked == true) { _selected.add(id); }
                            else { _selected.remove(id); }
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
            ),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: scheme.error)),
              const SizedBox(height: 8),
            ],
            AppButton.primary(
              label: l('Создать общий план', 'Create shared plan'),
              icon: Icons.group_add_rounded,
              loading: _busy,
              onPressed: _busy || _selected.isEmpty
                  ? null : () => unawaited(_create()),
              fullWidth: true,
            ),
          ],
        ),
      ),
    ));
  }
}
