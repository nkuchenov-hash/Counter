// ignore_for_file: avoid_print
part of '../database_service.dart';

final StreamController<List<PlanningTask>> _tasksController =
    StreamController<List<PlanningTask>>.broadcast();

/// Planning UI: manual refresh in addition to the 2s poll (after PATCH/cross-day optimistic).
final StreamController<void> _planningRefreshController =
    StreamController<void>.broadcast();

Timer? _planningNotifyNetworkDebounceTimer;
bool _planningRefreshWantsNetworkPump = false;
Future<void>? _plansRealtimeSubscribeFuture;
Future<void> Function()? _plansRealtimeUnsubscribe;

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
