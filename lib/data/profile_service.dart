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

String? _lastProfileBootLogKey;
DateTime? _lastProfileBootLogAt;
String? _lastProfileHydratedLogKey;
DateTime? _lastProfileHydratedLogAt;
const Duration _profileDiagLogDebounce = Duration(seconds: 8);

void _profileDiagLog(String line, {String? dedupeKey}) {
  final now = DateTime.now();
  if (dedupeKey != null) {
    if (_lastProfileBootLogKey == dedupeKey &&
        _lastProfileBootLogAt != null &&
        now.difference(_lastProfileBootLogAt!) < _profileDiagLogDebounce) {
      return;
    }
    _lastProfileBootLogKey = dedupeKey;
    _lastProfileBootLogAt = now;
  }
  print(line);
}

void _profileHydratedLog({
  required String id,
  required String lang,
  required String tz,
  required int offset,
  required bool isAdmin,
}) {
  final key = '$id|$lang|$tz|$offset|$isAdmin';
  final now = DateTime.now();
  if (_lastProfileHydratedLogKey == key &&
      _lastProfileHydratedLogAt != null &&
      now.difference(_lastProfileHydratedLogAt!) < _profileDiagLogDebounce) {
    return;
  }
  _lastProfileHydratedLogKey = key;
  _lastProfileHydratedLogAt = now;
  print(
    'PROFILE_HYDRATED id=$id source=pb lang=$lang tz=$tz offset=$offset isAdmin=$isAdmin',
  );
  print('PROFILE_ADMIN_STATE isAdmin=$isAdmin source=pb');
}

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
  List<String> get profileTimezoneOptions => validTimezonesForProfile;
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

  /// Fetches profile row fresh from PocketBase (never stale authStore-only for hydration).
  Future<Map<String, dynamic>?> getUserProfile(String id) async {
    await ensurePocketBaseReady();
    final want = id.trim();
    if (want.isEmpty) return null;
    _profileDiagLog(
      'PROFILE_FETCH_REQUEST id=$want',
      dedupeKey: 'fetch|$want',
    );

    if (_pb.authStore.isValid) {
      final auth = _pb.authStore.record;
      final authId = auth?.id.trim() ?? '';
      if (authId.isNotEmpty) {
        try {
          final rec = await _pb
              .collection(PbCollections.profiles)
              .getOne(authId);
          final data = Map<String, dynamic>.from(rec.data)..['id'] = rec.id;
          _profilePbRecordId = rec.id;
          final lang = (data['primary_language'] ?? '-').toString();
          final tz = (data['preferred_timezone'] ?? '-').toString();
          final off = data['timezone_offset'];
          final admin = _profileBool(data['is_admin']);
          _profileDiagLog(
            'PROFILE_FETCH_SUCCESS id=$authId lang=$lang tz=$tz offset=$off isAdmin=$admin',
            dedupeKey: 'ok|$authId|$lang|$tz|$admin',
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
          _profileDiagLog(
            'PROFILE_FETCH_FAIL id=$authId status=${e.statusCode} error=$e',
            dedupeKey: 'fail|$authId|${e.statusCode}',
          );
        } catch (e) {
          _profileDiagLog(
            'PROFILE_FETCH_FAIL id=$authId error=$e',
            dedupeKey: 'fail|$authId|err',
          );
        }
      }
    }

    try {
      final escaped = want.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      final rec = await _pb
          .collection(PbCollections.profiles)
          .getFirstListItem('user_id = "$escaped"');
      _profilePbRecordId = rec.id;
      final data = Map<String, dynamic>.from(rec.data)..['id'] = rec.id;
      final lang = (data['primary_language'] ?? '-').toString();
      final tz = (data['preferred_timezone'] ?? '-').toString();
      final off = data['timezone_offset'];
      final admin = _profileBool(data['is_admin']);
      _profileDiagLog(
        'PROFILE_FETCH_SUCCESS id=${rec.id} lang=$lang tz=$tz offset=$off isAdmin=$admin',
        dedupeKey: 'list|${rec.id}|$lang|$tz|$admin',
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

  /// Mirror PB-hydrated settings into device prefs (write-only cache; never overrides PB on boot).
  Future<void> _mirrorProfileSettingsToDeviceCache() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_profileThemeModeKey, _settings.themeMode);
      await prefs.setString(_profileTzLabelKey, _settings.preferredTimeZone);
      await prefs.setInt(_profileTzOffsetKey, _settings.timezoneOffsetHours);
    } catch (_) {}
  }

  String? _themeModeFromPrefsFallback() {
    try {
      final prefs = _prefs;
      if (prefs == null) return null;
      final cached = prefs.getString(_profileThemeModeKey)?.trim().toLowerCase();
      if (cached == 'light' || cached == 'dark' || cached == 'system') {
        return cached;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _diffProfilePatchFields(
    UserSettings prev,
    UserSettings next,
  ) {
    final fields = <String, dynamic>{};
    final nextLang = resolvedUiLanguageCode(
      next.primaryLanguage.trim().isNotEmpty ? next.primaryLanguage : next.language,
    );
    final prevLang = resolvedUiLanguageCode(
      prev.primaryLanguage.trim().isNotEmpty ? prev.primaryLanguage : prev.language,
    );
    if (nextLang != prevLang) {
      fields['primary_language'] = nextLang;
      fields['active_languages'] = <String>[nextLang];
    }
    if (next.preferredTimeZone != prev.preferredTimeZone ||
        next.timezoneOffsetHours != prev.timezoneOffsetHours) {
      fields['preferred_timezone'] = next.preferredTimeZone;
      fields['timezone_offset'] = next.timezoneOffsetHours;
    }
    if (next.themeMode != prev.themeMode) {
      fields['theme_mode'] = next.themeMode;
    }
    final nextDn = next.displayName?.trim() ?? '';
    final prevDn = prev.displayName?.trim() ?? '';
    if (nextDn != prevDn) {
      fields['display_name'] = nextDn.isEmpty ? null : nextDn;
    }
    if (next.tagDisplayMode != prev.tagDisplayMode ||
        tagDisplayModeWireForPatch(next) !=
            tagDisplayModeWireForPatch(prev)) {
      fields['tag_display_mode'] = tagDisplayModeWireForPatch(next);
    }
    if (next.listCompletionBehavior != prev.listCompletionBehavior) {
      fields['list_completion_behavior'] =
          listCompletionBehaviorWireForPatch(next);
    }
    return fields;
  }

  Future<void> _loadSettingsFromNoco() async {
    try {
      final authValid = _pb.authStore.isValid;
      final authId = _pb.authStore.record?.id.trim() ?? '';
      _profileDiagLog(
        'PROFILE_BOOT_START authValid=$authValid authId=${authId.isEmpty ? '-' : authId}',
        dedupeKey: 'boot|$authValid|$authId',
      );
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
      final tzLabel = (data['preferred_timezone'] as String? ?? '').trim();
      final resolvedTzLabel = tzLabel.isEmpty ? 'UTC' : tzLabel;
      final tzOffsetRaw = data['timezone_offset'];
      final tzOffset = tzOffsetRaw == null
          ? _fixedOffsetHoursFromLabel(resolvedTzLabel)
          : (tzOffsetRaw is int
                ? tzOffsetRaw
                : int.tryParse(tzOffsetRaw.toString()) ?? 0);
      final dc = data['default_category_id'];
      final rawTheme = (data['theme_mode'] as String?)?.trim().toLowerCase();
      String themeMode;
      if (rawTheme == 'light' || rawTheme == 'dark' || rawTheme == 'system') {
        themeMode = rawTheme!;
      } else {
        final cached = _themeModeFromPrefsFallback();
        if (cached != null) {
          themeMode = cached;
          _profileDiagLog(
            'PROFILE_FALLBACK_USED reason=missing_pb_theme_mode field=theme_mode value=$cached',
            dedupeKey: 'fb|theme|$cached',
          );
        } else {
          themeMode = 'system';
          _profileDiagLog(
            'PROFILE_FALLBACK_USED reason=missing_pb_theme_mode field=theme_mode value=system',
            dedupeKey: 'fb|theme|system',
          );
        }
      }
      final primaryLangRaw = data['primary_language']?.toString().trim() ?? '';
      final primaryLang = primaryLangRaw.isNotEmpty
          ? resolvedUiLanguageCode(primaryLangRaw)
          : 'en';
      if (primaryLangRaw.isEmpty) {
        _profileDiagLog(
          'PROFILE_FALLBACK_USED reason=missing_pb_primary_language field=primary_language value=en',
          dedupeKey: 'fb|lang|en',
        );
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
      final parsedAdmin = _profileBool(data['is_admin']);
      _settings = UserSettings(
        userId: settingsUserId,
        language: primaryLang,
        preferredTimeZone: resolvedTzLabel,
        timezoneOffsetHours: tzOffset,
        activeLanguages: activeLanguages,
        primaryLanguage: primaryLang,
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
      try {
        final prefs = _prefs;
        final uidKey = settingsUserId.trim();
        if (prefs != null && uidKey.isNotEmpty) {
          final showTags = prefs.getBool(_prefsKeyShowListTagsOnCards(uidKey));
          if (showTags != null) {
            _settings = _settings.copyWith(showListTagsOnCards: showTags);
          }
        }
      } catch (_) {}
      await _mirrorProfileSettingsToDeviceCache();
      _profileHydratedLog(
        id: (_profilePbRecordId ?? authId).trim().isEmpty
            ? settingsUserId
            : (_profilePbRecordId ?? authId),
        lang: primaryLang,
        tz: resolvedTzLabel,
        offset: tzOffset,
        isAdmin: parsedAdmin,
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
      _profileDiagLog(
        'PROFILE_FALLBACK_USED reason=profile_load_exception field=settings userId=$uidStr',
        dedupeKey: 'fb|exc|$uidStr',
      );
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
  /// Only fields that changed vs current [_settings] are PATCHed (never `is_admin`).
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
    final prev = _settings;
    final patchFields = _diffProfilePatchFields(prev, coerced);
    _settings = coerced.copyWith(userId: authId);
    _settingsController.add(_settings);
    _syncMaterialAppLocaleFromSettings(_settings);
    _notifyTimelineAfterRecordCacheMutation();

    if (patchFields.isEmpty) return true;

    final fieldNames = patchFields.keys.join(',');
    _profileDiagLog(
      'PROFILE_SAVE_PATCH fields=$fieldNames',
      dedupeKey: 'patch|$fieldNames',
    );

    try {
      await ensurePocketBaseReady();
      final pbId = (_profilePbRecordId ?? _pb.authStore.record?.id)?.trim();
      if (pbId == null || pbId.isEmpty) return false;
      await _pb
          .collection(PbCollections.profiles)
          .update(pbId, body: patchFields);
      final patchedTagWire = patchFields['tag_display_mode']?.toString();
      if (patchedTagWire != null && patchedTagWire.isNotEmpty) {
        _settings = _settings.copyWith(tagDisplayModeWireRaw: patchedTagWire);
        _settingsController.add(_settings);
      }
      _profileDiagLog(
        'PROFILE_SAVE_SUCCESS fields=$fieldNames',
        dedupeKey: 'ok|$fieldNames',
      );
      await _mirrorProfileSettingsToDeviceCache();
      return true;
    } on ClientException catch (e) {
      _profileDiagLog(
        'PROFILE_SAVE_FAIL status=${e.statusCode} error=$e payload=$patchFields',
        dedupeKey: 'fail|${e.statusCode}|$fieldNames',
      );
      DatabaseService._log('SAVE_SETTINGS: PocketBase ${e.statusCode} — $e');
      return false;
    } catch (e, st) {
      _profileDiagLog(
        'PROFILE_SAVE_FAIL status=- error=$e payload=$patchFields',
        dedupeKey: 'fail|err|$fieldNames',
      );
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
      final body = <String, dynamic>{
        'user_id': _pidForPbFilter,
      };
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
