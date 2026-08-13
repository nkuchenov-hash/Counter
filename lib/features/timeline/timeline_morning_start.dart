import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/features/shared/sleep_record_policy.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight gate that asks for a morning check-in once per waking day.
///
/// The confirmed sleep interval is persisted to Timeline. Existing manual or
/// imported sleep is updated in place; otherwise a completed Sleep record is
/// created. The server's singleton Timeline sanitizer remains the authority for
/// reconciling any ordinary activity that overlaps the confirmed sleep span.
class MorningStartGate extends StatefulWidget {
  const MorningStartGate({
    super.key,
    required this.selectedDate,
    required this.active,
    required this.titleController,
    required this.titleFocus,
    required this.onStart,
    required this.child,
  });

  final DateTime selectedDate;
  final bool active;
  final TextEditingController titleController;
  final FocusNode titleFocus;
  final Future<void> Function() onStart;
  final Widget child;

  @override
  State<MorningStartGate> createState() => _MorningStartGateState();
}

class _MorningStartGateState extends State<MorningStartGate> {
  bool _sheetOpen = false;
  bool _checkScheduled = false;
  String? _lastCheckedDay;

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _prefsPrefix(DateTime day) {
    final profile = DatabaseService.instance.currentProfileId ?? 'local';
    return 'lifeos.morning_start.$profile.${_dayKey(day)}';
  }

  void _scheduleCheck() {
    if (_checkScheduled || _sheetOpen || !widget.active) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkScheduled = false;
      if (!mounted || !widget.active || _sheetOpen) return;
      await _maybeShow();
    });
  }

  Future<void> _maybeShow() async {
    final db = DatabaseService.instance;
    final day = _day(widget.selectedDate);
    final today = _day(db.getTimelineDeviceLocalToday());
    if (!_sameDay(day, today)) return;

    final key = _dayKey(day);
    if (_lastCheckedDay == key) return;

    final current = db.peekTimelineRecordsForDate(day);
    final adjacent = SleepRecordPolicy.adjacentRecordsForDay(day, current);
    final mainSleep = SleepRecordPolicy.mainSleepEndingOnDay(day, adjacent);
    final wake = mainSleep == null
        ? null
        : SleepRecordPolicy.endWall(mainSleep);
    final nowWall = db.applyUserOffset(DatabaseService.getPlanetaryNow());

    final hasWakingActivity = current.any((record) {
      if (SleepRecordPolicy.isSleepRecord(record)) return false;
      final start = SleepRecordPolicy.startWall(record);
      return start != null && _sameDay(start, day);
    });
    // Ask close to the actual wake-up when sleep is available. Without sleep
    // data, use a conservative morning window instead of interrupting at night.
    if (wake != null) {
      final sinceWake = nowWall.difference(wake);
      if (sinceWake < const Duration(minutes: -15) ||
          sinceWake > const Duration(hours: 6)) {
        return;
      }
    } else if (nowWall.hour < 4 || nowWall.hour >= 13) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final prefix = _prefsPrefix(day);
    if (prefs.getBool('$prefix.done') == true ||
        prefs.getBool('$prefix.dismissed') == true) {
      _lastCheckedDay = key;
      return;
    }

    final detectedBed = mainSleep == null
        ? null
        : SleepRecordPolicy.startWall(mainSleep);
    final detectedWake = wake;
    _sheetOpen = true;
    final result = await showModalBottomSheet<MorningStartResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (context) => MorningStartSheet(
        day: day,
        detectedBed: detectedBed,
        detectedWake: detectedWake,
        allowFirstActivity: !hasWakingActivity,
      ),
    );
    _sheetOpen = false;
    if (!mounted) return;

    if (result == null) {
      await prefs.setBool('$prefix.dismissed', true);
      _lastCheckedDay = key;
      return;
    }

    // The sheet edits profile wall-clock values. Convert them back to real UTC
    // instants before touching Timeline; device timezone must not leak here.
    final bedtimeUtc = db.displayTimeToUtc(result.bedtime);
    final wakeUtc = db.displayTimeToUtc(result.wake);
    if (!wakeUtc.isAfter(bedtimeUtc)) return;

    var sleepSaved = false;
    if (mainSleep != null && mainSleep.id.trim().isNotEmpty) {
      final updated = await db.updateRecord(
        recordId: mainSleep.id,
        startTime: bedtimeUtc,
        endTime: wakeUtc,
      );
      sleepSaved = updated != null;
    } else {
      final ru = currentLocale.value.toLowerCase().startsWith('ru');
      final sleepTitle = ru ? 'Сон' : 'Sleep';
      final sleepCategory =
          db.identifyCategory(sleepTitle) ??
          db.identifyCategory(ru ? 'Sleep' : 'Сон');
      final created = await db.writeRecord(
        key,
        sleepTitle,
        categoryId: sleepCategory?.id,
        explicitStartTime: bedtimeUtc,
        explicitEndTime: wakeUtc,
      );
      sleepSaved = created != null;
    }

    // Never consume the morning check-in until the Timeline mutation exists.
    // This keeps a failed/offline create retryable instead of silently losing it.
    if (!sleepSaved) return;

    await prefs.setInt('$prefix.sleep_quality', result.sleepQuality);
    await prefs.setString('$prefix.bedtime', result.bedtime.toIso8601String());
    await prefs.setString('$prefix.wake', result.wake.toIso8601String());
    await prefs.setBool('$prefix.done', true);
    _lastCheckedDay = key;

    final firstActivity = result.firstActivity.trim();
    if (firstActivity.isEmpty) return;
    widget.titleController.text = firstActivity;
    widget.titleController.selection = TextSelection.collapsed(
      offset: firstActivity.length,
    );
    await widget.onStart();
    if (mounted) widget.titleFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleCheck();
    return widget.child;
  }
}

class MorningStartResult {
  const MorningStartResult({
    required this.sleepQuality,
    required this.bedtime,
    required this.wake,
    required this.firstActivity,
  });

  final int sleepQuality;
  final DateTime bedtime;
  final DateTime wake;
  final String firstActivity;
}

class MorningStartSheet extends StatefulWidget {
  const MorningStartSheet({
    super.key,
    required this.day,
    required this.allowFirstActivity,
    this.detectedBed,
    this.detectedWake,
  });

  final DateTime day;
  final bool allowFirstActivity;
  final DateTime? detectedBed;
  final DateTime? detectedWake;

  @override
  State<MorningStartSheet> createState() => _MorningStartSheetState();
}

class _MorningStartSheetState extends State<MorningStartSheet> {
  late TimeOfDay _bed;
  late TimeOfDay _wake;
  int _quality = 3;
  String _activity = '';
  final TextEditingController _customController = TextEditingController();

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');
  String _copy(String en, String ru) => _ru ? ru : en;

  List<String> get _suggestions => _ru
      ? const ['Умывание', 'Душ', 'Завтрак', 'Зарядка']
      : const ['Wash up', 'Shower', 'Breakfast', 'Exercise'];

  @override
  void initState() {
    super.initState();
    final fallbackWake = DatabaseService.instance.applyUserOffset(
      DatabaseService.getPlanetaryNow(),
    );
    final bed =
        widget.detectedBed ??
        widget.day
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 23, minutes: 30));
    final wake = widget.detectedWake ?? fallbackWake;
    _bed = TimeOfDay.fromDateTime(bed);
    _wake = TimeOfDay.fromDateTime(wake);
    _activity = _suggestions.first;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _pickBed() async {
    final next = await showTimePicker(context: context, initialTime: _bed);
    if (next != null && mounted) setState(() => _bed = next);
  }

  Future<void> _pickWake() async {
    final next = await showTimePicker(context: context, initialTime: _wake);
    if (next != null && mounted) setState(() => _wake = next);
  }

  DateTime _dateTimeForWake() => DateTime(
    widget.day.year,
    widget.day.month,
    widget.day.day,
    _wake.hour,
    _wake.minute,
  );

  DateTime _dateTimeForBed() {
    final wake = _dateTimeForWake();
    var bed = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _bed.hour,
      _bed.minute,
    );
    if (!bed.isBefore(wake)) bed = bed.subtract(const Duration(days: 1));
    return bed;
  }

  void _finish({required bool startActivity}) {
    final custom = _customController.text.trim();
    final activity = !startActivity || !widget.allowFirstActivity
        ? ''
        : custom.isNotEmpty
        ? custom
        : _activity;
    Navigator.of(context).pop(
      MorningStartResult(
        sleepQuality: _quality,
        bedtime: _dateTimeForBed(),
        wake: _dateTimeForWake(),
        firstActivity: activity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 12, 10, bottom + 10),
      child: Material(
        color: scheme.surface.withValues(alpha: 0.96),
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.wb_sunny_outlined, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _copy('Start the day', 'Начнём день'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          _copy(
                            'First, a 10-second sleep check-in.',
                            'Сначала 10 секунд про сон.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                _copy('How did you sleep?', 'Как вы спали?'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++) ...[
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 5 ? 0 : 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: () => setState(() => _quality = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            height: 44,
                            decoration: BoxDecoration(
                              color: i == _quality
                                  ? scheme.primary.withValues(alpha: 0.13)
                                  : scheme.surfaceContainerHighest.withValues(
                                      alpha: 0.45,
                                    ),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: i == _quality
                                    ? scheme.primary.withValues(alpha: 0.45)
                                    : scheme.outlineVariant.withValues(
                                        alpha: 0.35,
                                      ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$i',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: i == _quality ? scheme.primary : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _TimeTile(
                      label: _copy('Went to bed', 'Легли'),
                      value: _bed.format(context),
                      icon: Icons.bedtime_outlined,
                      onTap: _pickBed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeTile(
                      label: _copy('Woke up', 'Встали'),
                      value: _wake.format(context),
                      icon: Icons.wb_sunny_outlined,
                      onTap: _pickWake,
                    ),
                  ),
                ],
              ),
              if (widget.allowFirstActivity) ...[
                const SizedBox(height: 24),
                Text(
                  _copy('What do we do first?', 'Что делаем первым?'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final suggestion in _suggestions)
                      ChoiceChip(
                        label: Text(suggestion),
                        selected:
                            _activity == suggestion &&
                            _customController.text.trim().isEmpty,
                        onSelected: (_) {
                          _customController.clear();
                          setState(() => _activity = suggestion);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _customController,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _copy('Something else…', 'Что-то другое…'),
                    prefixIcon: const Icon(Icons.edit_outlined, size: 19),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      _finish(startActivity: widget.allowFirstActivity),
                  icon: Icon(
                    widget.allowFirstActivity
                        ? Icons.play_arrow_rounded
                        : Icons.check_rounded,
                  ),
                  label: Text(
                    widget.allowFirstActivity
                        ? _copy('Start day', 'Начать день')
                        : _copy('Save morning check-in', 'Сохранить утро'),
                  ),
                ),
              ),
              if (widget.allowFirstActivity) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _finish(startActivity: false),
                    child: Text(
                      _copy('Save sleep only', 'Только сохранить сон'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: scheme.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
