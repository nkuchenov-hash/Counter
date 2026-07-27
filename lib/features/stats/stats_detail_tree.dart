import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  if (minutes > 0) {
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${seconds}s';
}

String _formatTimeOfDay(DateTime value) =>
    DateFormat.Hm(currentLocale.value).format(value);

DateTime _utcToDisplay(DateTime utc) =>
    DatabaseService.instance.applyUserOffset(utc);

class StatsDetailTree extends StatelessWidget {
  const StatsDetailTree({
    super.key,
    required this.roots,
    required this.totalDuration,
    required this.selectedDate,
    required this.expandedKeys,
    required this.onToggle,
  });

  final List<StatsNode> roots;
  final Duration totalDuration;
  final DateTime selectedDate;
  final Set<String> expandedKeys;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            t(
              currentLocale.value,
              'total_time_format',
            ).replaceFirst('%s', _formatDuration(totalDuration)),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: roots.length,
            itemBuilder: (context, index) =>
                _buildStatsNode(context, scheme, roots[index], 0, ''),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsNode(
    BuildContext context,
    ColorScheme scheme,
    StatsNode node,
    int depth,
    String pathPrefix,
  ) {
    final pathKey = pathPrefix.isEmpty
        ? node.label
        : '$pathPrefix > ${node.label}';
    final indent = depth * 16.0;

    if (node.children.isNotEmpty) {
      final isExpanded = expandedKeys.contains(pathKey);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onToggle(pathKey),
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
            ...node.children.map(
              (child) =>
                  _buildStatsNode(context, scheme, child, depth + 1, pathKey),
            ),
            ...node.sessionGroups.asMap().entries.map(
              (entry) => _buildGroupRow(
                context,
                scheme,
                pathKey,
                entry.value,
                (depth + 1) * 16.0 - 16,
                entry.key,
              ),
            ),
          ],
        ],
      );
    }

    if (node.sessionGroups.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: indent, right: 16),
        title: Text(
          node.label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatDuration(node.total),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.primary),
        ),
      );
    }

    final isExpanded = expandedKeys.contains(pathKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onToggle(pathKey),
          child: ListTile(
            contentPadding: EdgeInsets.only(left: indent, right: 16),
            title: Text(
              node.label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatDuration(node.total),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.primary),
            ),
          ),
        ),
        if (isExpanded)
          ...node.sessionGroups.asMap().entries.map(
            (entry) => _buildGroupRow(
              context,
              scheme,
              pathKey,
              entry.value,
              indent,
              entry.key,
            ),
          ),
      ],
    );
  }

  Widget _buildGroupRow(
    BuildContext context,
    ColorScheme scheme,
    String pathKey,
    SessionGroup group,
    double indent,
    int groupIndex,
  ) {
    final taskKey = '$pathKey|$groupIndex';
    final isExpanded = expandedKeys.contains(taskKey);
    final totalText = t(currentLocale.value, 'stats_group_total')
        .replaceFirst('%s', group.label)
        .replaceFirst('%s', _formatDuration(group.total));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onToggle(taskKey),
          child: ListTile(
            contentPadding: EdgeInsets.only(left: indent + 16, right: 16),
            title: Text(
              totalText,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (isExpanded)
          ...group.records.map(
            (record) => _buildSessionTile(context, scheme, record, indent + 32),
          ),
      ],
    );
  }

  Widget _buildSessionTile(
    BuildContext context,
    ColorScheme scheme,
    Map<String, dynamic> record,
    double indent,
  ) {
    final startUtc = CategoryServiceExtension.startTimeFromRecord(record);
    final endUtc = CategoryServiceExtension.endTimeFromRecord(record);
    final status = (record['status'] as String? ?? '').toLowerCase();
    final endUtcOrNow =
        endUtc ??
        (status == 'running' ? DatabaseService.getPlanetaryNow() : null);
    final seconds =
        CategoryServiceExtension.recordDurationSecondsWithinDayFromTimestamps(
          record,
          selectedDate,
          DatabaseService.instance.settings.timezoneOffsetHours,
          DatabaseService.instance.settings.preferredTimeZone,
        );
    final startText = startUtc != null
        ? _formatTimeOfDay(_utcToDisplay(startUtc))
        : '–';
    final endText = endUtcOrNow != null
        ? _formatTimeOfDay(_utcToDisplay(endUtcOrNow))
        : '–';
    final rawTitle = (record['title'] as String?)?.trim();
    final title = rawTitle != null && rawTitle.isNotEmpty
        ? rawTitle
        : t(currentLocale.value, 'untitled');
    final sessionText = t(currentLocale.value, 'stats_session_line')
        .replaceFirst('%s', startText)
        .replaceFirst('%s', endText)
        .replaceFirst('%s', _formatDuration(Duration(seconds: seconds)))
        .replaceFirst('%s', title);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: indent, right: 16),
      title: Text(
        sessionText,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }
}
