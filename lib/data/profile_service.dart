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

bool _profileHydratedFromPb = false;
String? _profileHydrationError;

String _maskEmailForLog(String? raw) {
  final e = raw?.trim() ?? '';
  if (e.isEmpty) return '-';
  final at = e.indexOf('@');
  if (at <= 0) return '***';
  final local = e.substring(0, at);
  final domain = e.substring(at);
  if (local.length <= 1) return '*$domain';
  return '${local[0]}***$domain';
}

String? _authRecordEmail() {
  try {
    final pb = DatabaseService.instance.pocketBase;
    final e = pb.authStore.record?.data['email']?.toString().trim();
    return (e != null && e.isNotEmpty) ? e : null;
  } catch (_) {
    return null;
  }
}

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
const String _profilePrimaryLangKey = 'profile_primary_language';

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

void _profileVerboseDiag(String line) {
  if (!kDebugMode) return;
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
  _profileVerboseDiag(
    'PROFILE_HYDRATED id=$id source=pb lang=$lang tz=$tz offset=$offset isAdmin=$isAdmin',
  );
  _profileVerboseDiag('PROFILE_ADMIN_STATE isAdmin=$isAdmin source=pb');
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
  bool get profileHydratedFromPb => _profileHydratedFromPb;
  String? get profileHydrationError => _profileHydrationError;

  static String resolveProfileDisplayLabelFor({UserSettings? settings}) {
    final s = settings ?? _settings;
    final dn = s.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final name = s.accountName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email =
        s.profileEmail?.trim() ?? _authRecordEmail() ?? '';
    if (email.isNotEmpty) {
      if (email.contains('@')) {
        final local = email.split('@').first.trim();
        if (local.isNotEmpty) return local;
      }
      return email;
    }
    return '';
  }

  String get resolvedProfileDisplayLabel =>
      ProfileServiceExtension.resolveProfileDisplayLabelFor();

  /// Retry PocketBase profile hydration without wiping the auth session.
  Future<bool> retryProfileHydration() async {
    if (!_pb.authStore.isValid) {
      _profileHydrationError = 'Not signed in';
      return false;
    }
    try {
      await _loadSettingsFromNoco();
      _profileHydratedFromPb = true;
      _profileHydrationError = null;
      return true;
    } on _ProfileFetchFailedException catch (e) {
      _profileHydratedFromPb = false;
      _profileHydrationError =
          e.message ?? 'Could not load your profile settings.';
      return false;
    } catch (e) {
      _profileHydratedFromPb = false;
      _profileHydrationError = 'Could not load your profile settings. ($e)';
      return false;
    }
  }

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

  /// Fetches profile row via `profiles.getOne(authStore.record.id)` only.
  Future<Map<String, dynamic>?> getUserProfile(String id) async {
    await ensurePocketBaseReady();
    final authValid = _pb.authStore.isValid;
    final auth = _pb.authStore.record;
    final authId = auth?.id.trim() ?? '';
    final authEmail = _maskEmailForLog(
      auth?.data['email']?.toString() ?? _authRecordEmail(),
    );
    _profileDiagLog(
      'PROFILE_BOOT_START authValid=$authValid authId=${authId.isEmpty ? '-' : authId} authEmail=$authEmail',
      dedupeKey: 'boot|$authValid|$authId',
    );
    if (!authValid || authId.isEmpty) {
      _profileDiagLog(
        'PROFILE_FETCH_FAIL reason=auth_invalid_or_missing_id',
        dedupeKey: 'fail|auth',
      );
      return null;
    }
    _profileDiagLog(
      'PROFILE_FETCH_REQUEST collection=${PbCollections.profiles} id=$authId',
      dedupeKey: 'fetch|$authId',
    );
    try {
      final rec = await _pb.collection(PbCollections.profiles).getOne(authId);
      final data = Map<String, dynamic>.from(rec.data)..['id'] = rec.id;
      _profilePbRecordId = rec.id;
      final lang = (data['primary_language'] ?? '-').toString();
      final tz = (data['preferred_timezone'] ?? '-').toString();
      final off = data['timezone_offset'];
      final admin = _profileBool(data['is_admin']);
      final dn = (data['display_name'] ?? '-').toString();
      final name = (data['name'] ?? '-').toString();
      final email = _maskEmailForLog(data['email']?.toString());
      _profileDiagLog(
        'PROFILE_FETCH_SUCCESS id=$authId email=$email name=$name display_name=$dn lang=$lang tz=$tz offset=$off is_admin=$admin',
        dedupeKey: 'ok|$authId|$lang|$tz|$admin',
      );
      return data;
    } on ClientException catch (e) {
      _profileDiagLog(
        'PROFILE_FETCH_FAIL status=${e.statusCode} error=$e response=${e.response}',
        dedupeKey: 'fail|$authId|${e.statusCode}',
      );
      throw _ProfileFetchFailedException(
        e.statusCode,
        'Could not load your profile settings.',
      );
    } catch (e) {
      _profileDiagLog(
        'PROFILE_FETCH_FAIL status=- error=$e response=-',
        dedupeKey: 'fail|$authId|err',
      );
      throw _ProfileFetchFailedException(
        0,
        'Could not load your profile settings.',
      );
    }
  }

  Future<Map<String, dynamic>> getCurrentUserProfileMap() async {
    final m = await getUserProfile('');
    if (m == null || m.isEmpty) {
      throw _ProfileFetchFailedException(
        404,
        'Could not load your profile settings.',
      );
    }
    return m;
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

  /// Mirror PB-hydrated settings into device prefs (boot cache for tz/lang/theme).
  Future<void> _mirrorProfileSettingsToDeviceCache() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_profileThemeModeKey, _settings.themeMode);
      await prefs.setString(_profileTzLabelKey, _settings.preferredTimeZone);
      await prefs.setInt(_profileTzOffsetKey, _settings.timezoneOffsetHours);
      final lang = _settings.primaryLanguage.trim().isNotEmpty
          ? _settings.primaryLanguage
          : _settings.language;
      if (lang.trim().isNotEmpty) {
        await prefs.setString(_profilePrimaryLangKey, lang);
      }
    } catch (_) {}
  }

  Future<bool> _hydrateSettingsFromDeviceCacheIfAvailable() async {
    final uid = (_userIdForWhere ?? currentProfileId ?? '').trim();
    if (uid.isEmpty) return false;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final tzLabel = prefs.getString(_profileTzLabelKey);
      final tzOffset = prefs.getInt(_profileTzOffsetKey);
      if (tzLabel == null || tzOffset == null) return false;
      final resolvedTz = tzLabel.trim().isEmpty ? 'UTC' : tzLabel.trim();
      final theme = prefs.getString(_profileThemeModeKey) ?? 'system';
      final langRaw = prefs.getString(_profilePrimaryLangKey);
      final lang = (langRaw != null && langRaw.trim().isNotEmpty)
          ? resolvedUiLanguageCode(langRaw)
          : 'en';
      _settings = UserSettings(
        userId: uid,
        language: lang,
        primaryLanguage: lang,
        preferredTimeZone: resolvedTz,
        timezoneOffsetHours: tzOffset,
        themeMode: theme,
      );
      try {
        final showTags = prefs.getBool(_prefsKeyShowListTagsOnCards(uid));
        if (showTags != null) {
          _settings = _settings.copyWith(showListTagsOnCards: showTags);
        }
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _profileSettingsVisiblyChanged(UserSettings a, UserSettings b) {
    return a.primaryLanguage != b.primaryLanguage ||
        a.preferredTimeZone != b.preferredTimeZone ||
        a.timezoneOffsetHours != b.timezoneOffsetHours ||
        a.themeMode != b.themeMode ||
        a.displayName != b.displayName ||
        a.isAdmin != b.isAdmin;
  }

  void _applyProfileFromPbMap(Map<String, dynamic> data) {
    if (data.isEmpty) {
      throw _ProfileFetchFailedException(
        404,
        'Could not load your profile settings.',
      );
    }
    final rowUid = data['user_id']?.toString().trim() ?? '';
    if (rowUid.isEmpty) {
      throw _ProfileFetchFailedException(
        422,
        'Profile row missing user_id',
      );
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
    final themeMode = (rawTheme == 'light' ||
            rawTheme == 'dark' ||
            rawTheme == 'system')
        ? rawTheme!
        : 'system';
    final primaryLangRaw = data['primary_language']?.toString().trim() ?? '';
    final primaryLang = primaryLangRaw.isNotEmpty
        ? resolvedUiLanguageCode(primaryLangRaw)
        : 'en';
    final dnRaw = data['display_name'] as String?;
    final nameRaw = data['name'] as String?;
    final emailRaw = data['email']?.toString().trim();
    final displayResolved = (dnRaw != null && dnRaw.trim().isNotEmpty)
        ? dnRaw.trim()
        : ((nameRaw != null && nameRaw.trim().isNotEmpty)
              ? nameRaw.trim()
              : null);
    final accountName =
        (nameRaw != null && nameRaw.trim().isNotEmpty) ? nameRaw.trim() : null;
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
      displayName: displayResolved,
      accountName: accountName,
      profileEmail: (emailRaw != null && emailRaw.isNotEmpty) ? emailRaw : null,
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
    _profileHydratedFromPb = true;
    _profileHydrationError = null;
    _profileHydratedLog(
      id: (_profilePbRecordId ?? authUid).trim().isEmpty
          ? settingsUserId
          : (_profilePbRecordId ?? authUid),
      lang: primaryLang,
      tz: resolvedTzLabel,
      offset: tzOffset,
      isAdmin: parsedAdmin,
    );
    final uiLabel = ProfileServiceExtension.resolveProfileDisplayLabelFor(
      settings: _settings,
    );
    _profileVerboseDiag(
      'PROFILE_UI_SETTINGS_APPLIED displayName=$uiLabel lang=$primaryLang tz=$resolvedTzLabel isAdmin=$parsedAdmin',
    );
    _settingsController.add(_settings);
    _syncMaterialAppLocaleFromSettings(_settings);
  }

  Future<void> _fetchAndApplyProfileFromServer({
    required bool afterCacheBoot,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final data = await getCurrentUserProfileMap();
      _applyProfileFromPbMap(data);
      await _mirrorProfileSettingsToDeviceCache();
      sw.stop();
    } catch (e) {
      sw.stop();
      if (afterCacheBoot) {
        DatabaseService._log(
          'Profile server refresh after cache boot failed: $e',
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> _loadSettingsFromNoco() async {
    final hadCache = await _hydrateSettingsFromDeviceCacheIfAvailable();
    if (hadCache) {
      _profileHydratedFromPb = true;
      _profileHydrationError = null;
      _settingsController.add(_settings);
      _syncMaterialAppLocaleFromSettings(_settings);
      unawaited(_fetchAndApplyProfileFromServer(afterCacheBoot: true));
      return;
    }
    await _fetchAndApplyProfileFromServer(afterCacheBoot: false);
    await _mirrorProfileSettingsToDeviceCache();
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
    _profileVerboseDiag(
      'PROFILE_SAVE_PATCH fields=$fieldNames payload=$patchFields',
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
      _profileVerboseDiag(
        'PROFILE_SAVE_SUCCESS fields=$fieldNames',
      );
      await _mirrorProfileSettingsToDeviceCache();
      return true;
    } on ClientException catch (e) {
      _profileVerboseDiag(
        'PROFILE_SAVE_FAIL status=${e.statusCode} error=$e payload=$patchFields',
      );
      DatabaseService._log('SAVE_SETTINGS: PocketBase ${e.statusCode} — $e');
      return false;
    } catch (e, st) {
      _profileVerboseDiag(
        'PROFILE_SAVE_FAIL status=- error=$e payload=$patchFields',
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
