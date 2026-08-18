import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/features/timeline/timeline_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

bool timelineRecordIsSleep(Map<String, dynamic> data) {
  final kind = (data['external_kind'] ?? '').toString().trim().toLowerCase();
  final source = (data['sleep_source'] ?? '').toString().trim();
  final title = (data['title'] ?? '').toString().trim().toLowerCase();
  return kind == 'sleep' || source.isNotEmpty || title == 'sleep' || title == 'сон';
}

Future<Map<String, dynamic>> timelineHydrateSleepData(
  Map<String, dynamic> projected,
) async {
  if (!timelineRecordIsSleep(projected)) return projected;
  final businessId = (projected['record_id'] ?? '').toString().trim();
  final systemId = (projected['id'] ?? projected['_pb_record_id'] ?? '')
      .toString()
      .trim();
  try {
    final rows = await DatabaseService.instance.fetchRecords(forceNetwork: false);
    for (final raw in rows) {
      final rawBusinessId = (raw['record_id'] ?? '').toString().trim();
      final rawSystemId = (raw['_pb_record_id'] ?? raw['id'] ?? '')
          .toString()
          .trim();
      final same = businessId.isNotEmpty
          ? rawBusinessId == businessId
          : systemId.isNotEmpty && rawSystemId == systemId;
      if (!same) continue;
      return <String, dynamic>{...projected, ...raw};
    }
  } catch (_) {}
  return projected;
}

String? timelineSleepWakeDateKey(Map<String, dynamic> data) {
  if (!timelineRecordIsSleep(data)) return null;
  final raw = data['end_time'] ?? data['endTime'];
  final endUtc = raw is DateTime
      ? raw.toUtc()
      : DateTime.tryParse(raw?.toString() ?? '')?.toUtc();
  if (endUtc == null) return null;
  final wall = timelineUtcToDisplay(endUtc);
  return '${wall.year}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';
}

List<Map<String, dynamic>> timelineProjectRecordsToWakeDay({
  required String targetDateKey,
  required Iterable<Map<String, dynamic>> startDayRecords,
  required Iterable<Map<String, dynamic>> priorStartDayRecords,
}) {
  final out = <Map<String, dynamic>>[];
  final seen = <String>{};

  void add(Map<String, dynamic> row) {
    final businessId = (row['record_id'] ?? '').toString().trim();
    final systemId = (row['id'] ?? row['_pb_record_id'] ?? '').toString().trim();
    final key = businessId.isNotEmpty
        ? businessId
        : systemId.isNotEmpty
            ? systemId
            : '${row['title']}|${row['start_time']}|${row['end_time']}';
    if (!seen.add(key)) return;
    out.add(row);
  }

  for (final row in startDayRecords) {
    if (timelineRecordIsSleep(row)) {
      if (timelineSleepWakeDateKey(row) == targetDateKey) add(row);
    } else {
      add(row);
    }
  }
  for (final row in priorStartDayRecords) {
    if (timelineRecordIsSleep(row) &&
        timelineSleepWakeDateKey(row) == targetDateKey) {
      add(row);
    }
  }

  out.sort((a, b) {
    DateTime? start(Map<String, dynamic> row) {
      final raw = row['start_time'] ?? row['startTime'];
      if (raw is DateTime) return raw.toUtc();
      return DateTime.tryParse(raw?.toString() ?? '')?.toUtc();
    }

    final aStart = start(a);
    final bStart = start(b);
    if (aStart == null && bStart == null) return 0;
    if (aStart == null) return 1;
    if (bStart == null) return -1;
    return bStart.compareTo(aStart);
  });
  return out;
}

class TimelineSleepStage {
  const TimelineSleepStage({
    required this.startUtc,
    required this.endUtc,
    required this.stage,
    required this.source,
  });

  final DateTime startUtc;
  final DateTime endUtc;
  final int stage;
  final String source;

  Duration get duration => endUtc.difference(startUtc);
}

List<TimelineSleepStage> timelineSleepStages(Map<String, dynamic> data) {
  dynamic raw = data['sleep_stages'];
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      raw = jsonDecode(raw);
    } catch (_) {
      return const <TimelineSleepStage>[];
    }
  }
  if (raw is! List) return const <TimelineSleepStage>[];

  final out = <TimelineSleepStage>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final start = DateTime.tryParse((item['start'] ?? '').toString())?.toUtc();
    final end = DateTime.tryParse((item['end'] ?? '').toString())?.toUtc();
    final stageRaw = item['stage'];
    final stage = stageRaw is num
        ? stageRaw.toInt()
        : int.tryParse(stageRaw?.toString() ?? '') ?? 0;
    if (start == null || end == null || !end.isAfter(start)) continue;
    out.add(
      TimelineSleepStage(
        startUtc: start,
        endUtc: end,
        stage: stage,
        source: (item['source'] ?? '').toString().trim(),
      ),
    );
  }
  out.sort((a, b) => a.startUtc.compareTo(b.startUtc));
  return out;
}

String _sleepStageLabel(String locale, int stage) {
  final ru = locale == 'ru';
  return switch (stage) {
    1 => ru ? 'Бодрствование' : 'Awake',
    2 => ru ? 'Сон' : 'Sleep',
    3 => ru ? 'Вне кровати' : 'Out of bed',
    4 => ru ? 'Лёгкий' : 'Light',
    5 => ru ? 'Глубокий' : 'Deep',
    6 => 'REM',
    7 => ru ? 'Бодрствование в кровати' : 'Awake in bed',
    _ => ru ? 'Не определено' : 'Unknown',
  };
}

String _sleepDuration(Duration duration, String locale) {
  final minutes = duration.inMinutes;
  final h = minutes ~/ 60;
  final m = minutes.remainder(60);
  if (locale == 'ru') {
    if (h > 0 && m > 0) return '${h}ч ${m}м';
    if (h > 0) return '${h}ч';
    return '${m}м';
  }
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}

Map<int, Duration> _sleepStageTotals(List<TimelineSleepStage> stages) {
  final totals = <int, Duration>{};
  for (final stage in stages) {
    totals[stage.stage] = (totals[stage.stage] ?? Duration.zero) + stage.duration;
  }
  return totals;
}

String timelineSleepSource(Map<String, dynamic> data) {
  final sourceName = (data['sleep_source_name'] ?? '').toString().trim();
  if (sourceName.isNotEmpty) return sourceName;
  final source = (data['sleep_source'] ?? data['external_source'] ?? '')
      .toString()
      .trim();
  if (source == 'google_fit') return 'Google Fit';
  if (source == 'health_connect') return 'Health Connect';
  if (source == 'apple_health') return 'Apple Health';
  return source;
}

class TimelineSleepSummary extends StatelessWidget {
  const TimelineSleepSummary({super.key, required this.data});

  final Map<String, dynamic> data;

  Widget _buildSummary(BuildContext context, Map<String, dynamic> hydrated) {
    final stages = timelineSleepStages(hydrated);
    final totals = _sleepStageTotals(stages);
    final locale = currentLocale.value;
    final source = timelineSleepSource(hydrated);
    final recovered = hydrated['sleep_recovered_from_segments'] == true;
    final pointsRaw = hydrated['sleep_segment_points'];
    final points = pointsRaw is num
        ? pointsRaw.toInt()
        : int.tryParse(pointsRaw?.toString() ?? '') ?? stages.length;
    final scheme = Theme.of(context).colorScheme;

    final summary = <Widget>[];
    for (final entry in totals.entries) {
      summary.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_sleepStageLabel(locale, entry.key)} ${_sleepDuration(entry.value, locale)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (source.isNotEmpty || points > 0 || recovered) ...[
          const SizedBox(height: 6),
          Text(
            [
              if (source.isNotEmpty) source,
              if (points > 0) locale == 'ru' ? '$points сегм.' : '$points segments',
              if (recovered) locale == 'ru' ? 'восстановлено' : 'recovered',
            ].join(' · '),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: summary),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: timelineHydrateSleepData(data),
      initialData: data,
      builder: (context, snapshot) =>
          _buildSummary(context, snapshot.data ?? data),
    );
  }
}

Future<void> showTimelineSleepDetails(
  BuildContext context,
  Map<String, dynamic> data,
) async {
  final hydrated = await timelineHydrateSleepData(data);
  if (!context.mounted) return;
  final stages = timelineSleepStages(hydrated);
  final totals = _sleepStageTotals(stages);
  final locale = currentLocale.value;
  final source = timelineSleepSource(hydrated);
  final recovered = hydrated['sleep_recovered_from_segments'] == true;
  final startRaw = hydrated['start_time'] ?? hydrated['startTime'];
  final endRaw = hydrated['end_time'] ?? hydrated['endTime'];
  final startUtc = startRaw is DateTime
      ? startRaw.toUtc()
      : DateTime.tryParse(startRaw?.toString() ?? '')?.toUtc();
  final endUtc = endRaw is DateTime
      ? endRaw.toUtc()
      : DateTime.tryParse(endRaw?.toString() ?? '')?.toUtc();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                locale == 'ru' ? 'Данные сна' : 'Sleep data',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (startUtc != null && endUtc != null)
                Text(
                  '${timelineFormatTimeOfDay(timelineUtcToDisplay(startUtc))} — '
                  '${timelineFormatTimeOfDay(timelineUtcToDisplay(endUtc))} '
                  '(${timelineFormatDuration(endUtc.difference(startUtc))})',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              if (source.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${locale == 'ru' ? 'Источник' : 'Source'}: $source',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (recovered) ...[
                const SizedBox(height: 4),
                Text(
                  locale == 'ru'
                      ? 'Границы сна восстановлены по сегментам источника.'
                      : 'Sleep boundaries were recovered from source segments.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (totals.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  locale == 'ru' ? 'По стадиям' : 'Stage totals',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final entry in totals.entries)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_sleepStageLabel(locale, entry.key)),
                    trailing: Text(_sleepDuration(entry.value, locale)),
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                locale == 'ru' ? 'Хронология' : 'Timeline',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (stages.isEmpty)
                Text(
                  locale == 'ru'
                      ? 'Источник не передал детализацию по стадиям для этой ночи.'
                      : 'The source did not provide stage detail for this night.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                )
              else
                for (final stage in stages)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_sleepStageLabel(locale, stage.stage)),
                    subtitle: stage.source.isEmpty ? null : Text(stage.source),
                    trailing: Text(
                      '${timelineFormatTimeOfDay(timelineUtcToDisplay(stage.startUtc))}–'
                      '${timelineFormatTimeOfDay(timelineUtcToDisplay(stage.endUtc))} · '
                      '${_sleepDuration(stage.duration, locale)}',
                    ),
                  ),
            ],
          ),
        ),
      );
    },
  );
}
