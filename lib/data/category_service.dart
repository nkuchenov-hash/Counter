part of 'database_service.dart';

// Category domain extracted from database_service.dart (V5.4).
// Contains: fetchCategories, _loadRulesFromNoco, category CRUD,
// smart-match, slug helpers, stats, and supporting utilities.

extension CategoryServiceExtension on DatabaseService {
  /// PocketBase: all **categories** for the signed-in `user_id` (@DATA_MAP).
  Future<void> refreshCategoryRulesFromServer() => _loadRulesFromNoco();

  /// Breadcrumb of local category ids from root to [leafLocalId] (inclusive).
  static Map<String, dynamic> _flattenNocoRecord(
    Map<String, dynamic> record, {
    bool allowCategoryIdAsRowPk = false,
  }) {
    if (record.containsKey('fields') && record['fields'] is Map) {
      final fields = Map<String, dynamic>.from(record['fields'] as Map);
      // Compatibility shim: some tables expose a string relational key as 'id1'.
      // We do not use 'id1' in app logic; we map it into 'normalized_id' if missing.
      if (!fields.containsKey('normalized_id') &&
          fields.containsKey('id1') &&
          fields['id1'] != null &&
          fields['id1'].toString().trim().isNotEmpty) {
        fields['normalized_id'] = fields['id1'].toString().trim();
      }
      final envPk = DatabaseService._envelopePkOnlyFromWrapper(record);
      final uuidInFields = allowCategoryIdAsRowPk
          ? null
          : DatabaseService._firstUuidLikeRecordIdInFields(fields);

      if (!allowCategoryIdAsRowPk) {
        // Records/plans: REST path = **system integer** from wrapper only (never business UUID).
        final sysInt = DatabaseService._parseSystemIntFromWrapper(record);
        if (sysInt != null) {
          fields[DatabaseService._nocoSystemRowIdKey] = sysInt;
          fields['id'] = sysInt;
        }
        if (uuidInFields != null &&
            (envPk == null || _isSmallIntegerString(envPk))) {
          fields[DatabaseService._nocoEnvelopePkKey] = uuidInFields;
        } else if (envPk != null) {
          fields[DatabaseService._nocoEnvelopePkKey] = envPk;
        }
        // M2M link column may sit on the v3 list **envelope** (nested expand) or match `fields`
        // when using `fields=` GET. If the wrapper has the link key, **overwrite** `fields` so
        // chips survive refresh.
        final linkKey = _plansToTagsLinkColumnSystemId;
        if (record.containsKey(linkKey)) {
          fields[linkKey] = record[linkKey];
        }
        return fields;
      }

      if (envPk != null) {
        fields[DatabaseService._nocoEnvelopePkKey] = envPk;
      }

      dynamic resolvedPk =
          record['id'] ??
          record['Id'] ??
          record['ID'] ??
          record['record_id'] ??
          record['Record_id'];
      final rs = resolvedPk?.toString().trim() ?? '';
      if (rs.isEmpty) {
        resolvedPk =
            fields['record_id'] ??
            fields['Record_id'] ??
            fields['id'] ??
            fields['Id'] ??
            fields['ID'];
      }
      final rs2 = resolvedPk?.toString().trim() ?? '';
      if (rs2.isEmpty) {
        resolvedPk =
            fields['category_id'] ??
            fields['Category_id'] ??
            record['category_id'] ??
            record['Category_id'];
      }
      final stamped = DatabaseService._sanitizePkString(
        fields[DatabaseService._nocoEnvelopePkKey]?.toString(),
      );
      if (stamped != null && stamped.isNotEmpty) {
        fields['id'] = stamped;
        resolvedPk = stamped;
      }
      final pkStr = resolvedPk?.toString().trim() ?? '';
      if (pkStr.isNotEmpty) {
        fields['id'] = resolvedPk;
      }
      // Categories (@DATA_MAP): REST row URL must use wrapper **Id** (int). Never leave `id` as
      // `category_id` UUID after fallbacks above.
      final categoryWrapperSysId = DatabaseService._parseSystemIntFromWrapper(
        record,
      );
      if (categoryWrapperSysId != null && categoryWrapperSysId > 0) {
        fields[DatabaseService._nocoSystemRowIdKey] = categoryWrapperSysId;
        fields['id'] = categoryWrapperSysId;
      }
      return fields;
    }
    final flat = Map<String, dynamic>.from(record);
    if (!allowCategoryIdAsRowPk) {
      final sysInt = DatabaseService._parseSystemIntFromWrapper(record);
      if (sysInt != null) {
        flat[DatabaseService._nocoSystemRowIdKey] = sysInt;
        flat['id'] = sysInt;
      }
      final envFlat = DatabaseService._envelopePkOnlyFromWrapper(flat);
      final uuidFlat = DatabaseService._firstUuidLikeRecordIdInFields(flat);
      if (uuidFlat != null &&
          (envFlat == null || _isSmallIntegerString(envFlat))) {
        flat[DatabaseService._nocoEnvelopePkKey] = uuidFlat;
      } else if (envFlat != null) {
        flat[DatabaseService._nocoEnvelopePkKey] = envFlat;
      }
      return flat;
    }
    final rpFlat = DatabaseService._wrapperRestPathIdOnly(record);
    if (rpFlat != null && rpFlat.isNotEmpty) {
      flat[DatabaseService._nocoCategoryRestSegmentKey] = rpFlat;
    }
    final envFlat = DatabaseService._envelopePkOnlyFromWrapper(flat);
    if (envFlat != null) {
      flat[DatabaseService._nocoEnvelopePkKey] = envFlat;
    }
    final catSys = DatabaseService._parseSystemIntFromWrapper(record);
    if (catSys != null && catSys > 0) {
      flat[DatabaseService._nocoSystemRowIdKey] = catSys;
      flat['id'] = catSys;
    }
    return flat;
  }

  /// PocketBase **records** row id (string) or legacy numeric id string.
  static String recordsTablePk(Map<String, dynamic> row) {
    final pb = row['_pb_record_id']?.toString().trim() ?? '';
    if (pb.isNotEmpty) return pb;
    final idStr = row['id']?.toString().trim() ?? '';
    if (idStr.isNotEmpty && int.tryParse(idStr) == null) {
      return idStr;
    }
    final sys = row[DatabaseService._nocoSystemRowIdKey];
    if (sys is int) return sys.toString();
    if (sys != null) {
      final p = int.tryParse(sys.toString());
      if (p != null) return p.toString();
    }
    final idRaw = row['id'];
    if (idRaw is int) return idRaw.toString();
    final parsed = int.tryParse((idRaw ?? '').toString().trim());
    if (parsed != null) return parsed.toString();
    return '';
  }

  static int _rowInt(dynamic v, [int d = 0]) {
    if (v == null) return d;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? d;
  }

  /// When updating a row, include business `record_id` in `fields` if known (Noco column alignment).
  static void _mergeBusinessRecordIdIntoFields(
    Map<String, dynamic> fields,
    Map<String, dynamic>? row,
  ) {
    if (row == null) return;
    final biz = (row['record_id'] ?? '').toString().trim();
    if (biz.isNotEmpty) fields['record_id'] = biz;
  }

  void _purgeGhostRecordById(String recordId) {
    final rid = recordId.trim();
    if (rid.isEmpty) return;
    final blockKeys = _collectRecordKeysFromCache(rid);
    for (final k in blockKeys) {
      if (k.isNotEmpty) _recordRestDefinitive404Keys.add(k);
    }
    if (rid.isNotEmpty) _recordRestDefinitive404Keys.add(rid);
    _cachedFlatRecords.removeWhere((r) {
      final pk = recordsTablePk(r).trim();
      if (pk == rid) return true;
      final sys = r[DatabaseService._nocoSystemRowIdKey];
      if (sys is int && sys.toString() == rid) return true;
      if (sys != null && sys.toString().trim() == rid) return true;
      final env = (r[DatabaseService._nocoEnvelopePkKey] ?? '')
          .toString()
          .trim();
      if (env.isNotEmpty && env == rid) return true;
      final localId = (r['id'] ?? '').toString().trim();
      final localRecordId = (r['record_id'] ?? '').toString().trim();
      return localId == rid || localRecordId == rid;
    });
    _notifyTimelineAfterRecordCacheMutation();
    DatabaseService._log('SYNC: purged ghost local record id=$rid after 404');
  }

  /// ACTIVE_STATUS_LAW (@ARCHITECTURE.md): running ⇔ no end_time **and** status == running.
  static bool isRecordMapActuallyRunning(Map<String, dynamic> data) {
    final end = data['endTime'] ?? data['end_time'];
    if (end != null && end.toString().trim().isNotEmpty) return false;
    final s = (data['status'] as String? ?? '').trim();
    return s == 'running';
  }

  /// Flat Noco row (snake_case) before [_rowToRecordMap].
  /// UI / streams: only explicit `running` counts as active.
  static bool _isNocoRowActiveRunning(Map<String, dynamic> r) {
    final end = r['end_time'] ?? r['endTime'];
    if (end != null && end.toString().trim().isNotEmpty) return false;
    final s = (r['status'] ?? '').toString().trim().toLowerCase();
    return s == 'running';
  }

  /// Singleton enforcement: any **open** interval (no end_time) that is not clearly completed/stopped.
  /// Closes legacy rows missing `status` so two timers cannot stay open (@ARCHITECTURE §3).
  static bool _isNocoRowSacredStopTarget(Map<String, dynamic> r) {
    final end = r['end_time'] ?? r['endTime'];
    if (end != null && end.toString().trim().isNotEmpty) return false;
    final s = (r['status'] ?? '').toString().trim().toLowerCase();
    if (s == 'stopped' || s == 'completed') return false;
    if (s == 'running') return true;
    if (s.isEmpty) return true;
    return false;
  }

  /// Sacred Law scope: only rows whose [start_time] falls on **profile wall-clock today**
  /// (same as timeline buckets). Avoids PATCHing legacy `running` ghosts from other wall-clock days.

  /// Day-bucket key for a stored UTC instant: profile wall date, never raw UTC Y-M-D / never [DateTime.toLocal].
  String _timelineDeviceLocalDayKeyFromUtc(DateTime utcInstant) {
    final wall = _profileWallFromUtc(utcInstant.toUtc());
    return _dateKeyFromDate(DateTime(wall.year, wall.month, wall.day));
  }

  /// **Deprecated:** Full-tree category PATCH is disabled. Use [patchCategoryDelta], [updateCategory],
  /// [addNestedCategory], [updateCategoryParent], etc. — one network call per user intent.
  Future<void> persistRules() async {
    DatabaseService._log(
      'CATEGORY_FULL_SYNC_DISABLED: persistRules() is a no-op — use targeted category APIs (single id per PATCH).',
    );
  }


  /// Replaces the in-memory category tree only. Does **not** upload the whole table to Noco.
  /// Push per-row changes with [patchCategoryDelta] / [updateCategory] / [addNestedCategory].
  Future<void> setRulesAndSave(List<CategoryRule> newRules) async {
    _rules = List.from(newRules);
    _categoryController.add(List.from(_rules));
  }






  Future<void> updateCategoryKeywords(
    int categoryId,
    Map<String, List<String>> keywords,
  ) async {
    try {
      final rule = getCategoryRuleById(categoryId);
      if (rule == null) return;
      final pbId = _categoryBackendRowIdStrict(rule);
      if (pbId == null) {
        return;
      }
      final biz = _categoryStringPkForApi(rule);
      await ensurePocketBaseReady();
      final body = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pidForPbFilter,
          if (biz != null && biz.isNotEmpty) 'category_id': biz,
          'keywords': keywords,
          'order': rule.order,
        }),
      );
      await _pb.collection(PbCollections.categories).update(pbId, body: body);
      await _loadRulesFromNoco();
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
    } catch (e, st) {
      DatabaseService._log('UPDATE_CATEGORY_KEYWORDS: $e');
      DatabaseService._log('$st');
    }
  }

  void updateCategoryLocalizedNames(int id, Map<String, String> names) {
    void visit(List<CategoryRule> rules) {
      for (var i = 0; i < rules.length; i++) {
        final r = rules[i];
        if (r.id == id) {
          rules[i] = r.copyWith(localizedNames: names);
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
  }

  Future<String?> translateKeyword(
    String text, {
    required String fromLang,
    required String toLang,
  }) async {
    return text;
  }

  int? get defaultCategoryId {
    final d = _settings.defaultCategoryId;
    if (d != null && categoryExists(d)) return d;
    if (_rules.isNotEmpty) return _rules.first.id;
    return null;
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(' ', '').trim();

  static int recordDurationSeconds(Map<String, dynamic> rec) {
    final type = rec['type'] as String? ?? 'record';
    if (type == 'planned') return 0;
    final start = startTimeFromRecord(rec);
    if (start == null) return 0;
    final endParsed = endTimeFromRecord(rec);
    if (endParsed != null) {
      return endParsed.difference(start).inSeconds;
    }
    final status = (rec['status'] as String? ?? '').toLowerCase();
    if (status == 'running') {
      return DatabaseService.getPlanetaryNow().difference(start).inSeconds;
    }
    return 0;
  }

  static DateTime? startTimeFromRecord(Map<String, dynamic> rec) {
    final v = rec['startTime'];
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    if (v is String) return DateTime.tryParse(v)?.toUtc();
    return null;
  }

  static DateTime? endTimeFromRecord(Map<String, dynamic> rec) {
    final status = rec['status'] as String? ?? 'completed';
    if (status == 'running') return null;
    final v = rec['endTime'];
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    if (v is String) return DateTime.tryParse(v)?.toUtc();
    return null;
  }

  /// Uses profile [offsetHours] (profiles.timezone_offset) for day bounds — same as timeline day bucket.
  static int recordDurationSecondsWithinDayFromTimestamps(
    Map<String, dynamic> rec,
    DateTime selectedDay,
    int offsetHours,
    String preferredTimeZone,
  ) {
    final type = rec['type'] as String? ?? 'record';
    if (type == 'planned') return 0;
    final start = startTimeFromRecord(rec);
    if (start == null) return 0;
    final endParsed = endTimeFromRecord(rec);
    final status = (rec['status'] as String? ?? '').toLowerCase();
    final DateTime end;
    if (endParsed != null) {
      end = endParsed;
    } else if (status == 'running') {
      end = DatabaseService.getPlanetaryNow();
    } else {
      end = start;
    }
    final (DateTime dayStart, DateTime dayEnd) = utcRangeForWallClockDate(
      selectedDay,
      offsetHours,
      preferredTimeZone,
    );
    final effectiveStart = start.isBefore(dayStart) ? dayStart : start;
    final effectiveEnd = end.isAfter(dayEnd) ? dayEnd : end;
    if (!effectiveStart.isBefore(effectiveEnd)) return 0;
    return effectiveEnd.difference(effectiveStart).inSeconds;
  }

  /// Strong signature so stats cache cannot reuse another day’s tree when length/first/last collide.
  static int statsRecordsSignature(
    List<Map<String, dynamic>> records,
    DateTime selectedDay,
  ) {
    var h = Object.hash(
      2,
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      records.length,
    );
    for (final r in records) {
      h = Object.hash(
        h,
        (r['record_id'] ?? r['id'] ?? '').toString(),
        r['startTime']?.toString() ?? '',
        r['endTime']?.toString() ?? '',
        (r['title'] ?? '').toString(),
      );
    }
    return h;
  }


  ({String title, List<String> tags}) getCleanTitleAndTags(String input) {
    final tags = <String>[];
    final words = input.trim().split(RegExp(r'\s+'));
    final titleParts = <String>[];
    for (final w in words) {
      if (w.startsWith('#')) {
        if (w.length > 1) tags.add(w);
      } else {
        titleParts.add(w);
      }
    }
    final title = titleParts.join(' ').trim();
    return (title: title.isEmpty ? input.trim() : title, tags: tags);
  }

  Future<List<Task>> loadTasksForDate(DateTime date) async {
    return RebuildMetrics.instance.perfBlockAsync(
      'Category.loadTasksForDate',
      () async {
    final prefs = _prefs;
    if (prefs == null) return [];
    try {
      final key = _tasksKeyForDate(date);
      final list = prefs.getStringList(key);
      if (list == null || list.isEmpty) return [];
      return list
          .map(
            (s) =>
                Task.fromMap(Map<String, dynamic>.from(jsonDecode(s) as Map)),
          )
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    } catch (_) {
      return [];
    }
      },
      meta: {
        'date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      },
    );
  }

  Future<void> saveTasks(DateTime date, List<Task> tasks) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setStringList(
        _tasksKeyForDate(date),
        tasks.map((t) => t.toJson()).toList(),
      );
    } catch (_) {}
  }

  Stream<bool> get connectionStream => Stream.value(true);

  /// Parse NocoDB date string as UTC so Moscow (UTC+3) is not treated as UTC.
  static DateTime? _parseDateTimeUtc(dynamic v) {
    if (v == null) return null;
    // Local DateTime from any source: convert properly — never treat wall components as UTC.
    if (v is DateTime) return v.isUtc ? v : v.toUtc();
    if (v is String) {
      var s = v.trim();
      if (s.isEmpty) return null;
      // NocoDB often returns "YYYY-MM-DD HH:MM:SS+00" or without timezone.
      // Normalize to ISO-8601 before parse.
      s = s.replaceAll(' ', 'T');
      if (RegExp(r'[+-]\d{2}$').hasMatch(s)) {
        s = '$s:00';
      }
      final hasTz =
          s.endsWith('Z') ||
          s.contains('+') ||
          (s.length > 11 && s.substring(11).contains('-'));
      final parsed = DateTime.tryParse(hasTz ? s : '${s}Z');
      return parsed?.toUtc();
    }
    return null;
  }

  static bool _isLikelyUuidOrLongPk(String s) {
    final t = s.trim();
    if (t.length >= 28) return true;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(t);
  }

  static bool _isSmallIntegerString(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^\d{1,9}$').hasMatch(t);
  }
}
