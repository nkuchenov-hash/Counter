// ignore_for_file: avoid_print
part of 'database_service.dart';

/// Thrown when profile fetch returns 404 or 422 (invalid session / UUID mismatch).
class _ProfileFetchFailedException implements Exception {
  _ProfileFetchFailedException(this.statusCode, [this.message]);
  final int statusCode;
  final String? message;
  @override
  String toString() => message ?? 'Profile fetch failed: $statusCode';
}

/// PocketBase **profiles** auth row id (for PATCH settings); set on profile load.
String? _profilePbRecordId;

String _dataRegion = 'global';

UserSettings _settings = UserSettings(userId: '');

final StreamController<UserSettings> _settingsController =
    StreamController<UserSettings>.broadcast();

/// Last [fetchTagsForCurrentUser] result (`sort_order` then name). Updated on every fetch; not broadcast.
List<Tag> _userTagsCatalogCache = [];

/// Planning **Sort by Tags** grouping refreshes when tag order changes in Tag Manager (no plan list tick).
final StreamController<void> _tagsCatalogRefreshController =
    StreamController<void>.broadcast();

const String _dataRegionKey = 'data_region';
const String _profileTzLabelKey = 'profile_preferred_timezone';
const String _profileTzOffsetKey = 'profile_timezone_offset_hours';
const String _profileThemeModeKey = 'profile_theme_mode';

String _normalizeTimezone(String timezone) {
  final t = timezone.trim();
  if (t.isEmpty) return 'UTC';
  switch (t) {
    case 'London':
    case 'London (UTC+0)':
      return 'UTC';
    case 'Moscow':
    case 'Moscow (UTC+3)':
    case 'Dubai':
      return 'GMT+3';
    case 'Dubai (UTC+4)':
      return 'Dubai';
    case 'New York':
    case 'New York (UTC-5)':
      return 'New York';
    default:
      if (t.contains('Moscow') || t.contains('UTC+3')) return 'GMT+3';
      if (t.contains('Dubai') || t.contains('UTC+4')) return 'Dubai';
      if (t.contains('New York') || t.contains('UTC-5')) return 'New York';
      if (t.contains('London') || t.contains('UTC+0')) return 'UTC';
      return t;
  }
}

bool _profileBool(dynamic value, [bool fallback = false]) {
  if (value == true) return true;
  if (value == false) return false;
  if (value == 1) return true;
  if (value == 0) return false;
  if (value is String) {
    final s = value.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return fallback;
}

int _fixedOffsetHoursFromLabel(String timezone) {
  final tz = _normalizeTimezone(timezone);
  switch (tz) {
    case 'UTC':
      return 0;
    case 'GMT+3':
      return 3;
    case 'Dubai':
      return 4;
    case 'New York':
      return -5;
    default:
      return 0;
  }
}

(DateTime, DateTime) utcRangeForDateInTimezone(
  DateTime selectedDate,
  String timezone,
) {
  final offset = _fixedOffsetHoursFromLabel(timezone);
  return wall_clock.utcWallClockDayBoundsUtc(
    DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
    offset,
    timezone,
  );
}

(DateTime, DateTime) utcRangeForWallClockDate(
  DateTime wallClockDate,
  int offsetHours,
  String preferredTimeZone,
) {
  return wall_clock.utcWallClockDayBoundsUtc(
    wallClockDate,
    offsetHours,
    preferredTimeZone,
  );
}

extension ProfileServiceExtension on DatabaseService {
  static const List<String> _profileTimezoneOptions = [
    'UTC',
    'London',
    'Moscow',
    'Dubai',
    'New York',
  ];
  static List<String> get validTimezonesForProfile =>
      List.from(_profileTimezoneOptions);
  UserSettings get settings => _settings;

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

  /// Background refresh only; does not block UI.
  Future<void> reloadForDataRegionChange() async {
    if ((currentProfileId?.isNotEmpty ?? false)) {
      unawaited(loadInitialData(currentProfileId!));
    }
  }

  String get dataRegion => _dataRegion;

  /// Fetches profile row fresh from PocketBase; falls back to auth cache / `user_id` lookup.
  Future<Map<String, dynamic>?> getUserProfile(String id) async {
    await ensurePocketBaseReady();
    final want = id.trim();
    if (want.isEmpty) return null;
    RecordModel? auth;
    try {
      auth = _pb.authStore.record;
      if (auth != null) {
        final cachedData = Map<String, dynamic>.from(auth.data);
        final cachedUid = (cachedData['user_id'] ?? '').toString().trim();
        if (cachedUid == want || auth.id == want) {
          try {
            final rec = await _pb
                .collection(PbCollections.profiles)
                .getOne(auth.id);
            final data = Map<String, dynamic>.from(rec.data)..['id'] = rec.id;
            _profilePbRecordId = rec.id;
            debugPrint(
              '[ADMIN_FLAG] getUserProfile fresh profiles.is_admin=${data['is_admin']} parsed=${_profileBool(data['is_admin'])}',
            );
            return data;
          } on ClientException catch (e) {
            if (e.statusCode == 401 ||
                e.statusCode == 403 ||
                e.statusCode == 404 ||
                e.statusCode == 422) {
              throw _ProfileFetchFailedException(
                e.statusCode,
                'Session invalid or profile not found',
              );
            }
            debugPrint('[ADMIN_FLAG] getUserProfile fresh auth row failed: $e');
          } catch (e) {
            debugPrint('[ADMIN_FLAG] getUserProfile fresh auth row failed: $e');
          }
        }
      }
    } catch (_) {}
    try {
      if (auth != null) {
        final data = Map<String, dynamic>.from(auth.data);
        data['id'] = auth.id;
        final uid = (data['user_id'] ?? '').toString().trim();
        if (uid == want || auth.id == want) {
          _profilePbRecordId = auth.id;
          debugPrint(
            '[ADMIN_FLAG] getUserProfile cached profiles.is_admin=${data['is_admin']} parsed=${_profileBool(data['is_admin'])}',
          );
          return data;
        }
      }
    } catch (_) {}
    try {
      final escaped = want.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      final rec = await _pb
          .collection(PbCollections.profiles)
          .getFirstListItem('user_id = "$escaped"');
      _profilePbRecordId = rec.id;
      final data = Map<String, dynamic>.from(rec.data)..['id'] = rec.id;
      debugPrint(
        '[ADMIN_FLAG] getUserProfile list profiles.is_admin=${data['is_admin']} parsed=${_profileBool(data['is_admin'])}',
      );
      return data;
    } on ClientException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 403 || e.statusCode == 422) {
        throw _ProfileFetchFailedException(
          e.statusCode,
          'Session invalid or profile not found',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Shell: current profile as map (snake_case keys aligned with UI).
  /// Rethrows _ProfileFetchFailedException so loadInitialData can force logout on 422/404.
  Future<Map<String, dynamic>> getCurrentUserProfileMap() async {
    try {
      final id = currentProfileId;
      if (id == null || id.isEmpty) return {};
      final m = await getUserProfile(id);
      return m ?? {};
    } on _ProfileFetchFailedException {
      rethrow;
    } catch (_) {
      return {};
    }
  }

  /// After Noco profile load: **device prefs win** for theme + timezone so a stale server row
  /// (e.g. default "New York" / `system`) cannot wipe what the user saved in-app (@DATA_MAP §profiles).
  static String _prefsKeyShowListTagsOnCards(String uid) =>
      'lists_show_tags_on_cards_${uid.trim()}';

  /// Lists inbox: persist tag strip visibility per auth user (device prefs; merged into [UserSettings]).
  Future<void> persistShowListTagsOnCards(bool value) async {
    final aid = _requireAuthUserIdForWrite();
    _settings = _settings.copyWith(showListTagsOnCards: value);
    _settingsController.add(_settings);
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyShowListTagsOnCards(aid), value);
    } catch (_) {}
  }

  void _mergeDeviceProfilePreferenceOverridesSync() {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      final tm = prefs.getString(_profileThemeModeKey)?.trim().toLowerCase();
      var next = _settings;
      if (tm == 'light' || tm == 'dark' || tm == 'system') {
        next = next.copyWith(themeMode: tm);
      }
      final tzLabel = prefs.getString(_profileTzLabelKey)?.trim();
      if (tzLabel != null && tzLabel.isNotEmpty) {
        final oh =
            prefs.getInt(_profileTzOffsetKey) ??
            _fixedOffsetHoursFromLabel(tzLabel);
        next = next.copyWith(
          preferredTimeZone: tzLabel,
          timezoneOffsetHours: oh,
        );
      }
      final uid = next.userId.trim();
      if (uid.isNotEmpty) {
        final showTags = prefs.getBool(_prefsKeyShowListTagsOnCards(uid));
        if (showTags != null) {
          next = next.copyWith(showListTagsOnCards: showTags);
        }
      }
      _settings = next;
    } catch (_) {}
  }

  Future<void> _loadSettingsFromNoco() async {
    try {
      final data = await getCurrentUserProfileMap();
      if (data.isEmpty) {
        throw _ProfileFetchFailedException(
          404,
          'Profile not found — cannot load timezone or user_id',
        );
      }
      final rowUid = data['user_id']?.toString().trim() ?? '';
      if (rowUid.isEmpty) {
        throw _ProfileFetchFailedException(422, 'Profile row missing user_id');
      }
      DatabaseService._log('Profile data loaded from PocketBase.');
      final authUid = _userIdForWhere ?? '';
      final uid = data['user_id']?.toString().trim();
      final raw = data['active_languages'];
      List<String>? activeLanguages;
      if (raw is List) {
        activeLanguages = raw
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (activeLanguages.isEmpty) activeLanguages = null;
      }
      final region = data['data_region'] as String?;
      if (region == 'russia' || region == 'global') _dataRegion = region!;
      final tzLabel = (data['preferred_timezone'] as String? ?? 'UTC').trim();
      final tzOffsetRaw = data['timezone_offset'];
      final tzOffset = tzOffsetRaw == null
          ? _fixedOffsetHoursFromLabel(tzLabel.isEmpty ? 'UTC' : tzLabel)
          : (tzOffsetRaw is int
                ? tzOffsetRaw
                : int.tryParse(tzOffsetRaw.toString()) ?? 0);
      final dc = data['default_category_id'];
      final rawTheme = (data['theme_mode'] as String?)?.trim().toLowerCase();
      String themeMode;
      if (rawTheme == 'light' || rawTheme == 'dark' || rawTheme == 'system') {
        themeMode = rawTheme!;
      } else {
        try {
          final prefs = _prefs ?? await SharedPreferences.getInstance();
          final cached = prefs
              .getString(_profileThemeModeKey)
              ?.trim()
              .toLowerCase();
          themeMode =
              (cached == 'light' || cached == 'dark' || cached == 'system')
              ? cached!
              : 'system';
        } catch (_) {
          themeMode = 'system';
        }
      }
      final dn = data['display_name'] as String?;
      final tagModeRaw = data['tag_display_mode']?.toString().trim();
      final rawListBeh = data['list_completion_behavior'];
      final listBehRaw = rawListBeh == null
          ? ''
          : rawListBeh.toString().trim().toLowerCase();
      final listBeh =
          (listBehRaw == 'stay' ||
              listBehRaw == 'bottom' ||
              listBehRaw == 'hide' ||
              listBehRaw == 'archive')
          ? listBehRaw
          : (listBehRaw.isEmpty ? 'stay' : 'hide');
      final settingsUserId = authUid.isNotEmpty
          ? authUid
          : (uid != null && uid.isNotEmpty ? uid : rowUid);
      final rawAdmin = data['is_admin'];
      final parsedAdmin = _profileBool(rawAdmin);
      debugPrint(
        '[ADMIN_FLAG] _loadSettingsFromNoco raw profiles.is_admin=$rawAdmin parsed=$parsedAdmin',
      );
      _settings = UserSettings(
        userId: settingsUserId,
        language: data['primary_language'] as String? ?? 'en',
        preferredTimeZone: tzLabel.isEmpty ? 'UTC' : tzLabel,
        timezoneOffsetHours: tzOffset,
        activeLanguages: activeLanguages,
        primaryLanguage: data['primary_language'] as String? ?? 'en',
        defaultCategoryId: dc == null
            ? null
            : CategoryServiceExtension._rowInt(dc),
        hasSeeded: data['has_seeded'] == true,
        dataRegion: region,
        biometricEnabled: data['biometric_enabled'] == true,
        isAdmin: parsedAdmin,
        themeMode: themeMode,
        displayName: dn != null && dn.trim().isNotEmpty ? dn.trim() : null,
        tagDisplayMode: categoryDisplayModeFromWire(tagModeRaw),
        tagDisplayModeWireRaw: (tagModeRaw != null && tagModeRaw.isNotEmpty)
            ? tagModeRaw
            : null,
        listCompletionBehavior: listBeh,
        showListTagsOnCards: true,
      );
      _mergeDeviceProfilePreferenceOverridesSync();
      debugPrint(
        '[ADMIN_FLAG] _loadSettingsFromNoco settings.isAdmin=${_settings.isAdmin}',
      );
      _settingsController.add(_settings);
      _syncMaterialAppLocaleFromSettings(_settings);
    } on _ProfileFetchFailedException {
      rethrow;
    } catch (_) {
      final authUid = _userIdForWhere ?? '';
      final fallback = currentProfileId?.trim() ?? '';
      final uidStr = authUid.isNotEmpty ? authUid : fallback;
      _settings = UserSettings(userId: uidStr);
      _mergeDeviceProfilePreferenceOverridesSync();
      _settingsController.add(_settings);
    }
  }

  DateTime getProjectedToday() {
    final utc = DateTime.now().toUtc();
    final view = _profileWallFromUtc(utc);
    return DateTime(view.year, view.month, view.day);
  }

  DateTime applyUserOffset(DateTime utcDate) {
    return _profileWallFromUtc(utcDate);
  }

  DateTime displayTimeToUtc(DateTime displayNaive) {
    return _profileUtcFromWall(displayNaive);
  }

  String getProjectedTodayDateKey() {
    final t = getProjectedToday();
    return '${t.year}-${_two(t.month)}-${_two(t.day)}';
  }

  /// Timeline calendar “today” / strip anchor: **profile wall-clock** ([getProjectedToday]), per [DATA_MAP] records §8 / [wall_clock] (not device TZ).
  DateTime getTimelineDeviceLocalToday() => getProjectedToday();

  String getTimelineDeviceLocalTodayDateKey() => getProjectedTodayDateKey();

  void _syncMaterialAppLocaleFromSettings(UserSettings s) {
    final raw = s.primaryLanguage.trim().isNotEmpty
        ? s.primaryLanguage
        : s.language;
    final code = resolvedUiLanguageCode(raw);
    if (currentLocale.value != code) {
      currentLocale.value = code;
    }
  }

  /// UI-first: update state immediately; then PocketBase PATCH on **profiles** auth row.
  Future<bool> saveSettings(UserSettings s) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }

    final authId = _requireAuthUserIdForWrite();
    final lang = resolvedUiLanguageCode(
      s.primaryLanguage.trim().isNotEmpty ? s.primaryLanguage : s.language,
    );
    final coerced = s.copyWith(
      primaryLanguage: lang,
      language: lang,
      activeLanguages: <String>[lang],
    );
    _settings = coerced.copyWith(userId: authId);
    _settingsController.add(_settings);
    _syncMaterialAppLocaleFromSettings(_settings);
    _notifyTimelineAfterRecordCacheMutation();

    try {
      await ensurePocketBaseReady();
      final pbId = (_profilePbRecordId ?? _pb.authStore.record?.id)?.trim();
      if (pbId == null || pbId.isEmpty) return false;
      final profileBody = ProfileUpdate.fromSettings(coerced).toJson();
      await _pb
          .collection(PbCollections.profiles)
          .update(pbId, body: profileBody);
      final patchedTagWire = profileBody['tag_display_mode']?.toString();
      if (patchedTagWire != null && patchedTagWire.isNotEmpty) {
        _settings = _settings.copyWith(tagDisplayModeWireRaw: patchedTagWire);
        _settingsController.add(_settings);
      }
      DatabaseService._log('Timezone synced to PocketBase.');
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        await prefs.setString(_profileThemeModeKey, coerced.themeMode);
        await prefs.setString(_profileTzLabelKey, coerced.preferredTimeZone);
        await prefs.setInt(_profileTzOffsetKey, coerced.timezoneOffsetHours);
      } catch (_) {}
      return true;
    } on ClientException catch (e) {
      DatabaseService._log('SAVE_SETTINGS: PocketBase ${e.statusCode} — $e');
      return false;
    } catch (e, st) {
      DatabaseService._log('SAVE_SETTINGS: request failed — $e');
      DatabaseService._log(st);
      return false;
    }
  }

  Future<bool> updateTimeZone(String label) async {
    final ok = await saveSettings(
      _settings.copyWith(
        preferredTimeZone: label,
        timezoneOffsetHours: _fixedOffsetHoursFromLabel(label),
      ),
    );
    reprojectAllPlansForProfileTimezone();
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    _notifyTimelineAfterRecordCacheMutation();
    return ok;
  }

  Future<bool> updateUserTimezone(double offsetHours) async {
    final ok = await saveSettings(
      _settings.copyWith(timezoneOffsetHours: offsetHours.round()),
    );
    reprojectAllPlansForProfileTimezone();
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    _notifyTimelineAfterRecordCacheMutation();
    return ok;
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
  Future<bool> patchTagDefaultPlanDurationForCurrentUser({
    required String pocketRecordId,
    int? durationMinutes,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    final rid = pocketRecordId.trim();
    if (rid.isEmpty) return false;
    final sanitized = durationMinutes == null
        ? null
        : DatabaseService.instance.sanitizeTagDefaultPlanDurationMinutes(
            durationMinutes,
          );
    try {
      final body = <String, dynamic>{
        'user_id': _pidForPbFilter,
      };
      if (sanitized == null) {
        body['default_plan_duration_minutes'] = null;
      } else {
        body['default_plan_duration_minutes'] = sanitized;
      }
      await _pb.collection(PbCollections.tags).update(rid, body: body);
      _userTagsCatalogCache = [
        for (final t in _userTagsCatalogCache)
          if (t.pbRecordId == rid)
            t.copyWith(
              defaultPlanDurationMinutes: sanitized,
              clearDefaultPlanDuration: sanitized == null,
            )
          else
            t,
      ];
      notifyTagsCatalogChanged();
      return true;
    } catch (e, st) {
      DatabaseService._log('TAG_DURATION_PATCH: $e');
      DatabaseService._log(st.toString());
      return false;
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
