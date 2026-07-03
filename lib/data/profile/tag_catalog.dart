part of '../database_service.dart';

extension TagCatalogExtension on DatabaseService {
  /// Snapshot for tag-group headers (may be empty before first fetch).
  List<Tag> get cachedUserTagsCatalog =>
      List.unmodifiable(_userTagsCatalogCache);

  Stream<void> get tagsCatalogUpdated => _tagsCatalogRefreshController.stream;

  void notifyTagsCatalogChanged() {
    if (!_tagsCatalogRefreshController.isClosed) {
      _tagsCatalogRefreshController.add(null);
    }
    syncEmbeddedPlanTagsFromCatalog();
  }
  /// PocketBase: **tags** rows for the current `user_id` (flat maps incl. 15-char `id`).
  Future<List<Map<String, dynamic>>> fetchTags() async {
    if (!(currentProfileId?.isNotEmpty ?? false)) return [];
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        return [];
      }
      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return [];
      final uid = _escapeForPbFilter(authId);
      final list = await _pb
          .collection(PbCollections.tags)
          .getFullList(filter: 'user_id = "$uid"');
      final out = list.map((r) {
        final m = Map<String, dynamic>.from(r.data);
        m['id'] = r.id;
        m['_pb_record_id'] = r.id;
        return m;
      }).toList();
      if (kDebugMode) {
        debugPrint('[PB] fetchTags: ${out.length} rows @ $kPocketBaseUrl');
      }
      return out;
    } catch (e, st) {
      _maybeOpenPbCircuitFromListFailure(e, 'fetchTags');
      DatabaseService._log('TAGS_FETCH: $e');
      DatabaseService._log(st.toString());
      return [];
    }
  }

  /// Loads tag rows for the current profile (`user_id` filter). Returns empty if none or error (no mocks).
  /// [scope] filters `tags.domain`: plan strip vs list strip (@DATA_MAP).
  Future<List<Tag>> fetchTagsForCurrentUser({
    TagCatalogScope scope = TagCatalogScope.plan,
  }) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      _userTagsCatalogCache = [];
      return [];
    }
    try {
      final flat = await fetchTags();
      final out = <Tag>[];
      for (final row in flat) {
        final tag = Tag.fromPocketJson(row);
        if (tag.tagId == 0 &&
            (tag.pbRecordId == null || tag.pbRecordId!.isEmpty)) {
          continue;
        }
        out.add(tag);
      }
      out.sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      _userTagsCatalogCache = List.unmodifiable(out);
      return List<Tag>.from(out.where((t) => scope.matchesTag(t)));
    } catch (e, st) {
      DatabaseService._log('TAGS_FETCH: $e');
      DatabaseService._log(st.toString());
      _userTagsCatalogCache = [];
      return [];
    }
  }

  /// Writes `sort_order` 0…n-1 for [ordered] (PocketBase **tags** rows). Concurrent PATCH per row.
  Future<bool> persistTagsSortOrderForCurrentUser(List<Tag> ordered) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (ordered.isEmpty) return true;
    try {
      await ensurePocketBaseReady();
      final jobs = <Future<dynamic>>[];
      for (var i = 0; i < ordered.length; i++) {
        final rid = ordered[i].pbRecordId?.trim() ?? '';
        if (rid.isEmpty) continue;
        jobs.add(
          _pb
              .collection(PbCollections.tags)
              .update(
                rid,
                body: <String, dynamic>{
                  'user_id': _pidForPbFilter,
                  'sort_order': i,
                },
              ),
        );
      }
      if (jobs.isEmpty) return false;
      await Future.wait(jobs);
      final next = <Tag>[
        for (var i = 0; i < ordered.length; i++)
          ordered[i].copyWith(sortOrder: i),
      ];
      _userTagsCatalogCache = List.unmodifiable(next);
      notifyTagsCatalogChanged();
      return true;
    } catch (e, st) {
      DatabaseService._log('TAG_SORT_PERSIST: $e');
      DatabaseService._log(st.toString());
      return false;
    }
  }

  /// POST one tag row: `user_id`, `tag_id` (business), `name`, optional `color` / `icon` (@DATA_MAP `tags`).
  Future<Tag?> createTagForCurrentUser({
    required String name,
    required String colorHex,
    required String iconKey,
    String domain = 'plan',
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final dom = domain.trim().toLowerCase() == 'list' ? 'list' : 'plan';
    try {
      final existing = await fetchTagsForCurrentUser(
        scope: dom == 'list' ? TagCatalogScope.list : TagCatalogScope.plan,
      );
      var nextBiz = 1;
      var nextOrder = 0;
      for (final t in existing) {
        if (t.tagId >= nextBiz) nextBiz = t.tagId + 1;
        if (t.sortOrder >= nextOrder) nextOrder = t.sortOrder + 1;
      }
      final created = await _pb
          .collection(PbCollections.tags)
          .create(
            body: <String, dynamic>{
              'tag_id': nextBiz,
              'user_id': _pidForPbFilter,
              'name': trimmed,
              'color': colorHex,
              'icon': iconKey,
              'sort_order': nextOrder,
              'domain': dom,
            },
          );
      final tag = Tag.fromPocketJson(<String, dynamic>{
        ...created.data,
        'id': created.id,
      });
      _userTagsCatalogCache = [..._userTagsCatalogCache, tag];
      notifyTagsCatalogChanged();
      return tag;
    } catch (e, st) {
      DatabaseService._log('CREATE_TAG: $e');
      DatabaseService._log(st.toString());
      return null;
    }
  }

  /// PocketBase **tags** collection row id.
  Future<bool> deleteTagByPocketRecordId(String pocketRecordId) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }
    final id = pocketRecordId.trim();
    if (id.isEmpty) return false;
    try {
      await _pb.collection(PbCollections.tags).delete(id);
      _userTagsCatalogCache = _userTagsCatalogCache
          .where((t) => t.pbRecordId != id)
          .toList();
      notifyTagsCatalogChanged();
      return true;
    } catch (e, st) {
      DatabaseService._log('DELETE_TAG_PB: $e');
      DatabaseService._log(st.toString());
      return false;
    }
  }

  /// Update one **tags** row on PocketBase.
  Future<bool> patchTagForCurrentUser({
    required String pocketRecordId,
    required String name,
    required String colorHex,
    required String iconKey,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final rid = pocketRecordId.trim();
    if (rid.isEmpty) return false;
    try {
      await _pb
          .collection(PbCollections.tags)
          .update(
            rid,
            body: <String, dynamic>{
              'user_id': _pidForPbFilter,
              'name': trimmed,
              'color': colorHex,
              'icon': iconKey,
            },
          );
      _userTagsCatalogCache = [
        for (final t in _userTagsCatalogCache)
          if (t.pbRecordId == rid)
            t.copyWith(name: trimmed, color: colorHex, icon: iconKey)
          else
            t,
      ];
      notifyTagsCatalogChanged();
      return true;
    } catch (e, st) {
      DatabaseService._log('TAG_PATCH: $e');
      DatabaseService._log(st.toString());
      return false;
    }
  }

  /// PATCH `tags.default_plan_duration_minutes` for the current user.
  /// Returns `null` on success, or a [dictionary] error key on failure.
  Future<String?> patchTagDefaultPlanDurationForCurrentUser({
    required String pocketRecordId,
    int? durationMinutes,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) {
      return 'toast_error';
    }
    final rid = pocketRecordId.trim();
    if (rid.isEmpty) return 'toast_error';
    final sanitized = durationMinutes == null
        ? null
        : DatabaseService.instance.sanitizeTagDefaultPlanDurationMinutes(
            durationMinutes,
          );
    Tag? prior;
    for (final t in _userTagsCatalogCache) {
      if (t.pbRecordId?.trim() == rid) {
        prior = t;
        break;
      }
    }
    final tagBizId = prior?.tagId ?? 0;
    print(
      'TAG_DURATION_SAVE_REQUEST tagId=$tagBizId pbId=$rid minutes=${sanitized ?? 'null'}',
    );
    try {
      final body = <String, dynamic>{'user_id': _pidForPbFilter};
      if (sanitized == null) {
        body['default_plan_duration_minutes'] = null;
      } else {
        body['default_plan_duration_minutes'] = sanitized;
      }
      final record = await _pb
          .collection(PbCollections.tags)
          .update(rid, body: body);
      final row = Map<String, dynamic>.from(record.data);
      row['id'] = record.id;
      final verified = Tag.fromPocketJson(row);
      final persisted = verified.defaultPlanDurationMinutes;
      if (sanitized == null) {
        if (persisted != null) {
          print(
            'TAG_DURATION_SAVE_FAIL tagId=$tagBizId pbId=$rid status=verify '
            'error=clear_expected_null_got_$persisted',
          );
          return 'tag_duration_field_not_configured';
        }
      } else if (persisted != sanitized) {
        print(
          'TAG_DURATION_SAVE_FAIL tagId=$tagBizId pbId=$rid status=verify '
          'error=expected_${sanitized}_got_${persisted ?? 'null'}',
        );
        return 'tag_duration_field_not_configured';
      }
      _userTagsCatalogCache = [
        for (final t in _userTagsCatalogCache)
          if (t.pbRecordId?.trim() == rid) verified else t,
      ];
      notifyTagsCatalogChanged();
      print(
        'TAG_DURATION_SAVE_SUCCESS tagId=$tagBizId pbId=$rid minutes=${persisted ?? 'null'}',
      );
      print(
        'TAG_DURATION_CACHE_UPDATED tagId=$tagBizId minutes=${persisted ?? 'null'}',
      );
      return null;
    } on ClientException catch (e, st) {
      DatabaseService._log('TAG_DURATION_PATCH: $e');
      DatabaseService._log(st.toString());
      print(
        'TAG_DURATION_SAVE_FAIL tagId=$tagBizId pbId=$rid status=${e.statusCode} error=$e',
      );
      if (e.statusCode == 400 || e.statusCode == 404) {
        return 'tag_duration_field_not_configured';
      }
      return 'toast_error';
    } catch (e, st) {
      DatabaseService._log('TAG_DURATION_PATCH: $e');
      DatabaseService._log(st.toString());
      print(
        'TAG_DURATION_SAVE_FAIL tagId=$tagBizId pbId=$rid status=- error=$e',
      );
      return 'toast_error';
    }
  }

  /// PocketBase `tags_link` values: **only** `tags` collection record ids ([Tag.pbRecordId]).
  /// Resolves by business [Tag.tagId] against [fetchTagsForCurrentUser] when pb id missing on the instance.
  /// Never uses tag name, Noco wrapper id, or any non-PB identifier.
  Future<List<String>> _pbTagRecordIdsFromTags(List<Tag> tags) async {
    if (tags.isEmpty) return [];
    final planCatalog = await fetchTagsForCurrentUser(
      scope: TagCatalogScope.plan,
    );
    final needsListCatalog = tags.any(TagCatalogScope.list.matchesTag);
    final listCatalog = needsListCatalog
        ? await fetchTagsForCurrentUser(scope: TagCatalogScope.list)
        : const <Tag>[];
    final catalog = <Tag>[...planCatalog, ...listCatalog];
    final byBiz = <String, Tag>{};
    for (final t in catalog) {
      if (t.tagId != 0) {
        final domain = TagCatalogScope.list.matchesTag(t) ? 'list' : 'plan';
        byBiz['$domain:${t.tagId}'] = t;
      }
    }
    final out = <String>[];
    final seen = <String>{};
    for (final t in tags) {
      if (!t.rendersAsChip) continue;
      var pid = t.pbRecordId?.trim() ?? '';
      if (pid.isEmpty && t.tagId != 0) {
        final domain = TagCatalogScope.list.matchesTag(t) ? 'list' : 'plan';
        pid = byBiz['$domain:${t.tagId}']?.pbRecordId?.trim() ?? '';
      }
      if (pid.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[PB] _pbTagRecordIdsFromTags: skip — no PocketBase record id '
            '(tagId=${t.tagId} name="${t.name}")',
          );
        }
        continue;
      }
      if (seen.add(pid)) out.add(pid);
    }
    return out;
  }
}
