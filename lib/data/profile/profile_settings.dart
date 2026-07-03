part of '../database_service.dart';

extension ProfileSettingsExtension on DatabaseService {
  Map<String, dynamic> _diffProfilePatchFields(
    UserSettings prev,
    UserSettings next,
  ) {
    final fields = <String, dynamic>{};
    final nextLang = resolvedUiLanguageCode(
      next.primaryLanguage.trim().isNotEmpty
          ? next.primaryLanguage
          : next.language,
    );
    final prevLang = resolvedUiLanguageCode(
      prev.primaryLanguage.trim().isNotEmpty
          ? prev.primaryLanguage
          : prev.language,
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
        tagDisplayModeWireForPatch(next) != tagDisplayModeWireForPatch(prev)) {
      fields['tag_display_mode'] = tagDisplayModeWireForPatch(next);
    }
    if (next.listCompletionBehavior != prev.listCompletionBehavior) {
      fields['list_completion_behavior'] = listCompletionBehaviorWireForPatch(
        next,
      );
    }
    return fields;
  }
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
      _profileVerboseDiag('PROFILE_SAVE_SUCCESS fields=$fieldNames');
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
}
