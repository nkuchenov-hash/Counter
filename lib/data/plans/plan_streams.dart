// ignore_for_file: avoid_print
part of '../database_service.dart';

final StreamController<List<PlanningTask>> _tasksController =
    StreamController<List<PlanningTask>>.broadcast();

/// Planning UI: manual refresh in addition to the 2s poll (after PATCH/cross-day optimistic).
final StreamController<void> _planningRefreshController =
    StreamController<void>.broadcast();

Timer? _planningNotifyNetworkDebounceTimer;
bool _planningRefreshWantsNetworkPump = false;

int _planningStreamIdSeq = 0;
final Map<String, _PlanningDayStreamHub> _planningStreamHubs = {};

/// Shared planning day stream — one hub per (day, global-listen) key; ref-counted listeners.
final class _PlanningDayStreamHub {
  _PlanningDayStreamHub({
    required this.streamId,
    required this.dayKey,
    required this.wallDay,
    required this.listenGlobal,
  });

  final String streamId;
  final String dayKey;
  final DateTime wallDay;
  final bool listenGlobal;
  int refCount = 0;
  final StreamController<List<PlanningTask>> controller =
      StreamController<List<PlanningTask>>.broadcast();
  StreamSubscription<void>? _pokeSub;
  bool _pumpBusy = false;
  bool _disposed = false;

  void acquire(DatabaseService db) {
    refCount++;
    planStreamLifecycleLog(
      'create streamId=$streamId user=${db.currentProfileId ?? '-'} '
      'date=$dayKey mode=listenGlobal=$listenGlobal '
      'activeForDay=${_planningStreamHubs.length}',
    );
    if (refCount == 1) {
      _bind(db);
    }
  }

  void release() {
    refCount--;
    if (refCount <= 0) {
      planStreamLifecycleLog('dispose streamId=$streamId');
      _disposeHub();
    }
  }

  void _bind(DatabaseService db) {
    _emitFromCache(db);
    unawaited(_pump(db, network: true));
    if (!listenGlobal) return;
    _pokeSub = _planningRefreshController.stream.listen((_) {
      final wantsNetwork = _planningRefreshWantsNetworkPump;
      if (wantsNetwork) {
        _planningRefreshWantsNetworkPump = false;
      }
      final stale =
          wantsNetwork ||
          _allPlansUserCache.isEmpty ||
          _allPlansUserCacheFetchedAt == null ||
          DateTime.now().difference(_allPlansUserCacheFetchedAt!) >
              _allPlansUserCacheFreshTtl;
      unawaited(_pump(db, network: stale));
    });
  }

  void _emitFromCache(DatabaseService db) {
    if (_disposed || controller.isClosed) return;
    List<PlanningTask> base = [];
    if (_allPlansUserCache.isNotEmpty) {
      base = db._filterPlansForWallDay(_allPlansUserCache, wallDay);
    }
    final merged = db._mergePlanningOptimistic(dayKey, base);
    db._logPlanDupTraceLayer(source: 'stream', tasks: merged, dayKey: dayKey);
    _logPlanningStreamEmit(merged);
    controller.add(merged);
  }

  Future<void> _pump(DatabaseService db, {required bool network}) async {
    _emitFromCache(db);
    if (!network || _pumpBusy || _disposed || controller.isClosed) return;
    _pumpBusy = true;
    try {
      List<PlanningTask> tasks;
      try {
        tasks = await db._fetchPlanningTasksForDate(wallDay);
      } catch (_) {
        tasks = <PlanningTask>[];
      }
      if (!_disposed && !controller.isClosed) {
        final merged = db._mergePlanningOptimistic(dayKey, tasks);
        db._logPlanDupTraceLayer(
          source: 'stream',
          tasks: merged,
          dayKey: dayKey,
        );
        _logPlanningStreamEmit(merged);
        controller.add(merged);
      }
    } finally {
      _pumpBusy = false;
    }
  }

  void _logPlanningStreamEmit(List<PlanningTask> merged) {
    final ids = merged.map((t) => t.planRowIdForBackend).toList();
    final unique = ids.toSet().length;
    planStreamLifecycleLog(
      'emit streamId=$streamId total=${merged.length} uniqueIds=$unique '
      'duplicateIds=${merged.length - unique}',
    );
  }

  void _disposeHub() {
    if (_disposed) return;
    _disposed = true;
    _pokeSub?.cancel();
    _pokeSub = null;
    _planningStreamHubs.remove('$dayKey|$listenGlobal');
    if (!controller.isClosed) {
      unawaited(controller.close());
    }
  }

  void emitCachedPlans(DatabaseService db) => _emitFromCache(db);
}

/// Planning/list refresh signals and shared day-stream orchestration.
extension PlanStreamsExtension on DatabaseService {
  /// Ping planning/list subscribers. UI streams emit cache+overlay first; network refresh is debounced.
  void notifyPlanningRefresh({
    bool scheduleNetworkRefresh = true,
    bool pumpNetworkNow = false,
  }) {
    if (pumpNetworkNow) {
      _planningRefreshWantsNetworkPump = true;
    }
    if (!_planningRefreshController.isClosed) {
      _planningRefreshController.add(null);
    }
    _requestPlanAlarmReschedule();
    _refreshPlansWarmSnapshotsAfterCacheMutation();
    persistPlansWarmSnapshotsToDisk();
    if (scheduleNetworkRefresh) {
      _planningNotifyNetworkDebounceTimer?.cancel();
      _planningNotifyNetworkDebounceTimer = Timer(
        const Duration(milliseconds: 400),
        () {
          unawaited(() async {
            await _ensureAllPlansUserCacheFresh(force: true);
            _planningRefreshWantsNetworkPump = true;
            if (!_planningRefreshController.isClosed) {
              _planningRefreshController.add(null);
            }
          }());
        },
      );
    }
  }

  void _pokeAllPlanningStreamHubsFromCache() {
    for (final hub in _planningStreamHubs.values) {
      hub.emitCachedPlans(this);
    }
  }

  /// Stats / Plan-vs-fact audit: listen to refresh planning data (same signal as [notifyPlanningRefresh]).
  Stream<void> get planningRefreshNotifications =>
      _planningRefreshController.stream;

  Stream<List<PlanningTask>> get tasksStream => Stream.multi((c) {
    c.add(List.from(_tasksCache));
    _tasksController.stream.listen(c.add, onError: c.addError);
  });

  /// Broadcast when planning cache should be re-read by UI (optimistic PATCH, realtime, etc.).
  Stream<void> get planningRefreshEvents => _planningRefreshController.stream;

  /// Planning list stream. **No periodic polling** (PageView keeps many days alive).
  /// [listenToGlobalPlanningRefresh]: only the **visible** planning day should be `true` so [notifyPlanningRefresh]
  /// does not fan out identical GETs to every off-screen [PlanningPage].
  ///
  /// One shared hub per (wall-day, global-listen) — ref-counted; replaces snapshot on emit (never append).
  Stream<List<PlanningTask>> planningStream(
    DateTime selectedDate, {
    bool listenToGlobalPlanningRefresh = true,
  }) {
    final targetDayStr =
        '${selectedDate.year}-${_two(selectedDate.month)}-${_two(selectedDate.day)}';
    final hubKey = '$targetDayStr|$listenToGlobalPlanningRefresh';
    final hub = _planningStreamHubs.putIfAbsent(
      hubKey,
      () => _PlanningDayStreamHub(
        streamId: 'ps-${++_planningStreamIdSeq}',
        dayKey: targetDayStr,
        wallDay: selectedDate,
        listenGlobal: listenToGlobalPlanningRefresh,
      ),
    );
    return Stream.multi((controller) {
      hub.acquire(this);
      final sub = hub.controller.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      if (_allPlansUserCache.isEmpty) {
        unawaited(() async {
          final offline = await _loadPlanningTasksDayCache(targetDayStr);
          if (!hub.controller.isClosed && offline.isNotEmpty) {
            final merged = _mergePlanningOptimistic(targetDayStr, offline);
            hub.controller.add(merged);
          }
        }());
      }
      controller.onCancel = () {
        sub.cancel();
        hub.release();
      };
    });
  }
}
