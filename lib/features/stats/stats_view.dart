import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// STATS FEATURE — UI_ISOLATION (§7). All strings via t() from dictionary.
// Uses StatsNode, SessionGroup from lib/data/models.dart (DNA). No direct DB writes.
// ---------------------------------------------------------------------------

String _formatDuration(Duration d) {
  final totalSeconds = d.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  if (m > 0) return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '${s}s';
}

String _formatTimeOfDay(DateTime dt) => DateFormat.Hm().format(dt);

DateTime _utcToDisplay(DateTime utc) => DatabaseService.instance.applyUserOffset(utc);

/// Stats tab content: hierarchical tree from getAggregatedStats (StatsNode from DNA). Cross-midnight records clamped to selected day.
class StatsView extends StatefulWidget {
  const StatsView({
    super.key,
    required this.records,
    required this.rules,
    required this.isFutureDate,
    required this.selectedDate,
  });

  final List<Map<String, dynamic>> records;
  final List<CategoryRule> rules;
  final bool isFutureDate;
  final DateTime selectedDate;

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  final Set<String> _expandedKeys = {};

  int? _lastCacheKey;
  List<StatsNode>? _cachedAggregated;

  int _aggregatedCacheKey(List<Map<String, dynamic>> records, DateTime selectedDate) {
    return DatabaseService.statsRecordsSignature(records, selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    if (pairs.isEmpty) {
      return Center(
        child: Text(
          t(currentLocale.value, 'add_categories_auditor'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final key = _aggregatedCacheKey(widget.records, widget.selectedDate);
    final List<StatsNode> aggregated;
    if (key == _lastCacheKey && _cachedAggregated != null) {
      aggregated = _cachedAggregated!;
    } else {
      aggregated = DatabaseService.instance.getAggregatedStats(
        widget.records,
        widget.selectedDate,
      );
      _lastCacheKey = key;
      _cachedAggregated = aggregated;
    }
    final totalDuration = aggregated.fold<Duration>(
      Duration.zero,
      (sum, node) => sum + node.total,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            t(currentLocale.value, 'total_time_format').replaceFirst('%s', _formatDuration(totalDuration)),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: widget.records.isEmpty
              ? Center(
                  child: Text(
                    widget.isFutureDate ? t(currentLocale.value, 'no_planned_tasks') : t(currentLocale.value, 'no_records_yet'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              : _buildStatsTree(context, scheme, aggregated),
        ),
      ],
    );
  }

  Widget _buildStatsTree(BuildContext context, ColorScheme scheme, List<StatsNode> roots) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: roots.length,
      itemBuilder: (context, index) => _buildStatsNode(context, scheme, roots[index], 0, ''),
    );
  }

  Widget _buildStatsNode(BuildContext context, ColorScheme scheme, StatsNode node, int depth, String pathPrefix) {
    final pathKey = pathPrefix.isEmpty ? node.label : '$pathPrefix > ${node.label}';
    final indent = depth * 16.0;

    if (node.children.isNotEmpty) {
      final isExpanded = _expandedKeys.contains(pathKey);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedKeys.remove(pathKey);
                } else {
                  _expandedKeys.add(pathKey);
                }
              });
            },
            child: ListTile(
              contentPadding: EdgeInsets.only(left: indent, right: 16),
              title: Text(
                node.label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: depth == 0 ? FontWeight.bold : FontWeight.w600,
                      fontSize: depth == 0 ? 16 : 14,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _formatDuration(node.total),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
              ),
            ),
          ),
          if (isExpanded) ...[
            ...node.children
                .map((child) => _buildStatsNode(context, scheme, child, depth + 1, pathKey)),
            ...node.sessionGroups.asMap().entries.map((e) => _buildGroupRow(
                  context,
                  scheme,
                  pathKey,
                  e.value,
                  (depth + 1) * 16.0 - 16,
                  e.key,
                )),
          ],
        ],
      );
    }

    final hasSessionGroups = node.sessionGroups.isNotEmpty;

    if (!hasSessionGroups) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: indent, right: 16),
        title: Text(
          node.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatDuration(node.total),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.primary),
        ),
      );
    }

    final isLeafExpanded = _expandedKeys.contains(pathKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isLeafExpanded) {
                _expandedKeys.remove(pathKey);
              } else {
                _expandedKeys.add(pathKey);
              }
            });
          },
          child: ListTile(
            contentPadding: EdgeInsets.only(left: indent, right: 16),
            title: Text(
              node.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatDuration(node.total),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.primary),
            ),
          ),
        ),
        if (isLeafExpanded)
          ...node.sessionGroups.asMap().entries.map((e) => _buildGroupRow(context, scheme, pathKey, e.value, indent, e.key)),
      ],
    );
  }

  Widget _buildGroupRow(BuildContext context, ColorScheme scheme, String pathKey, SessionGroup group, double indent, int groupIndex) {
    final taskKey = '$pathKey|$groupIndex';
    final isExpanded = _expandedKeys.contains(taskKey);
    final totalStr = t(currentLocale.value, 'stats_group_total')
        .replaceFirst('%s', group.label)
        .replaceFirst('%s', _formatDuration(group.total));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedKeys.remove(taskKey);
              } else {
                _expandedKeys.add(taskKey);
              }
            });
          },
          child: ListTile(
            contentPadding: EdgeInsets.only(left: indent + 16, right: 16),
            title: Text(
              totalStr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (isExpanded)
          ...group.records
              .map((rec) => _buildSessionTile(context, scheme, rec, indent + 32)),
      ],
    );
  }

  Widget _buildSessionTile(BuildContext context, ColorScheme scheme, Map<String, dynamic> rec, double indent) {
    final startUtc = DatabaseService.startTimeFromRecord(rec);
    final endUtc = DatabaseService.endTimeFromRecord(rec);
    final status = (rec['status'] as String? ?? '').toLowerCase();
    final DateTime? endUtcOrNow = endUtc ??
        (status == 'running' ? DatabaseService.getPlanetaryNow() : null);
    final sec = DatabaseService.recordDurationSecondsWithinDayFromTimestamps(
      rec,
      widget.selectedDate,
      DatabaseService.instance.settings.timezoneOffsetHours,
      DatabaseService.instance.settings.preferredTimeZone,
    );
    final startStr = startUtc != null
        ? _formatTimeOfDay(_utcToDisplay(startUtc))
        : '–';
    final endStr = endUtcOrNow != null
        ? _formatTimeOfDay(_utcToDisplay(endUtcOrNow))
        : '–';
    final actualTitle = (rec['title'] as String?)?.trim();
    final titleDisplay = (actualTitle != null && actualTitle.isNotEmpty) ? actualTitle : t(currentLocale.value, 'untitled');
    final sessionLine = t(currentLocale.value, 'stats_session_line')
        .replaceFirst('%s', startStr)
        .replaceFirst('%s', endStr)
        .replaceFirst('%s', _formatDuration(Duration(seconds: sec)))
        .replaceFirst('%s', titleDisplay);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.normal,
          fontSize: 12,
        );
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: indent, right: 16),
      title: Text(sessionLine, style: style),
    );
  }
}
