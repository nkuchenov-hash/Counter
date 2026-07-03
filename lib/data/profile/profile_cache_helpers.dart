part of '../database_service.dart';

extension ProfileCacheExtension on DatabaseService {
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
        final showTags = prefs.getBool(
          TagDisplaySettingsExtension._prefsKeyShowListTagsOnCards(uid),
        );
        if (showTags != null) {
          _settings = _settings.copyWith(showListTagsOnCards: showTags);
        }
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }
}
