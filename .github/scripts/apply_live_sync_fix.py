from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding='utf-8')


def replace_once(text: str, old: str, new: str, *, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


def function_span(text: str, marker: str) -> tuple[int, int]:
    start = text.find(marker)
    if start < 0:
        raise RuntimeError(f'function marker not found: {marker}')
    brace = text.find('{', start)
    if brace < 0:
        raise RuntimeError(f'opening brace not found: {marker}')
    depth = 0
    quote: str | None = None
    escaped = False
    i = brace
    while i < len(text):
        ch = text[i]
        if quote is not None:
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == quote:
                quote = None
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            i += 1
            continue
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                return start, i + 1
        i += 1
    raise RuntimeError(f'unclosed function: {marker}')


def patch_function(path: str, marker: str, transform) -> None:
    text = read(path)
    start, end = function_span(text, marker)
    original = text[start:end]
    updated = transform(original)
    if updated == original:
        raise RuntimeError(f'{path}:{marker}: transform made no change')
    write(path, text[:start] + updated + text[end:])


def patch_plan_mutation_outbox() -> None:
    path = 'lib/data/local_sync/plan_mutation_outbox.dart'
    text = read(path)
    text = replace_once(
        text,
        "  static bool _isDeleteItem(Map<String, dynamic> item) {\n"
        "    final kind = (item['kind'] ?? '').toString();\n"
        "    final op = (item['operationType'] ?? '').toString();\n"
        "    return kind == kindPlanDelete || op == 'delete';\n"
        "  }\n\n"
        "  static bool _isUpdateItem(Map<String, dynamic> item) =>\n",
        "  static bool _isDeleteItem(Map<String, dynamic> item) {\n"
        "    final kind = (item['kind'] ?? '').toString();\n"
        "    final op = (item['operationType'] ?? '').toString();\n"
        "    return kind == kindPlanDelete || op == 'delete';\n"
        "  }\n\n"
        "  static bool _isCreateItem(Map<String, dynamic> item) =>\n"
        "      (item['kind'] ?? '').toString() == kindPlanCreate;\n\n"
        "  static bool _isUpdateItem(Map<String, dynamic> item) =>\n",
        label='plan outbox create helper',
    )
    text = replace_once(
        text,
        "      if (_isDeleteItem(item)) {\n",
        "      // Write-ahead create may be staged again with an auth/network error.\n"
        "      // Keep one durable create per business id and preserve its original FIFO slot.\n"
        "      if (_isCreateItem(item) && biz.isNotEmpty) {\n"
        "        final existingCreateIndex = out.indexWhere(\n"
        "          (e) => _bizKey(e) == biz && _isCreateItem(e),\n"
        "        );\n"
        "        if (existingCreateIndex >= 0) {\n"
        "          final existing = out[existingCreateIndex];\n"
        "          item['operationId'] = existing['operationId'];\n"
        "          item['createdAt'] = existing['createdAt'];\n"
        "          out[existingCreateIndex] = item;\n"
        "          continue;\n"
        "        }\n"
        "      }\n\n"
        "      if (_isDeleteItem(item)) {\n",
        label='plan outbox create coalesce',
    )
    write(path, text)


def patch_plan_outbox_helpers() -> None:
    path = 'lib/data/plans/plan_outbox_helpers.dart'
    text = read(path)
    helper = """
  /// Durable write-ahead staging for a plan edit. The optimistic cache is already
  /// visible before this awaits SharedPreferences; PocketBase network I/O starts only
  /// after the mutation survives process death.
  Future<void> _stagePlanUpdateWriteAhead({
    required String originalInput,
    required String businessId,
    required Map<String, dynamic> patchBody,
    String? pocketBaseId,
    List<Tag>? tags,
  }) async {
    final scalarBody = Map<String, dynamic>.from(patchBody);
    scalarBody.remove('user_id');
    List<String>? tagIds;
    if (tags != null) {
      tagIds = await _pbTagRecordIdsFromTags(tags);
    }
    await _enqueuePlanUpdateMutation(
      originalInput: originalInput,
      businessId: businessId,
      patchFields: scalarBody,
      pocketBaseId: pocketBaseId,
      tagsLinkPbIds: tagIds,
    );
    await offlineSync.refreshPendingCount();
  }

"""
    text = replace_once(
        text,
        '  // --- Immediate update/delete network phase (not flush/replay) ---\n',
        helper + '  // --- Immediate update/delete network phase (not flush/replay) ---\n',
        label='insert write-ahead helper',
    )
    write(path, text)

    def transform(fn: str) -> str:
        fn = replace_once(
            fn,
            "      notifyPlanningRefresh(scheduleNetworkRefresh: false);\n"
            "      unawaited(offlineSync.refreshPendingCount());\n"
            "      return true;\n",
            "      notifyPlanningRefresh(scheduleNetworkRefresh: false);\n"
            "      await _cancelPendingPlanMutationsForBusinessId(businessId);\n"
            "      await offlineSync.refreshPendingCount();\n"
            "      return true;\n",
            label='update success clears write-ahead',
        )
        fn = replace_once(
            fn,
            "        notifyPlanningRefresh(scheduleNetworkRefresh: false);\n"
            "        if (!suppressAppSnack) AppSnack.failed();\n"
            "        return false;\n",
            "        notifyPlanningRefresh(scheduleNetworkRefresh: false);\n"
            "        await _cancelPendingPlanMutationsForBusinessId(businessId);\n"
            "        await offlineSync.refreshPendingCount();\n"
            "        if (!suppressAppSnack) AppSnack.failed();\n"
            "        return false;\n",
            label='update 404 clears write-ahead',
        )
        fn = replace_once(
            fn,
            "      if (!suppressAppSnack) AppSnack.failed();\n"
            "      return false;\n"
            "    } catch (e, st) {\n",
            "      await _cancelPendingPlanMutationsForBusinessId(businessId);\n"
            "      await offlineSync.refreshPendingCount();\n"
            "      if (!suppressAppSnack) AppSnack.failed();\n"
            "      return false;\n"
            "    } catch (e, st) {\n",
            label='update validation clears write-ahead',
        )
        fn = replace_once(
            fn,
            "      if (!suppressAppSnack) AppSnack.failed();\n"
            "      return false;\n"
            "    }\n",
            "      await _cancelPendingPlanMutationsForBusinessId(businessId);\n"
            "      await offlineSync.refreshPendingCount();\n"
            "      if (!suppressAppSnack) AppSnack.failed();\n"
            "      return false;\n"
            "    }\n",
            label='update nonretriable exception clears write-ahead',
        )
        return fn

    patch_function(path, '  Future<bool> _patchPlanUpdateNetworkPhase({', transform)


def patch_plan_service() -> None:
    path = 'lib/data/plan_service.dart'

    def create_transform(fn: str) -> str:
        fn = replace_once(
            fn,
            "    try {\n"
            "      final record = await _pb\n"
            "          .collection(PbCollections.plans)\n"
            "          .create(body: body);\n",
            "    // Write-ahead: persist the create intent before the asynchronous POST.\n"
            "    await _enqueuePlanCreateMutation(\n"
            "      body,\n"
            "      businessId: clientPlanId,\n"
            "    );\n"
            "    await offlineSync.refreshPendingCount();\n"
            "    try {\n"
            "      final record = await _pb\n"
            "          .collection(PbCollections.plans)\n"
            "          .create(body: body);\n",
            label='create write-ahead before POST',
        )
        fn = replace_once(
            fn,
            "      _allPlansUserCacheFetchedAt = DateTime.now();\n"
            "      clearOptimisticPlanningForPlanRow(optimisticId);\n",
            "      _allPlansUserCacheFetchedAt = DateTime.now();\n"
            "      await _cancelPendingPlanMutationsForBusinessId(clientPlanId);\n"
            "      await offlineSync.refreshPendingCount();\n"
            "      clearOptimisticPlanningForPlanRow(optimisticId);\n",
            label='create success clears write-ahead',
        )
        fn = replace_once(
            fn,
            "      clearOptimisticPlanningForPlanRow(optimisticId);\n"
            "      notifyPlanningRefresh(scheduleNetworkRefresh: false);\n"
            "      return false;\n",
            "      await _cancelPendingPlanMutationsForBusinessId(clientPlanId);\n"
            "      await offlineSync.refreshPendingCount();\n"
            "      clearOptimisticPlanningForPlanRow(optimisticId);\n"
            "      notifyPlanningRefresh(scheduleNetworkRefresh: false);\n"
            "      return false;\n",
            label='create nonretriable clears write-ahead',
        )
        return fn

    patch_function(path, '  Future<bool> _addPlanningTaskPocket(', create_transform)

    def update_transform(fn: str) -> str:
        target = (
            "    final shadowPb = _tryResolvePlanPbIdFromCacheOnly(\n"
            "      rid,\n"
            "      planBusinessId: planBusinessId,\n"
            "    );\n"
        )
        replacement = target + (
            "    await _stagePlanUpdateWriteAhead(\n"
            "      originalInput: rid,\n"
            "      businessId: businessId,\n"
            "      patchBody: patchBody,\n"
            "      pocketBaseId: shadowPb,\n"
            "      tags: tags,\n"
            "    );\n"
        )
        return replace_once(
            fn,
            target,
            replacement,
            label='update write-ahead before network dispatch',
        )

    patch_function(path, '  Future<bool> updatePlanningTask(', update_transform)

    def realtime_transform(fn: str) -> str:
        old = """      final rec = e.record;
      if (rec == null) return;
      unawaited(() async {
        try {
          final tagCatalog = await _fetchPlanAndListTagCatalog();
          final task = _planningTaskFromPocketRecord(
            rec,
            pocketTagCatalog: tagCatalog,
          );
          _upsertPlanInUserCache(task);
          _allPlansUserCacheFetchedAt = DateTime.now();
          final biz = _planBusinessUuidFromTask(task);
          if (biz != null && biz.isNotEmpty) {
            clearOptimisticPlanningForPlanRow('optimistic-$biz');
          }
          clearOptimisticPlanningForPlanRow(task.planRowIdForBackend);
          notifyPlanningRefresh(scheduleNetworkRefresh: false);
        } catch (_) {}
      }());
"""
        new = """      final rec = e.record;
      if (rec == null) return;
      // Realtime delivery must never wait for another HTTP request. The event
      // is merged immediately using the current tag catalog/expand payload.
      try {
        final task = _planningTaskFromPocketRecord(
          rec,
          pocketTagCatalog: _userTagsCatalogCache,
        );
        _upsertPlanInUserCache(task);
        _allPlansUserCacheFetchedAt = DateTime.now();
        final biz = _planBusinessUuidFromTask(task);
        if (biz != null && biz.isNotEmpty) {
          clearOptimisticPlanningForPlanRow('optimistic-$biz');
        }
        clearOptimisticPlanningForPlanRow(task.planRowIdForBackend);
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('plans realtime merge failed: $error\\n$stackTrace');
        }
      }
"""
        return replace_once(fn, old, new, label='plan realtime immediate merge')

    patch_function(path, '  void _onPbPlansSubscriptionEvent(', realtime_transform)


def patch_catalog_realtime() -> None:
    part_path = 'lib/data/realtime/catalog_realtime.dart'
    part_file = ROOT / part_path
    part_file.parent.mkdir(parents=True, exist_ok=True)
    part_file.write_text("""part of '../database_service.dart';

Future<void> Function()? _categoriesRealtimeUnsubscribe;
Future<void> Function()? _tagsRealtimeUnsubscribe;
Future<void> Function()? _profileRealtimeUnsubscribe;
Future<void>? _catalogRealtimeSubscribeFuture;
Timer? _catalogRealtimeReconnectTimer;
Timer? _categoryRealtimeRefreshDebounce;
Timer? _tagRealtimeRefreshDebounce;
Timer? _profileRealtimeRefreshDebounce;
int _catalogRealtimeFailureStreak = 0;

extension CatalogRealtimeExtension on DatabaseService {
  String? _catalogOwnerFilter() {
    final uid = _userIdForWhere?.trim() ?? '';
    if (uid.isEmpty) return null;
    return 'user_id = "${_escapeForPbFilter(uid)}"';
  }

  void _onCategoryRealtimeEvent(RecordSubscriptionEvent _) {
    _categoryRealtimeRefreshDebounce?.cancel();
    _categoryRealtimeRefreshDebounce = Timer(
      const Duration(milliseconds: 40),
      () => unawaited(_loadRulesFromNoco()),
    );
  }

  void _onTagRealtimeEvent(RecordSubscriptionEvent _) {
    _tagRealtimeRefreshDebounce?.cancel();
    _tagRealtimeRefreshDebounce = Timer(
      const Duration(milliseconds: 40),
      () => unawaited(() async {
        await fetchTagsForCurrentUser(scope: TagCatalogScope.plan);
        notifyTagsCatalogChanged();
      }()),
    );
  }

  void _onProfileRealtimeEvent(RecordSubscriptionEvent e) {
    final authId = _userIdForWhere?.trim() ?? '';
    final rowId = e.record?.id.trim() ?? '';
    if (authId.isEmpty || (rowId.isNotEmpty && rowId != authId)) return;
    _profileRealtimeRefreshDebounce?.cancel();
    _profileRealtimeRefreshDebounce = Timer(
      const Duration(milliseconds: 40),
      () => unawaited(_loadSettingsFromNoco()),
    );
  }

  Future<void> _cancelCatalogRealtimeSubscriptions() async {
    final callbacks = <Future<void> Function()?>[
      _categoriesRealtimeUnsubscribe,
      _tagsRealtimeUnsubscribe,
      _profileRealtimeUnsubscribe,
    ];
    _categoriesRealtimeUnsubscribe = null;
    _tagsRealtimeUnsubscribe = null;
    _profileRealtimeUnsubscribe = null;
    for (final callback in callbacks) {
      if (callback == null) continue;
      try {
        await callback();
      } catch (_) {}
    }
  }

  Future<void> _startCatalogRealtimeSubscriptions() async {
    final existing = _catalogRealtimeSubscribeFuture;
    if (existing != null) return existing;
    final future = _startCatalogRealtimeSubscriptionsBody();
    _catalogRealtimeSubscribeFuture = future;
    try {
      await future;
    } finally {
      _catalogRealtimeSubscribeFuture = null;
    }
  }

  Future<void> _startCatalogRealtimeSubscriptionsBody() async {
    await _cancelCatalogRealtimeSubscriptions();
    if (!_hasAuthenticatedUserId || isPbRealtimeUnavailable) return;
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return;
      final filter = _catalogOwnerFilter();
      final authId = _userIdForWhere?.trim() ?? '';
      if (filter == null || authId.isEmpty) return;
      _categoriesRealtimeUnsubscribe = await _pb
          .collection(PbCollections.categories)
          .subscribe('*', _onCategoryRealtimeEvent, filter: filter);
      _tagsRealtimeUnsubscribe = await _pb
          .collection(PbCollections.tags)
          .subscribe('*', _onTagRealtimeEvent, filter: filter);
      _profileRealtimeUnsubscribe = await _pb
          .collection(PbCollections.profiles)
          .subscribe(authId, _onProfileRealtimeEvent);
      _catalogRealtimeFailureStreak = 0;
      _catalogRealtimeReconnectTimer?.cancel();
      _catalogRealtimeReconnectTimer = null;
    } catch (error) {
      await _cancelCatalogRealtimeSubscriptions();
      _handleRealtimeSubscribeFailure(error, source: 'catalogs');
      _scheduleCatalogRealtimeReconnectAfterFailure();
    }
  }

  void _scheduleCatalogRealtimeReconnectAfterFailure() {
    if (!_hasAuthenticatedUserId || isPbRealtimeUnavailable) return;
    _catalogRealtimeReconnectTimer?.cancel();
    final index = _catalogRealtimeFailureStreak.clamp(
      0,
      DatabaseService._kRealtimeBackoffSeconds.length - 1,
    );
    final delay = Duration(
      seconds: DatabaseService._kRealtimeBackoffSeconds[index],
    );
    if (_catalogRealtimeFailureStreak <
        DatabaseService._kRealtimeBackoffSeconds.length) {
      _catalogRealtimeFailureStreak++;
    }
    _catalogRealtimeReconnectTimer = Timer(delay, () {
      _catalogRealtimeReconnectTimer = null;
      unawaited(_startCatalogRealtimeSubscriptions());
    });
  }

  Future<void> ensureCatalogRealtimeBridge() async {
    _catalogRealtimeReconnectTimer?.cancel();
    _catalogRealtimeReconnectTimer = null;
    _catalogRealtimeFailureStreak = 0;
    await _startCatalogRealtimeSubscriptions();
  }
}
""", encoding='utf-8')

    path = 'lib/data/database_service.dart'
    text = read(path)
    text = replace_once(
        text,
        "part 'plans/plan_ai_parse_helpers.dart';\npart 'plan_service.dart';\n",
        "part 'plans/plan_ai_parse_helpers.dart';\npart 'realtime/catalog_realtime.dart';\npart 'plan_service.dart';\n",
        label='database service catalog realtime part',
    )
    write(path, text)


def patch_db_core() -> None:
    path = 'lib/data/db_core.dart'
    text = read(path)
    text = replace_once(
        text,
        "      _scheduleRecordsRealtimeReconnectAfterFailure();\n"
        "      _schedulePlansRealtimeReconnectAfterFailure();\n",
        "      _scheduleRecordsRealtimeReconnectAfterFailure();\n"
        "      _schedulePlansRealtimeReconnectAfterFailure();\n"
        "      _scheduleCatalogRealtimeReconnectAfterFailure();\n",
        label='onDisconnect catalog reconnect',
    )
    old_unavailable = """    _realtimeEndpointUnavailableUntil =
        DateTime.now().add(const Duration(minutes: 30));
    planStreamLifecycleLog(
      'realtimeSubscribe status=error code=404 source=$source '
      'fallback=fetchUntil=${_realtimeEndpointUnavailableUntil!.toIso8601String()}',
    );
    unawaited(_cancelRecordsRealtimeSubscription());
    unawaited(_cancelPlansRealtimeSubscription());
    offlineSync.reconcileStuckSyncingBanner(
      syncFlushInFlight: isSyncFlushInFlight,
    );
"""
    new_unavailable = """    const retryDelay = Duration(seconds: 30);
    _realtimeEndpointUnavailableUntil = DateTime.now().add(retryDelay);
    planStreamLifecycleLog(
      'realtimeSubscribe status=error code=404 source=$source '
      'retryAt=${_realtimeEndpointUnavailableUntil!.toIso8601String()}',
    );
    unawaited(_cancelRecordsRealtimeSubscription());
    unawaited(_cancelPlansRealtimeSubscription());
    unawaited(_cancelCatalogRealtimeSubscriptions());
    _recordsRealtimeReconnectTimer?.cancel();
    _plansRealtimeReconnectTimer?.cancel();
    _catalogRealtimeReconnectTimer?.cancel();
    _recordsRealtimeReconnectTimer = Timer(retryDelay, () {
      _recordsRealtimeReconnectTimer = null;
      _realtimeEndpointUnavailableUntil = null;
      if (!_hasAuthenticatedUserId) return;
      unawaited(_startRecordsRealtimeSubscription());
      unawaited(_startPlansRealtimeSubscription());
      unawaited(_startCatalogRealtimeSubscriptions());
    });
    offlineSync.reconcileStuckSyncingBanner(
      syncFlushInFlight: isSyncFlushInFlight,
    );
"""
    text = replace_once(
        text,
        old_unavailable,
        new_unavailable,
        label='404 realtime retry instead of 30 minute silence',
    )
    text = replace_once(
        text,
        "    unawaited(_cancelPlansRealtimeSubscription());\n"
        "    _allPlansUserCache = [];\n",
        "    unawaited(_cancelPlansRealtimeSubscription());\n"
        "    unawaited(_cancelCatalogRealtimeSubscriptions());\n"
        "    _catalogRealtimeReconnectTimer?.cancel();\n"
        "    _catalogRealtimeReconnectTimer = null;\n"
        "    _allPlansUserCache = [];\n",
        label='signout catalog realtime cleanup',
    )
    write(path, text)

    def deferred_transform(fn: str) -> str:
        anchor = """    final projected = getProjectedToday();
    final timelineToday = getTimelineDeviceLocalToday();
"""
        early = anchor + """    // Subscribe first so cross-device changes arriving during catch-up are not missed.
    if (!_pbHttpBackoffActive) {
      try {
        await Future.wait<void>([
          _startRecordsRealtimeSubscription(),
          _startPlansRealtimeSubscription(),
          _startCatalogRealtimeSubscriptions(),
        ]);
      } catch (_) {}
    }
"""
        fn = replace_once(
            fn,
            anchor,
            early,
            label='boot realtime before catch-up',
        )
        late = """    try {
      await _startRecordsRealtimeSubscription();
    } catch (_) {}
    unawaited(
      _startPlansRealtimeSubscription().catchError((Object e, StackTrace _) {
        _handleRealtimeSubscribeFailure(e, source: 'plans-boot');
      }),
    );
"""
        fn = replace_once(
            fn,
            late,
            '',
            label='remove late boot realtime restart',
        )
        return fn

    patch_function(path, '  Future<void> _runDeferredBootWorkAfterFirstShell() async {', deferred_transform)

    def foreground_transform(_: str) -> str:
        return """  Future<void> refreshForegroundData() async {
    if (!(currentProfileId?.isNotEmpty ?? false)) return;
    if (!_isInitialized) return;
    await offlineSync.bootstrapFromOutboxes(
      pbBackoffActive: _pbHttpBackoffActive,
    );
    // Re-arm push channels before flush/catch-up. The following fetch is a one-shot
    // reconciliation for events missed while the app was suspended, never polling.
    if (!_pbHttpBackoffActive) {
      try {
        await Future.wait<void>([
          _startRecordsRealtimeSubscription(),
          _startPlansRealtimeSubscription(),
          _startCatalogRealtimeSubscriptions(),
        ]);
      } catch (_) {}
    }
    await flushPendingLocalMutations();
    if (_pbHttpBackoffActive) return;
    try {
      _lastSuccessfulRecordsNetworkFetchAt = null;
      await _fetchRecordsIntoCache(forceNetwork: true);
      await _reconcileDuplicatePrimaryRunningRecords();
      await _ensureAllPlansUserCacheFresh(force: true);
      await _loadPlanningTasksForToday();
      notifyPlanningRefresh(scheduleNetworkRefresh: false, pumpNetworkNow: true);
    } catch (_) {}
  }"""

    patch_function(path, '  Future<void> refreshForegroundData() async {', foreground_transform)


def patch_edit_sheet_lifecycle() -> None:
    path = 'lib/features/shared/planning_task_edit_sheet.dart'
    text = read(path)
    text = replace_once(
        text,
        "class PlanningTaskEditSheetState extends State<PlanningTaskEditSheet>\n"
        "    with SingleTickerProviderStateMixin {\n",
        "class PlanningTaskEditSheetState extends State<PlanningTaskEditSheet>\n"
        "    with SingleTickerProviderStateMixin, WidgetsBindingObserver {\n",
        label='edit sheet lifecycle observer mixin',
    )
    text = replace_once(
        text,
        "  void initState() {\n"
        "    super.initState();\n",
        "  void initState() {\n"
        "    super.initState();\n"
        "    WidgetsBinding.instance.addObserver(this);\n",
        label='edit sheet register lifecycle observer',
    )
    text = replace_once(
        text,
        "  void dispose() {\n"
        "    if (_isPersistedPlan) {\n",
        "  void dispose() {\n"
        "    WidgetsBinding.instance.removeObserver(this);\n"
        "    if (_isPersistedPlan) {\n",
        label='edit sheet remove lifecycle observer',
    )
    lifecycle = """
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    _flushDirtyPlanDraftForLifecycle();
  }

  void _flushDirtyPlanDraftForLifecycle() {
    if (!_isPersistedPlan || !_planAutosaveGate.isDirty) return;
    if (DatabaseService.instance.planningTaskIsRecurringForScope(
          _baselineTask,
        ) &&
        _recurrenceEditScopeChosen == null) {
      // Recurring edits still require the explicit scope decision; never guess
      // while the app is being backgrounded.
      return;
    }
    _planAutosaveGate.flush(() {
      final latest = _buildDraftTask();
      if (latest == null) return;
      _applyPlanDraftLocally(latest);
      unawaited(_syncPlanDraftToNetwork(latest));
    });
  }

"""
    text = replace_once(
        text,
        "  void _applyFuzzyCategoryFromTitle(String title) {\n",
        lifecycle + "  void _applyFuzzyCategoryFromTitle(String title) {\n",
        label='edit sheet lifecycle flush',
    )
    write(path, text)


def add_tests() -> None:
    path = ROOT / 'test/live_sync_contract_test.dart'
    path.write_text("""import 'dart:io';

import 'package:counter/data/local_sync/plan_mutation_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('write-ahead create is durable and duplicate staging coalesces', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await PlanMutationOutbox.enqueue(
      prefs,
      PlanMutationOutbox.newPlanCreateItem(
        businessId: 'plan-1',
        payload: <String, dynamic>{'plan_id': 'plan-1', 'title': 'Draft'},
      ),
    );
    await PlanMutationOutbox.enqueue(
      prefs,
      PlanMutationOutbox.newPlanCreateItem(
        businessId: 'plan-1',
        payload: <String, dynamic>{'plan_id': 'plan-1', 'title': 'Draft'},
        error: 503,
      ),
    );
    final queue = await PlanMutationOutbox.load(prefs);
    expect(queue, hasLength(1));
    expect(queue.single['businessId'], 'plan-1');
    expect(queue.single['lastError'], '503');
  });

  test('plan create and update stage outbox before PocketBase network', () {
    final service = File('lib/data/plan_service.dart').readAsStringSync();
    final outbox = File('lib/data/plans/plan_outbox_helpers.dart')
        .readAsStringSync();
    final createStart = service.indexOf('Future<bool> _addPlanningTaskPocket');
    final createStage = service.indexOf(
      'await _enqueuePlanCreateMutation(',
      createStart,
    );
    final createPost = service.indexOf('.create(body: body)', createStart);
    expect(createStage, greaterThan(createStart));
    expect(createStage, lessThan(createPost));

    final updateStart = service.indexOf('Future<bool> updatePlanningTask(');
    final updateStage = service.indexOf(
      'await _stagePlanUpdateWriteAhead(',
      updateStart,
    );
    final updateDispatch = service.indexOf(
      '_patchPlanUpdateNetworkPhase(',
      updateStage,
    );
    expect(updateStage, greaterThan(updateStart));
    expect(updateStage, lessThan(updateDispatch));
    expect(outbox, contains('await _cancelPendingPlanMutationsForBusinessId(businessId)'));
  });

  test('realtime is push-first and plan events do not perform tag HTTP fetch', () {
    final service = File('lib/data/plan_service.dart').readAsStringSync();
    final handlerStart = service.indexOf('void _onPbPlansSubscriptionEvent(');
    final handlerEnd = service.indexOf(
      'Future<void> _cancelPlansRealtimeSubscription()',
      handlerStart,
    );
    final handler = service.substring(handlerStart, handlerEnd);
    expect(handler, isNot(contains('_fetchPlanAndListTagCatalog')));
    expect(handler, contains('pocketTagCatalog: _userTagsCatalogCache'));

    final core = File('lib/data/db_core.dart').readAsStringSync();
    final foregroundStart = core.indexOf('Future<void> refreshForegroundData()');
    final foregroundEnd = core.indexOf(
      'Future<void> flushPendingLocalMutations()',
      foregroundStart,
    );
    final foreground = core.substring(foregroundStart, foregroundEnd);
    expect(
      foreground.indexOf('_startRecordsRealtimeSubscription()'),
      lessThan(foreground.indexOf('_fetchRecordsIntoCache(forceNetwork: true)')),
    );
    expect(foreground, isNot(contains('Timer.periodic')));

    final catalogs = File('lib/data/realtime/catalog_realtime.dart')
        .readAsStringSync();
    expect(catalogs, contains('PbCollections.categories'));
    expect(catalogs, contains('PbCollections.tags'));
    expect(catalogs, contains('PbCollections.profiles'));
    expect(catalogs, isNot(contains('Timer.periodic')));
  });
}
""", encoding='utf-8')


def patch_changelog() -> None:
    path = 'CHANGELOG.md'
    text = read(path)
    entry = """## [2026-08-05] - Push-first multi-device sync reliability [shipped]\n\n* **Plans/Lists durability:** create and edit mutations now use a local write-ahead outbox before PocketBase POST/PATCH; successful server confirmation clears the staged mutation, while auth/network failures keep one coalesced replay item.\n* **PocketBase realtime:** plan events merge immediately without a tag-catalog HTTP round trip; records, plans, categories, tags, and profile subscriptions are re-armed before one-shot resume catch-up, with no periodic polling.\n* **Mobile lifecycle:** dirty non-recurring plan drafts flush when the app becomes inactive/paused; realtime 404 no longer disables live sync silently for 30 minutes and retries the push channel after 30 seconds.\n* **Verification:** focused `live_sync_contract_test.dart`, analyzer, release web build, and Android arm64 APK build.\n\n"""
    marker = '## '
    idx = text.find(marker)
    if idx < 0:
        raise RuntimeError('CHANGELOG date marker not found')
    text = text[:idx] + entry + text[idx:]
    write(path, text)


def main() -> None:
    patch_plan_mutation_outbox()
    patch_plan_outbox_helpers()
    patch_plan_service()
    patch_catalog_realtime()
    patch_db_core()
    patch_edit_sheet_lifecycle()
    add_tests()
    patch_changelog()
    print('live sync patch applied')


if __name__ == '__main__':
    main()
