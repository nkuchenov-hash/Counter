from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing {label}')
    return text.replace(old, new, 1)

# Fix nullable promotions and avoid treating long daytime naps as the next bedtime.
p = Path('lib/features/shared/sleep_record_policy.dart')
s = p.read_text()
s = replace_once(
    s,
    """      if (!start.isAfter(wakeWall.add(const Duration(hours: 4)))) continue;
      if (end.difference(start) < const Duration(hours: 2)) continue;
      if (bestStart == null || start.isBefore(bestStart)) {
""",
    """      if (!start.isAfter(wakeWall.add(const Duration(hours: 4)))) continue;
      final duration = end.difference(start);
      if (duration < const Duration(hours: 2)) continue;
      final looksLikeMainSleep =
          duration >= const Duration(hours: 4) || start.hour >= 18 || start.hour < 5;
      if (!looksLikeMainSleep) continue;
      if (bestStart == null || start.isBefore(bestStart)) {
""",
    'next main sleep nap guard',
)
old = """    DateTime? wake = previousSleep == null ? null : endWall(previousSleep);

    final nonSleepOnDay =
"""
new = """    final detectedWake = previousSleep == null ? null : endWall(previousSleep);

    final nonSleepOnDay =
"""
s = replace_once(s, old, new, 'detected wake')
old = """    // If sleep data has not arrived yet, the first waking activity is the most
    // truthful observable start boundary. Only then fall back to 06:00.
    wake ??= nonSleepOnDay.isNotEmpty
        ? startWall(nonSleepOnDay.first)
        : day.add(const Duration(hours: 6));

    final nextSleep = nextMainSleepAfter(wake, candidates);
    DateTime? bed = nextSleep == null ? null : startWall(nextSleep);

    final today = _day(db.getTimelineDeviceLocalToday());
    if (bed == null) {
      if (_sameDay(day, today)) {
        final nowWall = db.applyUserOffset(DatabaseService.getPlanetaryNow());
        bed = nowWall.isAfter(wake)
            ? nowWall
            : wake.add(const Duration(minutes: 1));
      } else {
        // When the next sleep is unavailable, keep the historical fallback at
        // the calendar boundary rather than inventing a bedtime.
        bed = day.add(const Duration(days: 1));
        if (!bed.isAfter(wake)) bed = wake.add(const Duration(hours: 16));
      }
    }

    final wakingRecords = <Map<String, dynamic>>[];
"""
new = """    // If sleep data has not arrived yet, the first waking activity is the most
    // truthful observable start boundary. Only then fall back to 06:00.
    final wakeWall =
        detectedWake ??
        (nonSleepOnDay.isNotEmpty
            ? startWall(nonSleepOnDay.first)!
            : day.add(const Duration(hours: 6)));

    final nextSleep = nextMainSleepAfter(wakeWall, candidates);
    final detectedBed = nextSleep == null ? null : startWall(nextSleep);

    final today = _day(db.getTimelineDeviceLocalToday());
    final DateTime bedWall;
    if (detectedBed != null) {
      bedWall = detectedBed;
    } else if (_sameDay(day, today)) {
      final nowWall = db.applyUserOffset(DatabaseService.getPlanetaryNow());
      bedWall = nowWall.isAfter(wakeWall)
          ? nowWall
          : wakeWall.add(const Duration(minutes: 1));
    } else {
      // When the next sleep is unavailable, keep the historical fallback at
      // the calendar boundary rather than inventing a bedtime.
      final boundary = day.add(const Duration(days: 1));
      bedWall = boundary.isAfter(wakeWall)
          ? boundary
          : wakeWall.add(const Duration(hours: 16));
    }

    final wakingRecords = <Map<String, dynamic>>[];
"""
s = replace_once(s, old, new, 'nonnull waking boundaries')
s = s.replace('!end.isAfter(wake) || !start.isBefore(bed)', '!end.isAfter(wakeWall) || !start.isBefore(bedWall)')
s = s.replace('wakeWall: wake,\n      bedWall: bed,', 'wakeWall: wakeWall,\n      bedWall: bedWall,')
p.write_text(s)

# Morning: still ask for sleep feedback if the user already began the day, but
# don't offer to start a second "first" activity in that case.
p = Path('lib/features/timeline/timeline_morning_start.dart')
s = p.read_text()
s = replace_once(
    s,
    """    if (hasWakingActivity) {
      _lastCheckedDay = key;
      return;
    }

    // Ask close to the actual wake-up when sleep is available. Without sleep
""",
    """    // Ask close to the actual wake-up when sleep is available. Without sleep
""",
    'remove morning early return',
)
s = replace_once(
    s,
    """      builder: (context) => MorningStartSheet(
        day: day,
        detectedBed: detectedBed,
        detectedWake: detectedWake,
      ),
""",
    """      builder: (context) => MorningStartSheet(
        day: day,
        detectedBed: detectedBed,
        detectedWake: detectedWake,
        allowFirstActivity: !hasWakingActivity,
      ),
""",
    'morning allow first activity call',
)
s = replace_once(
    s,
    """  const MorningStartSheet({
    super.key,
    required this.day,
    this.detectedBed,
    this.detectedWake,
  });

  final DateTime day;
  final DateTime? detectedBed;
  final DateTime? detectedWake;
""",
    """  const MorningStartSheet({
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
""",
    'morning sheet bool',
)
s = replace_once(
    s,
    """    final activity = !startActivity
        ? ''
        : custom.isNotEmpty
        ? custom
        : _activity;
""",
    """    final activity = !startActivity || !widget.allowFirstActivity
        ? ''
        : custom.isNotEmpty
        ? custom
        : _activity;
""",
    'morning activity guard',
)
old = """              const SizedBox(height: 24),
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
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _finish(startActivity: true),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(_copy('Start day', 'Начать день')),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _finish(startActivity: false),
                  child: Text(_copy('Save sleep only', 'Только сохранить сон')),
                ),
              ),
"""
new = """              if (widget.allowFirstActivity) ...[
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
                  onPressed: () => _finish(
                    startActivity: widget.allowFirstActivity,
                  ),
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
                    child: Text(_copy('Save sleep only', 'Только сохранить сон')),
                  ),
                ),
              ],
"""
s = replace_once(s, old, new, 'morning conditional first activity UI')
p.write_text(s)

# Plan/Fact empty state should use the visible non-sleep dimensions.
p = Path('lib/features/stats/plan_vs_fact_tab.dart')
s = p.read_text()
old = """        if (stats.planTaskCount == 0 &&
            stats.planTimeSeconds == 0 &&
            stats.factTimeSeconds == 0) {
          return AppEmptyState(
            message: t(
              currentLocale.value,
              widget.isFutureDate ? 'no_planned_tasks' : 'stats_pvf_no_plans',
            ),
            icon: Icons.fact_check_outlined,
          );
        }

        final byPlan = DatabaseService.instance
"""
new = """        final byPlan = DatabaseService.instance
"""
s = replace_once(s, old, new, 'remove raw plan fact empty state')
old = """        final facts = _PlanFacts(
          stats: stats,
          actualByPlan: byPlan,
          unplannedRecordCount: unplannedRecordCount,
        );
        return _PlanFactContent(facts: facts);
"""
new = """        final facts = _PlanFacts(
          stats: stats,
          actualByPlan: byPlan,
          unplannedRecordCount: unplannedRecordCount,
        );
        if (facts.plannedCount == 0 &&
            facts.plannedTimeSeconds == 0 &&
            facts.factTimeSeconds == 0) {
          return AppEmptyState(
            message: t(
              currentLocale.value,
              widget.isFutureDate ? 'no_planned_tasks' : 'stats_pvf_no_plans',
            ),
            icon: Icons.fact_check_outlined,
          );
        }
        return _PlanFactContent(facts: facts);
"""
s = replace_once(s, old, new, 'visible plan fact empty state')
p.write_text(s)
