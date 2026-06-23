import 'package:counter/data/models.dart';

/// Atomic render inputs for one Plans day — no staged/partial card frames (P0T).
class PlanCardRenderDto {
  const PlanCardRenderDto({
    required this.task,
    required this.planTrackedSeconds,
    required this.planEstimatedSeconds,
    required this.displayIsDone,
    required this.showPlay,
    required this.highlightAsRunning,
    required this.timeLabel,
    required this.tagsReady,
    required this.categoryReady,
  });

  final PlanningTask task;
  final int planTrackedSeconds;
  final int? planEstimatedSeconds;
  final bool displayIsDone;
  final bool showPlay;
  final bool highlightAsRunning;
  final String timeLabel;
  final bool tagsReady;
  final bool categoryReady;
}

class PlansDayRenderSnapshot {
  const PlansDayRenderSnapshot({
    required this.dateKey,
    required this.knownEmpty,
    required this.cards,
    required this.cacheSignature,
    required this.ready,
    this.missing = 'none',
  });

  final String dateKey;
  final bool knownEmpty;
  final List<PlanCardRenderDto> cards;
  final int cacheSignature;
  final bool ready;
  final String missing;
}

/// Atomic render inputs for one Timeline day (P0T).
class TimelineCardRenderDto {
  const TimelineCardRenderDto({
    required this.recordMap,
    required this.title,
    required this.categoryReady,
    required this.tagsReady,
  });

  final Map<String, dynamic> recordMap;
  final String title;
  final bool categoryReady;
  final bool tagsReady;
}

class TimelineDayRenderSnapshot {
  const TimelineDayRenderSnapshot({
    required this.dateKey,
    required this.knownEmpty,
    required this.cards,
    required this.cacheSignature,
    required this.ready,
    this.missing = 'none',
  });

  final String dateKey;
  final bool knownEmpty;
  final List<TimelineCardRenderDto> cards;
  final int cacheSignature;
  final bool ready;
  final String missing;
}

/// In-memory P0T render snapshot cache (data only — not widgets).
final class P0tRenderSnapshotCache {
  P0tRenderSnapshotCache._();
  static final P0tRenderSnapshotCache instance = P0tRenderSnapshotCache._();

  final Map<String, PlansDayRenderSnapshot> _plans = {};
  final Map<String, TimelineDayRenderSnapshot> _timeline = {};

  PlansDayRenderSnapshot? peekPlans(String dateKey) => _plans[dateKey];
  TimelineDayRenderSnapshot? peekTimeline(String dateKey) => _timeline[dateKey];

  void putPlans(PlansDayRenderSnapshot snap) => _plans[snap.dateKey] = snap;
  void putTimeline(TimelineDayRenderSnapshot snap) =>
      _timeline[snap.dateKey] = snap;

  int get plansCount => _plans.length;
  int get timelineCount => _timeline.length;

  void clearPlans() => _plans.clear();
  void clearTimeline() => _timeline.clear();
}

String p0tDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
