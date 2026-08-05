from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding='utf-8')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


def function_span(text: str, marker: str) -> tuple[int, int]:
    start = text.find(marker)
    if start < 0:
        raise RuntimeError(f'function not found: {marker}')
    async_body = text.find(') async {', start)
    sync_body = text.find(') {', start)
    candidates = [p for p in (async_body, sync_body) if p >= 0]
    if not candidates:
        raise RuntimeError(f'function body not found: {marker}')
    brace = text.find('{', min(candidates))
    depth = 0
    quote: str | None = None
    escaped = False
    for i in range(brace, len(text)):
        ch = text[i]
        if quote is not None:
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == quote:
                quote = None
            continue
        if ch in ("'", '"'):
            quote = ch
            continue
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                return start, i + 1
    raise RuntimeError(f'unclosed function: {marker}')


def replace_function(path: str, marker: str, replacement: str) -> None:
    text = read(path)
    start, end = function_span(text, marker)
    write(path, text[:start] + replacement + text[end:])


def tag_snapshot_expr(indent: str, variable: str) -> str:
    return f"""{indent}<Map<String, dynamic>>[
{indent}  for (final tag in {variable})
{indent}    <String, dynamic>{{
{indent}      'id': tag.pbRecordId,
{indent}      'tag_id': tag.tagId,
{indent}      'name': tag.name,
{indent}      'color': tag.color,
{indent}      'icon': tag.icon,
{indent}      'sort_order': tag.sortOrder,
{indent}      'domain': tag.domain,
{indent}      'default_plan_duration_minutes':
{indent}          tag.defaultPlanDurationMinutes,
{indent}    }},
{indent}]"""


def patch_helpers() -> None:
    path = 'lib/data/plans/plan_outbox_helpers.dart'
    text = read(path)
    text = replace_once(
        text,
        "bool _planMutationOutboxFlushInFlight = false;\n",
        "bool _planMutationOutboxFlushInFlight = false;\n"
        "final Map<String, int> _pendingPlanMutationRevisionByBusinessId =\n"
        "    <String, int>{};\n",
        'pending revision map',
    )
    write(path, text)

    replace_function(
        path,
        '  Future<void> flushPendingPlanMutations() async {',
        """  Future<void> flushPendingPlanMutations() async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (!_isPlansTableConfigured) return;
    if (_planMutationOutboxFlushInFlight) return;
    if (offlineSync.authPaused) return;
    _planMutationOutboxFlushInFlight = true;
    offlineSync.setSyncing(true);
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return;
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final snapshot = await PlanMutationOutbox.load(prefs);
      if (snapshot.isEmpty) return;
      var allSynced = true;
      for (final raw in snapshot) {
        final item = Map<String, dynamic>.from(raw);
        final receipt = PlanMutationOutbox.receiptForItem(item);
        _rememberPendingPlanMutation(receipt);
        final ok = await _flushOnePlanOutboxEntry(item, prefs);
        if (ok) {
          await _acknowledgePlanMutation(receipt);
          continue;
        }
        allSynced = false;
        await PlanMutationOutbox.markRetryIfCurrent(
          prefs,
          receipt,
          lastError: offlineSync.lastError ?? 'sync_failed',
        );
        break;
      }
      if (allSynced) offlineSync.clearErrors();
      await offlineSync.refreshPendingCount();
    } finally {
      offlineSync.setSyncing(false);
      _planMutationOutboxFlushInFlight = false;
    }
  }""",
    )

    replace_function(
        path,
        '  Future<void> _cancelPendingPlanMutationsForBusinessId(',
        """  Future<void> _cancelPendingPlanMutationsForBusinessId(
    String businessId,
  ) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await PlanMutationOutbox.removePendingForBusinessId(prefs, businessId);
      _pendingPlanMutationRevisionByBusinessId.remove(businessId.trim());
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_CANCEL: $e');
    }
  }""",
    )

    helpers = """

  void _rememberPendingPlanMutation(PlanMutationReceipt? receipt) {
    if (receipt == null) return;
    _pendingPlanMutationRevisionByBusinessId[receipt.businessId] =
        receipt.revision;
  }

  bool _hasPendingPlanMutationForBusinessId(String? businessId) {
    final key = businessId?.trim() ?? '';
    return key.isNotEmpty &&
        _pendingPlanMutationRevisionByBusinessId.containsKey(key);
  }

  Future<bool> _acknowledgePlanMutation(
    PlanMutationReceipt? receipt,
  ) async {
    if (receipt == null) return false;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final removed = await PlanMutationOutbox.acknowledge(prefs, receipt);
      if (removed &&
          _pendingPlanMutationRevisionByBusinessId[receipt.businessId] ==
              receipt.revision) {
        _pendingPlanMutationRevisionByBusinessId.remove(receipt.businessId);
      }
      await offlineSync.refreshPendingCount();
      return removed;
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_ACK: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> _planTagSnapshot(List<Tag> tags) =>
      <Map<String, dynamic>>[
        for (final tag in tags)
          <String, dynamic>{
            'id': tag.pbRecordId,
            'tag_id': tag.tagId,
            'name': tag.name,
            'color': tag.color,
            'icon': tag.icon,
            'sort_order': tag.sortOrder,
            'domain': tag.domain,
            'default_plan_duration_minutes':
                tag.defaultPlanDurationMinutes,
          },
      ];

  List<Tag> _planTagsFromSnapshot(dynamic raw) => <Tag>[
    if (raw is List)
      for (final item in raw)
        if (item is Map)
          Tag.fromPocketJson(Map<String, dynamic>.from(item)),
  ];
"""
    text = read(path)
    marker = '  Future<void> _cancelPendingPlanMutationsForBusinessId('
    start, end = function_span(text, marker)
    text = text[:end] + helpers + text[end:]
    write(path, text)

    replace_function(
        path,
        '  Future<void> _enqueuePlanCreateMutation(',
        """  Future<PlanMutationReceipt?> _enqueuePlanCreateMutation(
    Map<String, dynamic> body, {
    required String businessId,
    List<Tag>? tags,
    Object? error,
    String syncStatus = PlanMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
      if (tags != null) {
        normalized[PlanMutationOutbox.payloadTagsSnapshotKey] =
            _planTagSnapshot(tags);
      }
      final receipt = await PlanMutationOutbox.enqueue(
        prefs,
        PlanMutationOutbox.newPlanCreateItem(
          businessId: businessId,
          payload: normalized,
          error: error,
          syncStatus: syncStatus,
        ),
      );
      _rememberPendingPlanMutation(receipt);
      unawaited(offlineSync.refreshPendingCount());
      return receipt;
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_ENQUEUE create: $e');
      return null;
    }
  }""",
    )

    replace_function(
        path,
        '  Future<void> _enqueuePlanUpdateMutation({',
        """  Future<PlanMutationReceipt?> _enqueuePlanUpdateMutation({
    required String originalInput,
    required String businessId,
    required Map<String, dynamic> patchFields,
    String? pocketBaseId,
    List<String>? tagsLinkPbIds,
    Object? error,
    String syncStatus = PlanMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized =
          jsonDecode(jsonEncode(patchFields)) as Map<String, dynamic>;
      if (businessId.trim().isEmpty ||
          (normalized.isEmpty && tagsLinkPbIds == null)) {
        return null;
      }
      final receipt = await PlanMutationOutbox.enqueue(
        prefs,
        PlanMutationOutbox.newPlanUpdateItem(
          businessId: businessId.trim(),
          patchFields: normalized,
          pocketBaseId: pocketBaseId?.trim(),
          originalQueryId: originalInput.trim(),
          tagsLinkPbIds: tagsLinkPbIds,
          error: error,
          syncStatus: syncStatus,
        ),
      );
      _rememberPendingPlanMutation(receipt);
      unawaited(offlineSync.refreshPendingCount());
      return receipt;
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_ENQUEUE update: $e');
      return null;
    }
  }""",
    )

    replace_function(
        path,
        '  Future<void> _stagePlanUpdateWriteAhead({',
        """  Future<PlanMutationReceipt?> _stagePlanUpdateWriteAhead({
    required String originalInput,
    required String businessId,
    required Map<String, dynamic> patchBody,
    String? pocketBaseId,
    List<Tag>? tags,
  }) async {
    final scalarBody = Map<String, dynamic>.from(patchBody);
    scalarBody.remove('user_id');
    if (tags != null) {
      scalarBody[PlanMutationOutbox.payloadTagsSnapshotKey] =
          _planTagSnapshot(tags);
    }
    final receipt = await _enqueuePlanUpdateMutation(
      originalInput: originalInput,
      businessId: businessId,
      patchFields: scalarBody,
      pocketBaseId: pocketBaseId,
    );
    await offlineSync.refreshPendingCount();
    return receipt;
  }""",
    )

    replace_function(
        path,
        '  Future<bool> _patchPlanUpdateNetworkPhase({',
        """  Future<bool> _patchPlanUpdateNetworkPhase({
    required String originalInput,
    required String resolvedPbId,
    required String businessId,
    required PlanMutationReceipt? writeAheadReceipt,
    required Map<String, dynamic> patchBody,
    List<Tag>? tags,
    bool suppressAppSnack = false,
  }) async {
    final scalarBody = Map<String, dynamic>.from(patchBody);
    scalarBody.remove('user_id');
    try {
      if (scalarBody.isNotEmpty) {
        await _pb
            .collection(PbCollections.plans)
            .update(resolvedPbId, body: scalarBody);
      }
      if (tags != null) {
        await _syncPlanTagsPocket(resolvedPbId, tags);
      }
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final merged = await _pb
          .collection(PbCollections.plans)
          .getOne(resolvedPbId, expand: kPbPlanTagsExpand);
      final taskFromServer = _planningTaskFromPocketRecord(
        merged,
        pocketTagCatalog: tagCatalog,
      );
      _upsertPlanInUserCache(taskFromServer);
      _allPlansUserCacheFetchedAt = DateTime.now();
      final acknowledged = await _acknowledgePlanMutation(writeAheadReceipt);
      if (acknowledged) {
        clearOptimisticPlanningForPlanRow(originalInput);
        clearOptimisticPlanningForPlanRow(resolvedPbId);
      }
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      return true;
    } on ClientException catch (e) {
      final code = e.statusCode;
      if (code == 404) {
        final acknowledged = await _acknowledgePlanMutation(writeAheadReceipt);
        if (acknowledged) {
          _removePlanFromUserCache(resolvedPbId);
          _removePlanFromUserCache(originalInput);
        }
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }
      if (code == 401 || code == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        if (!suppressAppSnack) AppSnack.failed();
        return true;
      }
      if (_planMutationRetriableHttpCode(code)) {
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      await _acknowledgePlanMutation(writeAheadReceipt);
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    } catch (e, st) {
      DatabaseService._log('PATCH_PLAN_NETWORK: $e');
      DatabaseService._log(st.toString());
      if (_planMutationRetriableHttpCode(0)) {
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      await _acknowledgePlanMutation(writeAheadReceipt);
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
  }""",
    )

    text = read(path)
    text = replace_once(
        text,
        "      final body = Map<String, dynamic>.from(wrapped);\n"
        "      body['user_id'] = _pidForPbFilter;\n"
        "      try {\n"
        "        final record = await _pb\n"
        "            .collection(PbCollections.plans)\n"
        "            .create(body: body);\n",
        "      final body = Map<String, dynamic>.from(wrapped);\n"
        "      final tagsSnapshot =\n"
        "          body.remove(PlanMutationOutbox.payloadTagsSnapshotKey);\n"
        "      body['user_id'] = _pidForPbFilter;\n"
        "      try {\n"
        "        final existingId = await _fetchPbPlanSysIdByPlanIdField(businessId);\n"
        "        var record = existingId != null && existingId.isNotEmpty\n"
        "            ? await _pb.collection(PbCollections.plans).getOne(existingId)\n"
        "            : await _pb.collection(PbCollections.plans).create(body: body);\n"
        "        final replayTags = _planTagsFromSnapshot(tagsSnapshot);\n"
        "        if (replayTags.isNotEmpty || tagsSnapshot is List) {\n"
        "          await _syncPlanTagsPocket(record.id, replayTags);\n"
        "          record = await _pb.collection(PbCollections.plans).getOne(\n"
        "            record.id,\n"
        "            expand: kPbPlanTagsExpand,\n"
        "          );\n"
        "        }\n",
        'idempotent create replay',
    )
    text = replace_once(
        text,
        "      final tagsRaw = rawPayload.remove(PlanMutationOutbox.payloadTagsLinkKey);\n"
        "      final patchBody = Map<String, dynamic>.from(rawPayload);\n"
        "      patchBody.remove('user_id');\n"
        "      if (patchBody.isEmpty && tagsRaw == null) return true;\n",
        "      final tagsRaw = rawPayload.remove(PlanMutationOutbox.payloadTagsLinkKey);\n"
        "      final tagsSnapshot =\n"
        "          rawPayload.remove(PlanMutationOutbox.payloadTagsSnapshotKey);\n"
        "      final patchBody = Map<String, dynamic>.from(rawPayload);\n"
        "      patchBody.remove('user_id');\n"
        "      if (patchBody.isEmpty && tagsRaw == null && tagsSnapshot == null) {\n"
        "        return true;\n"
        "      }\n",
        'extract update tag snapshot',
    )
    text = replace_once(
        text,
        "        if (tagsRaw is List) {\n"
        "          final ids = [\n"
        "            for (final e in tagsRaw)\n"
        "              if (e != null) e.toString().trim(),\n"
        "          ].where((s) => s.isNotEmpty).toList();\n"
        "          await _pb\n"
        "              .collection(PbCollections.plans)\n"
        "              .update(pbId, body: <String, dynamic>{kPbPlanTagsExpand: ids});\n"
        "        }\n",
        "        List<String>? replayTagIds;\n"
        "        if (tagsRaw is List) {\n"
        "          replayTagIds = [\n"
        "            for (final e in tagsRaw)\n"
        "              if (e != null) e.toString().trim(),\n"
        "          ].where((s) => s.isNotEmpty).toList();\n"
        "        } else if (tagsSnapshot is List) {\n"
        "          replayTagIds = await _pbTagRecordIdsFromTags(\n"
        "            _planTagsFromSnapshot(tagsSnapshot),\n"
        "          );\n"
        "        }\n"
        "        if (replayTagIds != null) {\n"
        "          await _pb.collection(PbCollections.plans).update(\n"
        "            pbId,\n"
        "            body: <String, dynamic>{kPbPlanTagsExpand: replayTagIds},\n"
        "          );\n"
        "        }\n",
        'replay update tag snapshot',
    )
    write(path, text)


def patch_plan_service() -> None:
    path = 'lib/data/plan_service.dart'
    text = read(path)
    text = replace_once(
        text,
        "    await _enqueuePlanCreateMutation(\n"
        "      body,\n"
        "      businessId: clientPlanId,\n"
        "    );\n",
        "    final writeAheadReceipt = await _enqueuePlanCreateMutation(\n"
        "      body,\n"
        "      businessId: clientPlanId,\n"
        "      tags: task.tags,\n"
        "    );\n",
        'capture create receipt',
    )
    text = replace_once(
        text,
        "      await _cancelPendingPlanMutationsForBusinessId(clientPlanId);\n"
        "      await offlineSync.refreshPendingCount();\n"
        "      clearOptimisticPlanningForPlanRow(optimisticId);\n",
        "      await _acknowledgePlanMutation(writeAheadReceipt);\n"
        "      if (!_hasPendingPlanMutationForBusinessId(clientPlanId)) {\n"
        "        clearOptimisticPlanningForPlanRow(optimisticId);\n"
        "      }\n",
        'create success exact ack',
    )
    text = replace_once(
        text,
        "      if (code == 401 || code == 403) {\n"
        "        await _enqueuePlanCreateMutation(\n"
        "          body,\n"
        "          businessId: clientPlanId,\n"
        "          error: code,\n"
        "          syncStatus: PlanMutationOutbox.syncStatusPausedAuth,\n"
        "        );\n",
        "      if (code == 401 || code == 403) {\n",
        'create auth keeps staged item',
    )
    text = replace_once(
        text,
        "      if (_planMutationRetriableHttpCode(code) || _pbHttpBackoffActive) {\n"
        "        await _enqueuePlanCreateMutation(\n"
        "          body,\n"
        "          businessId: clientPlanId,\n"
        "          error: code,\n"
        "        );\n",
        "      if (_planMutationRetriableHttpCode(code) || _pbHttpBackoffActive) {\n",
        'create retry keeps staged item',
    )
    text = replace_once(
        text,
        "      await _cancelPendingPlanMutationsForBusinessId(clientPlanId);\n"
        "      await offlineSync.refreshPendingCount();\n"
        "      clearOptimisticPlanningForPlanRow(optimisticId);\n",
        "      await _acknowledgePlanMutation(writeAheadReceipt);\n"
        "      if (!_hasPendingPlanMutationForBusinessId(clientPlanId)) {\n"
        "        clearOptimisticPlanningForPlanRow(optimisticId);\n"
        "      }\n",
        'create validation exact ack',
    )
    text = replace_once(
        text,
        "      await _enqueuePlanCreateMutation(\n"
        "        body,\n"
        "        businessId: clientPlanId,\n"
        "        error: e,\n"
        "      );\n"
        "      offlineSync.setConnectivityOffline(true);\n",
        "      offlineSync.setConnectivityOffline(true);\n",
        'create exception keeps staged item',
    )
    text = replace_once(
        text,
        "    await _stagePlanUpdateWriteAhead(\n"
        "      originalInput: rid,\n"
        "      businessId: businessId,\n"
        "      patchBody: patchBody,\n"
        "      pocketBaseId: shadowPb,\n"
        "      tags: tags,\n"
        "    );\n",
        "    final writeAheadReceipt = await _stagePlanUpdateWriteAhead(\n"
        "      originalInput: rid,\n"
        "      businessId: businessId,\n"
        "      patchBody: patchBody,\n"
        "      pocketBaseId: shadowPb,\n"
        "      tags: tags,\n"
        "    );\n",
        'capture update receipt',
    )
    call = "          businessId: businessId,\n          patchBody: patchBody,\n"
    replacement = (
        "          businessId: businessId,\n"
        "          writeAheadReceipt: writeAheadReceipt,\n"
        "          patchBody: patchBody,\n"
    )
    if text.count(call) != 2:
        raise RuntimeError(f'update network calls: expected 2, found {text.count(call)}')
    text = text.replace(call, replacement)

    unresolved_old = """        if (!DatabaseService._isLikelyPocketBaseRowId(restId)) {
          List<String>? tagIds;
          if (tags != null) {
            tagIds = await _pbTagRecordIdsFromTags(tags);
          }
          final scalarOnly = Map<String, dynamic>.from(patchBody);
          scalarOnly.remove('user_id');
          await _enqueuePlanUpdateMutation(
            originalInput: rid,
            businessId: businessId,
            patchFields: scalarOnly,
            tagsLinkPbIds: tagIds,
            error: 'unresolved_pb_id',
          );
          offlineSync.setConnectivityOffline(true);
          return;
        }
"""
    unresolved_new = """        if (!DatabaseService._isLikelyPocketBaseRowId(restId)) {
          offlineSync.setConnectivityOffline(true);
          return;
        }
"""
    text = replace_once(text, unresolved_old, unresolved_new, 'unresolved keeps staged')
    catch_old = """        if (_planMutationRetriableHttpCode(0)) {
          final scalarOnly = Map<String, dynamic>.from(patchBody);
          scalarOnly.remove('user_id');
          await _enqueuePlanUpdateMutation(
            originalInput: rid,
            businessId: businessId,
            patchFields: scalarOnly,
            error: e,
          );
          offlineSync.setConnectivityOffline(true);
        } else if (!suppressAppSnack) {
"""
    catch_new = """        if (_planMutationRetriableHttpCode(0)) {
          offlineSync.setConnectivityOffline(true);
        } else if (!suppressAppSnack) {
"""
    text = replace_once(text, catch_old, catch_new, 'update exception keeps staged')

    realtime_old = """        final biz = _planBusinessUuidFromTask(task);
        if (biz != null && biz.isNotEmpty) {
          clearOptimisticPlanningForPlanRow('optimistic-$biz');
        }
        clearOptimisticPlanningForPlanRow(task.planRowIdForBackend);
"""
    realtime_new = """        final biz = _planBusinessUuidFromTask(task);
        if (!_hasPendingPlanMutationForBusinessId(biz)) {
          if (biz != null && biz.isNotEmpty) {
            clearOptimisticPlanningForPlanRow('optimistic-$biz');
          }
          clearOptimisticPlanningForPlanRow(task.planRowIdForBackend);
        }
"""
    text = replace_once(text, realtime_old, realtime_new, 'realtime preserves pending overlay')
    write(path, text)


def patch_order() -> None:
    path = 'lib/data/plans/plan_order_helpers.dart'
    text = read(path)
    old = """        final ok = await _patchPlanUpdateNetworkPhase(
          originalInput: input,
          resolvedPbId: resolved,
          businessId: businessId,
          patchBody: <String, dynamic>{'order': newOrder},
          suppressAppSnack: true,
        );
"""
    new = """        final patchBody = <String, dynamic>{'order': newOrder};
        final writeAheadReceipt = await _stagePlanUpdateWriteAhead(
          originalInput: input,
          businessId: businessId,
          patchBody: patchBody,
          pocketBaseId: resolved,
        );
        final ok = await _patchPlanUpdateNetworkPhase(
          originalInput: input,
          resolvedPbId: resolved,
          businessId: businessId,
          writeAheadReceipt: writeAheadReceipt,
          patchBody: patchBody,
          suppressAppSnack: true,
        );
"""
    write(path, replace_once(text, old, new, 'order write-ahead'))


def patch_tests() -> None:
    path = 'test/live_sync_contract_test.dart'
    text = read(path)
    start, end = function_span(
        text,
        "  test('write-ahead create is durable and duplicate staging coalesces', () async {",
    )
    replacement = """  test('stale acknowledgement cannot delete a newer plan edit', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final first = await PlanMutationOutbox.enqueue(
      prefs,
      PlanMutationOutbox.newPlanUpdateItem(
        businessId: 'plan-1',
        originalQueryId: 'plan-1',
        patchFields: <String, dynamic>{'title': 'First'},
      ),
    );
    final latest = await PlanMutationOutbox.enqueue(
      prefs,
      PlanMutationOutbox.newPlanUpdateItem(
        businessId: 'plan-1',
        originalQueryId: 'plan-1',
        patchFields: <String, dynamic>{'title': 'Latest'},
      ),
    );

    expect(await PlanMutationOutbox.acknowledge(prefs, first), isFalse);
    var queue = await PlanMutationOutbox.load(prefs);
    expect(queue, hasLength(1));
    expect((queue.single['payload'] as Map)['title'], 'Latest');

    expect(await PlanMutationOutbox.acknowledge(prefs, latest), isTrue);
    queue = await PlanMutationOutbox.load(prefs);
    expect(queue, isEmpty);
  });"""
    text = text[:start] + replacement + text[end:]
    text = replace_once(
        text,
        "    expect(outbox, contains('await _cancelPendingPlanMutationsForBusinessId(businessId)'));\n",
        "    expect(\n"
        "      outbox,\n"
        "      contains('await _acknowledgePlanMutation(writeAheadReceipt)'),\n"
        "    );\n"
        "    expect(\n"
        "      outbox,\n"
        "      isNot(contains('await _pbTagRecordIdsFromTags(tags);')),\n"
        "    );\n",
        'receipt contract assertion',
    )
    write(path, text)


def patch_changelog() -> None:
    path = 'CHANGELOG.md'
    text = read(path)
    old = '* **Plans/Lists durability:** create and edit mutations now use a local write-ahead outbox before PocketBase POST/PATCH; successful server confirmation clears the staged mutation, while auth/network failures keep one coalesced replay item.\n'
    new = '* **Plans/Lists durability:** create and edit mutations now use a serialized local write-ahead outbox before PocketBase POST/PATCH; revision-specific acknowledgements prevent stale responses or concurrent flushes from deleting newer mobile edits, while auth/network failures keep one coalesced replay item.\n'
    write(path, replace_once(text, old, new, 'changelog hardening'))


def main() -> None:
    patch_helpers()
    patch_plan_service()
    patch_order()
    patch_tests()
    patch_changelog()
    print('receipt hardening v2 applied')


if __name__ == '__main__':
    main()
