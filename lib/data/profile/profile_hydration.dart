part of '../database_service.dart';

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

extension ProfileHydrationExtension on DatabaseService {
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
    final themeMode =
        (rawTheme == 'light' || rawTheme == 'dark' || rawTheme == 'system')
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
    final accountName = (nameRaw != null && nameRaw.trim().isNotEmpty)
        ? nameRaw.trim()
        : null;
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
        final showTags = prefs.getBool(
          TagDisplaySettingsExtension._prefsKeyShowListTagsOnCards(uidKey),
        );
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
}
