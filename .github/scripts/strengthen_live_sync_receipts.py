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
        raise RuntimeError(f'{label}: expected one match, found {count}')
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


def patch_plan_outbox() -> None:
    path = 'lib/data/local_sync/plan_mutation_outbox.dart'
    text = read(path)
    text = replace_once(
        text,
        "import 'dart:convert';\n",
        "import 'dart:async';\nimport 'dart:convert';\n",
        'plan outbox async import',
    )
    receipt = """
final class PlanMutationReceipt {
  const PlanMutationReceipt({
    required this.operationId,
    required this.revision,
    required this.kind,
    required this.businessId,
  });

  final String operationId;
  final int revision;
  final String kind;
  final String businessId;
}

"""
    text = replace_once(
        text,
        'abstract final class PlanMutationOutbox {\n',
        receipt + 'abstract final class PlanMutationOutbox {\n',
        'plan receipt class',
    )
    text = replace_once(
        text,
        "  static const String payloadTagsLinkKey = '__tags_link_pb_ids';\n",
        "  static const String payloadTagsLinkKey = '__tags_link_pb_ids';\n"
        "  static const String payloadTagsSnapshotKey = '__tags_snapshot';\n\n"
        "  static Future<void> _writeChain = Future<void>.value();\n\n"
        "  static Future<T> _withWriteLock<T>(Future<T> Function() action) async {\n"
        "    final previous = _writeChain;\n"
        "    final release = Completer<void>();\n"
        "    _writeChain = release.future;\n"
        "    await previous;\n"
        "    try {\n"
        "      return await action();\n"
        "    } finally {\n"
        "      release.complete();\n"
        "    }\n"
        "  }\n",
        'plan write lock and tag snapshot key',
    )
    text = replace_once(
        text,
        "          item['operationId'] = existing['operationId'];\n"
        "          item['createdAt'] = existing['createdAt'];\n"
        "          out[existingCreateIndex] = item;\n",
        "          item['operationId'] = existing['operationId'];\n"
        "          item['createdAt'] = existing['createdAt'];\n"
        "          item['revision'] =\n"
        "              ((existing['revision'] as num?)?.toInt() ?? 1) + 1;\n"
        "          out[existingCreateIndex] = item;\n",
        'create revision bump',
    )
    text = replace_once(
        text,
        "          final pb = (item['pocketBaseId'] ?? '').toString().trim();\n"
        "          if (pb.isNotEmpty) existing['pocketBaseId'] = pb;\n"
        "          out[idx] = existing;\n",
        "          final pb = (item['pocketBaseId'] ?? '').toString().trim();\n"
        "          if (pb.isNotEmpty) existing['pocketBaseId'] = pb;\n"
        "          existing['revision'] =\n"
        "              ((existing['revision'] as num?)?.toInt() ?? 1) + 1;\n"
        "          existing['syncStatus'] = item['syncStatus'];\n"
        "          if (item.containsKey('lastError')) {\n"
        "            existing['lastError'] = item['lastError'];\n"
        "          }\n"
        "          out[idx] = existing;\n",
        'update revision bump',
    )
    text = replace_once(
        text,
        "      'operationId': _newOperationId(),\n"
        "      'collection': 'plans',\n",
        "      'operationId': _newOperationId(),\n"
        "      'revision': 1,\n"
        "      'collection': 'plans',\n",
        'base revision',
    )
    text = replace_once(
        text,
        "    List<String>? tagsLinkPbIds,\n"
        "    Object? error,\n",
        "    List<String>? tagsLinkPbIds,\n"
        "    List<Map<String, dynamic>>? tagsSnapshot,\n"
        "    Object? error,\n",
        'update item snapshot signature',
    )
    text = replace_once(
        text,
        "    if (tagsLinkPbIds != null && tagsLinkPbIds.isNotEmpty) {\n"
        "      payload[payloadTagsLinkKey] = tagsLinkPbIds;\n"
        "    }\n",
        "    if (tagsLinkPbIds != null) {\n"
        "      payload[payloadTagsLinkKey] = tagsLinkPbIds;\n"
        "    }\n"
        "    if (tagsSnapshot != null) {\n"
        "      payload[payloadTagsSnapshotKey] = tagsSnapshot;\n"
        "    }\n",
        'persist tag clear and snapshot',
    )
    enqueue_start, enqueue_end = function_span(
        text,
        '  static Future<void> enqueue(',
    )
    enqueue_new = """  static Future<PlanMutationReceipt?> enqueue(
    SharedPreferences prefs,
    Map<String, dynamic> item,
  ) => _withWriteLock(() async {
    final q = await load(prefs);
    q.add(item);
    final next = coalesceQueue(q);
    await save(prefs, next);
    final businessId = _bizKey(item);
    final kind = (item['kind'] ?? '').toString();
    for (final candidate in next.reversed) {
      if (_bizKey(candidate) != businessId) continue;
      if ((candidate['kind'] ?? '').toString() != kind) continue;
      return receiptForItem(candidate);
    }
    return null;
  });"""
    text = text[:enqueue_start] + enqueue_new + text[enqueue_end:]
    remove_start, remove_end = function_span(
        text,
        '  static Future<void> removePendingForBusinessId(',
    )
    remove_new = """  static Future<void> removePendingForBusinessId(
    SharedPreferences prefs,
    String businessId,
  ) => _withWriteLock(() async {
    final biz = businessId.trim();
    if (biz.isEmpty) return;
    final q = await load(prefs);
    if (q.isEmpty) return;
    final next = q.where((e) => _bizKey(e) != biz).toList();
    if (next.length != q.length) {
      await save(prefs, next);
    }
  });"""
    text = text[:remove_start] + remove_new + text[remove_end:]
    methods = """

  static PlanMutationReceipt? receiptForItem(Map<String, dynamic> item) {
    final operationId = (item['operationId'] ?? '').toString().trim();
    final kind = (item['kind'] ?? '').toString().trim();
    final businessId = _bizKey(item);
    if (operationId.isEmpty || kind.isEmpty || businessId.isEmpty) return null;
    return PlanMutationReceipt(
      operationId: operationId,
      revision: (item['revision'] as num?)?.toInt() ?? 1,
      kind: kind,
      businessId: businessId,
    );
  }

  static bool _matchesReceipt(
    Map<String, dynamic> item,
    PlanMutationReceipt receipt,
  ) =>
      (item['operationId'] ?? '').toString() == receipt.operationId &&
      ((item['revision'] as num?)?.toInt() ?? 1) == receipt.revision &&
      (item['kind'] ?? '').toString() == receipt.kind &&
      _bizKey(item) == receipt.businessId;

  static Future<bool> acknowledge(
    SharedPreferences prefs,
    PlanMutationReceipt? receipt,
  ) => _withWriteLock(() async {
    if (receipt == null) return false;
    final q = await load(prefs);
    final next = q.where((item) => !_matchesReceipt(item, receipt)).toList();
    if (next.length == q.length) return false;
    await save(prefs, next);
    return true;
  });

  static Future<bool> markRetryIfCurrent(
    SharedPreferences prefs,
    PlanMutationReceipt? receipt, {
    required String lastError,
  }) => _withWriteLock(() async {
    if (receipt == null) return false;
    final q = await load(prefs);
    var changed = false;
    final next = <Map<String, dynamic>>[];
    for (final raw in q) {
      final item = Map<String, dynamic>.from(raw);
      if (_matchesReceipt(item, receipt)) {
        item['retryCount'] = ((item['retryCount'] as num?)?.toInt() ?? 0) + 1;
        item['lastError'] = lastError;
        changed = true;
      }
      next.add(item);
    }
    if (changed) await save(prefs, next);
    return changed;
  });
"""
    final_brace = text.rfind('\n}')
    if final_brace < 0:
        raise RuntimeError('plan outbox final brace not found')
    text = text[:final_brace] + methods + text[final_brace:]
    write(path, text)


def patch_plan_helpers() -> None:
    path = 'lib/data/plans/plan_outbox_helpers.dart'
    flush = """  Future<void> flushPendingPlanMutations() async {
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
        final ok = await _flushOnePlanOutboxEntry(item, prefs);
        if (ok) {
          await PlanMutationOutbox.acknowledge(prefs, receipt);
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
  }"""
    replace_function(path, '  Future<void> flushPendingPlanMutations() async {', flush)
    text = read(path)
    text = replace_once(
        text,
        "  Future<void> _enqueuePlanCreateMutation(\n",
        "  Future<PlanMutationReceipt?> _enqueuePlanCreateMutation(\n",
        'create enqueue receipt return',
    )
    text = replace_once(
        text,
        "      await PlanMutationOutbox.enqueue(\n"
        "        prefs,\n"
        "        PlanMutationOutbox.newPlanCreateItem(\n",
        "      final receipt = await PlanMutationOutbox.enqueue(\n"
        "        prefs,\n"
        "        PlanMutationOutbox.newPlanCreateItem(\n",
        'capture create receipt',
    )
    text = replace_once(
        text,
        "      unawaited(offlineSync.refreshPendingCount());\n"
        "    } catch (e) {\n"
        "      DatabaseService._log('PLAN_OUTBOX_ENQUEUE create: $e');\n"
        "    }\n"
        "  }\n\n"
        "  Future<void> _enqueuePlanUpdateMutation({\n",
        "      unawaited(offlineSync.refreshPendingCount());\n"
        "      return receipt;\n"
        "    } catch (e) {\n"
        "      DatabaseService._log('PLAN_OUTBOX_ENQUEUE create: $e');\n"
        "      return null;\n"
        "    }\n"
        "  }\n\n"
        "  Future<PlanMutationReceipt?> _enqueuePlanUpdateMutation({\n",
        'finish create and update return types',
    )
    text = replace_once(
        text,
        "    List<String>? tagsLinkPbIds,\n"
        "    Object? error,\n",
        "    List<String>? tagsLinkPbIds,\n"
        "    List<Map<String, dynamic>>? tagsSnapshot,\n"
        "    Object? error,\n",
        'enqueue update snapshot parameter',
    )
    text = replace_once(
        text,
        "      if (businessId.trim().isEmpty || normalized.isEmpty) return;\n"
        "      await PlanMutationOutbox.enqueue(\n",
        "      if (businessId.trim().isEmpty ||\n"
        "          (normalized.isEmpty && tagsSnapshot == null && tagsLinkPbIds == null)) {\n"
        "        return null;\n"
        "      }\n"
        "      final receipt = await PlanMutationOutbox.enqueue(\n",
        'capture update receipt and allow tag-only',
    )
    text = replace_once(
        text,
        "          tagsLinkPbIds: tagsLinkPbIds,\n"
        "          error: error,\n",
        "          tagsLinkPbIds: tagsLinkPbIds,\n"
        "          tagsSnapshot: tagsSnapshot,\n"
        "          error: error,\n",
        'forward tag snapshot',
    )
    text = replace_once(
        text,
        "      unawaited(offlineSync.refreshPendingCount());\n"
        "    } catch (e) {\n"
        "      DatabaseService._log('PLAN_OUTBOX_ENQUEUE update: $e');\n"
        "    }\n"
        "  }\n\n"
        "  Future<void> _enqueuePlanDeleteMutation({\n",
        "      unawaited(offlineSync.refreshPendingCount());\n"
        "      return receipt;\n"
        "    } catch (e) {\n"
        "      DatabaseService._log('PLAN_OUTBOX_ENQUEUE update: $e');\n"
        "      return null;\n"
        "    }\n"
        "  }\n\n"
        "  Future<void> _enqueuePlanDeleteMutation({\n",
        'finish update receipt return',
    )
    text = replace_once(
        text,
        "      final tagsRaw = rawPayload.remove(PlanMutationOutbox.payloadTagsLinkKey);\n"
        "      final patchBody = Map<String, dynamic>.from(rawPayload);\n",
        "      final tagsRaw = rawPayload.remove(PlanMutationOutbox.payloadTagsLinkKey);\n"
        "      final tagsSnapshotRaw =\n"
        "          rawPayload.remove(PlanMutationOutbox.payloadTagsSnapshotKey);\n"
        "      final patchBody = Map<String, dynamic>.from(rawPayload);\n",
        'extract tag snapshot',
    )
    text = replace_once(
        text,
        "      if (patchBody.isEmpty && tagsRaw == null) return true;\n",
        "      if (patchBody.isEmpty && tagsRaw == null && tagsSnapshotRaw == null) {\n"
        "        return true;\n"
        "      }\n",
        'tag snapshot counts as update',
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
        "        } else if (tagsSnapshotRaw is List) {\n"
        "          final snapshotTags = <Tag>[\n"
        "            for (final raw in tagsSnapshotRaw)\n"
        "              if (raw is Map)\n"
        "                Tag.fromPocketJson(Map<String, dynamic>.from(raw)),\n"
        "          ];\n"
        "          replayTagIds = await _pbTagRecordIdsFromTags(snapshotTags);\n"
        "        }\n"
        "        if (replayTagIds != null) {\n"
        "          await _pb.collection(PbCollections.plans).update(\n"
        "            pbId,\n"
        "            body: <String, dynamic>{kPbPlanTagsExpand: replayTagIds},\n"
        "          );\n"
        "        }\n",
        'replay tag snapshot',
    )
    stage = """  Future<PlanMutationReceipt?> _stagePlanUpdateWriteAhead({
    required String originalInput,
    required String businessId,
    required Map<String, dynamic> patchBody,
    String? pocketBaseId,
    List<Tag>? tags,
  }) async {
    final scalarBody = Map<String, dynamic>.from(patchBody);
    scalarBody.remove('user_id');
    final tagSnapshot = tags == null
        ? null
        : <Map<String, dynamic>>[
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
    final knownTagIds = tags == null
        ? null
        : <String>[
            for (final tag in tags)
              if ((tag.pbRecordId ?? '').trim().isNotEmpty)
                tag.pbRecordId!.trim(),
          ];
    final receipt = await _enqueuePlanUpdateMutation(
      originalInput: originalInput,
      businessId: businessId,
      patchFields: scalarBody,
      pocketBaseId: pocketBaseId,
      tagsLinkPbIds: knownTagIds,
      tagsSnapshot: tagSnapshot,
    );
    await offlineSync.refreshPendingCount();
    return receipt;
  }"""
    replace_function(path, '  Future<void> _stagePlanUpdateWriteAhead({', stage)
    text = read(path)
    text = replace_once(
        text,
        "  Future<bool> _patchPlanUpdateNetworkPhase({\n"
        "    required String originalInput,\n"
        "    required String resolvedPbId,\n"
        "    required String businessId,\n"
        "    required Map<String, dynamic> patchBody,\n",
        "  Future<bool> _patchPlanUpdateNetworkPhase({\n"
        "    required String originalInput,\n"
        "    required String resolvedPbId,\n"
        "    required String businessId,\n"
        "    required PlanMutationReceipt? writeAheadReceipt,\n"
        "    required Map<String, dynamic> patchBody,\n",
        'network phase receipt parameter',
    )
    text = text.replace(
        'await _cancelPendingPlanMutationsForBusinessId(businessId);',
        'await _acknowledgePlanMutation(writeAheadReceipt);',
    )
    ack_helper = """
  Future<void> _acknowledgePlanMutation(
    PlanMutationReceipt? receipt,
  ) async {
    if (receipt == null) return;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await PlanMutationOutbox.acknowledge(prefs, receipt);
      await offlineSync.refreshPendingCount();
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_ACK: $e');
    }
  }

"""
    text = replace_once(
        text,
        '  // --- Immediate update/delete network phase (not flush/replay) ---\n',
        ack_helper + '  // --- Immediate update/delete network phase (not flush/replay) ---\n',
        'insert plan ack helper',
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
        "    );\n",
        'capture create write-ahead receipt',
    )
    text = replace_once(
        text,
        "      await _cancelPendingPlanMutationsForBusinessId(clientPlanId);\n"
        "      await offlineSync.refreshPendingCount();\n",
        "      await _acknowledgePlanMutation(writeAheadReceipt);\n",
        'ack exact create receipt on success',
    )
    text = replace_once(
        text,
        "      await _cancelPendingPlanMutationsForBusinessId(clientPlanId);\n"
        "      await offlineSync.refreshPendingCount();\n"
        "      clearOptimisticPlanningForPlanRow(optimisticId);\n",
        "      await _acknowledgePlanMutation(writeAheadReceipt);\n"
        "      clearOptimisticPlanningForPlanRow(optimisticId);\n",
        'ack exact create receipt on nonretriable',
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
        'capture update write-ahead receipt',
    )
    # Both immediate dispatch sites use the same receipt. A stale response can
    # only acknowledge the exact revision it sent.
    text = text.replace(
        "          businessId: businessId,\n          patchBody: patchBody,\n",
        "          businessId: businessId,\n"
        "          writeAheadReceipt: writeAheadReceipt,\n"
        "          patchBody: patchBody,\n",
    )
    if text.count('writeAheadReceipt: writeAheadReceipt') != 2:
        raise RuntimeError(
            'expected two update network receipt forwards, found '
            f"{text.count('writeAheadReceipt: writeAheadReceipt')}"
        )
    write(path, text)


def patch_tests() -> None:
    path = 'test/live_sync_contract_test.dart'
    text = read(path)
    start, end = function_span(
        text,
        "  test('write-ahead create is durable and duplicate staging coalesces', () async {",
    )
    first_test = """  test('write-ahead acknowledgements never delete newer mutations', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final createReceipt = await PlanMutationOutbox.enqueue(
      prefs,
      PlanMutationOutbox.newPlanCreateItem(
        businessId: 'plan-1',
        payload: <String, dynamic>{'plan_id': 'plan-1', 'title': 'Draft'},
      ),
    );
    final firstUpdate = await PlanMutationOutbox.enqueue(
      prefs,
      PlanMutationOutbox.newPlanUpdateItem(
        businessId: 'plan-1',
        originalQueryId: 'plan-1',
        patchFields: <String, dynamic>{'title': 'First'},
      ),
    );
    final secondUpdate = await PlanMutationOutbox.enqueue(
      prefs,
      PlanMutationOutbox.newPlanUpdateItem(
        businessId: 'plan-1',
        originalQueryId: 'plan-1',
        patchFields: <String, dynamic>{'title': 'Latest'},
      ),
    );

    expect(await PlanMutationOutbox.acknowledge(prefs, firstUpdate), isFalse);
    var queue = await PlanMutationOutbox.load(prefs);
    expect(queue, hasLength(2));
    expect(
      (queue.last['payload'] as Map<String, dynamic>)['title'],
      'Latest',
    );

    expect(await PlanMutationOutbox.acknowledge(prefs, createReceipt), isTrue);
    queue = await PlanMutationOutbox.load(prefs);
    expect(queue, hasLength(1));
    expect(queue.single['kind'], PlanMutationOutbox.kindPlanUpdate);

    expect(await PlanMutationOutbox.acknowledge(prefs, secondUpdate), isTrue);
    expect(await PlanMutationOutbox.load(prefs), isEmpty);
  });"""
    text = text[:start] + first_test + text[end:]
    text = replace_once(
        text,
        "    expect(outbox, contains('await _cancelPendingPlanMutationsForBusinessId(businessId)'));\n",
        "    expect(outbox, contains('await _acknowledgePlanMutation(writeAheadReceipt)'));\n"
        "    expect(outbox, isNot(contains('await _pbTagRecordIdsFromTags(tags);')));\n",
        'test exact ack and no pre-stage tag network',
    )
    write(path, text)


def patch_changelog() -> None:
    path = 'CHANGELOG.md'
    text = read(path)
    old = (
        '* **Plans/Lists durability:** create and edit mutations now use a local '
        'write-ahead outbox before PocketBase POST/PATCH; successful server '
        'confirmation clears the staged mutation, while auth/network failures keep '
        'one coalesced replay item.\n'
    )
    new = (
        '* **Plans/Lists durability:** create and edit mutations now use a serialized '
        'local write-ahead outbox before PocketBase POST/PATCH; revision-specific '
        'acknowledgements prevent an older response or concurrent flush from deleting '
        'a newer mobile edit, while auth/network failures keep one coalesced replay item.\n'
    )
    text = replace_once(text, old, new, 'changelog receipt hardening')
    write(path, text)


def main() -> None:
    patch_plan_outbox()
    patch_plan_helpers()
    patch_plan_service()
    patch_tests()
    patch_changelog()
    print('live sync receipts strengthened')


if __name__ == '__main__':
    main()
