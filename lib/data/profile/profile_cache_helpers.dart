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

/// Persistent device-local visibility for the automatic morning check-in.
///
/// Use a single stable browser/device key. The original implementation scoped
/// it by a profile id captured when Settings first built; that id may be absent
/// or change during login hydration and cause an apparently forgotten toggle.
/// This preference only affects the local prompt, not recorded sleep data.
class MorningStartPreference {
  MorningStartPreference._();

  static const String deviceKey = 'lifeos.morning_start.enabled.v2';
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static String _legacyKeyFor(String? profileId) {
    final id = profileId?.trim();
    final scope = id == null || id.isEmpty ? 'local' : id;
    return 'lifeos.morning_start.$scope.enabled';
  }

  static Future<bool> isEnabled(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    // Reading from backing storage avoids a stale in-memory snapshot when
    // profile hydration or another view touched preferences since app start.
    await prefs.reload();
    final stored = prefs.getBool(deviceKey);
    if (stored != null) return stored;

    // Upgrade settings from builds which stored them under the transient
    // profile ID. Migrate a disabled value first rather than accidentally
    // turning a previously disabled prompt back on.
    final scoped = prefs.getBool(_legacyKeyFor(profileId));
    final local = prefs.getBool(_legacyKeyFor(null));
    final enabled = scoped == false || local == false
        ? false
        : (scoped ?? local ?? true);
    if (scoped != null || local != null) {
      final saved = await prefs.setBool(deviceKey, enabled);
      if (!saved) {
        throw StateError('Could not migrate morning check-in setting');
      }
    }
    return enabled;
  }

  static Future<void> setEnabled(String? profileId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool(deviceKey, enabled);
    if (!saved) {
      throw StateError('Could not persist morning check-in setting');
    }
    // Do not claim the change was saved without confirming the backing store.
    await prefs.reload();
    if (prefs.getBool(deviceKey) != enabled) {
      throw StateError('Morning check-in setting failed readback');
    }
    changes.value++;
  }
}
