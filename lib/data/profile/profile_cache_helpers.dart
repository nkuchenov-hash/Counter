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
    // SharedPreferences.getInstance() provides the persisted cache for this
    // browser session. Do not force reload() on every preference read:
    // web implementations may invalidate/recreate the snapshot mid-toggle.
    final stored = prefs.getBool(deviceKey);
    if (stored != null) return stored;

    // Upgrade settings from builds which stored them under the transient
    // profile ID. Migrate a disabled value first rather than accidentally
    // turning a previously disabled prompt back on.
    final scoped = prefs.getBool(_legacyKeyFor(profileId));
    final local = prefs.getBool(_legacyKeyFor(null));
    final legacyValues = [
      for (final key in prefs.getKeys())
        if (key.startsWith('lifeos.morning_start.') &&
            key.endsWith('.enabled') &&
            prefs.get(key) is bool)
          prefs.get(key) as bool,
    ];
    final enabled = legacyValues.contains(false)
        ? false
        : (scoped ?? local ?? true);
    if (legacyValues.isNotEmpty) {
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
    // setBool already awaits the platform persistence operation. A second
    // reload here could fail on web after a successful save and incorrectly
    // roll back the switch. Use the same cache that setBool just updated.
    if (prefs.getBool(deviceKey) != enabled) {
      throw StateError('Morning check-in setting failed cache readback');
    }
    changes.value++;
  }
}
