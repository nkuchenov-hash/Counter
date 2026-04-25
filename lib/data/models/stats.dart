// Part of lib/data/models.dart — BasicDayStats, StatsTreeNode, SessionGroup, StatsNode.
// Split per ROADMAP Tier 4.2 (April 2026).
part of '../models.dart';

class BasicDayStats {
  const BasicDayStats({
    required this.planTaskCount,
    required this.factDistinctPlansFromRecords,
    required this.planTimeSeconds,
    required this.factTimeSeconds,
    required this.plannedSecByCategory,
    required this.actualSecByCategory,
    required this.plansScheduledThisDay,
  });

  /// All planning rows whose [planningWallScheduleDateKey] is this day.
  final int planTaskCount;

  /// Distinct plan PocketBase ids appearing as [records.source_plan_id] on this wall day (with logged time).
  final int factDistinctPlansFromRecords;

  /// Sum of plan start→end durations for rows on this day (omits open-ended plans).
  final int planTimeSeconds;

  /// Sum of record durations attributed to this wall day.
  final int factTimeSeconds;

  final Map<int, int> plannedSecByCategory;
  final Map<int, int> actualSecByCategory;

  /// Plans scheduled on this day (for optional “no time logged” hints in UI).
  final List<PlanningTask> plansScheduledThisDay;
}

/// One node in the hierarchical stats tree.
class StatsTreeNode {
  const StatsTreeNode({
    required this.label,
    required this.totalSeconds,
    this.children = const [],
    this.records = const [],
    this.categoryId,
  });

  final String label;
  final int totalSeconds;
  final List<StatsTreeNode> children;
  final List<Map<String, dynamic>> records;
  final int? categoryId;

  Duration get total => Duration(seconds: totalSeconds);
}

/// Records grouped by normalized title at a leaf category.
class SessionGroup {
  const SessionGroup({
    required this.label,
    required this.totalSeconds,
    required this.records,
    required this.actualTitles,
  });
  final String label;
  final int totalSeconds;
  final List<Map<String, dynamic>> records;
  final Set<String> actualTitles;
  Duration get total => Duration(seconds: totalSeconds);
}

/// Recursive stats node: full category path, with children and session groups.
class StatsNode {
  const StatsNode({
    required this.label,
    required this.totalSeconds,
    this.children = const [],
    this.sessionGroups = const [],
  });

  final String label;
  final int totalSeconds;
  final List<StatsNode> children;
  final List<SessionGroup> sessionGroups;

  Duration get total => Duration(seconds: totalSeconds);

  bool get isLeaf => children.isEmpty;
}

// --- Helpers (tag path, opacity). Pure logic on CategoryRule. ---
