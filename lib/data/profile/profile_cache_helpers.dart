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
    if (kIsWeb) {
      final durable = await WebRecordJournal.readPreferenceBool(deviceKey);
      if (durable != null) return durable;

      // Migration is best-effort: exhausted/corrupted SharedPreferences must
      // never disable the UI or prevent a new IndexedDB preference from saving.
      final legacy = await _readLegacyValue(profileId);
      if (legacy != null) {
        await WebRecordJournal.writePreferenceBool(deviceKey, legacy);
        return legacy;
      }
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(deviceKey);
    if (stored != null) return stored;
    final legacy = await _readLegacyValue(profileId);
    if (legacy != null) {
      if (!await prefs.setBool(deviceKey, legacy)) {
        throw StateError('Could not migrate morning prompt preference');
      }
      return legacy;
    }
    return true;
  }

  static Future<bool?> _readLegacyValue(String? profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Existing v2 value may be present from earlier builds. Never overwrite
      // an explicit disabled setting with a default true.
      final v2 = prefs.get(deviceKey);
      if (v2 is bool) return v2;
      final legacy = <bool>[];
      for (final key in prefs.getKeys()) {
        if (key.startsWith('lifeos.morning_start.') &&
            key.endsWith('.enabled')) {
          final value = prefs.get(key);
          if (value is bool) legacy.add(value);
        }
      }
      if (legacy.contains(false)) return false;
      if (legacy.isNotEmpty) return true;
      final scoped = prefs.get(_legacyKeyFor(profileId));
      if (scoped is bool) return scoped;
    } catch (_) {
      // It is unsafe to depend on localStorage during a browser storage error.
      // The IndexedDB preference remains fully usable without legacy migration.
    }
    return null;
  }

  static Future<void> setEnabled(String? profileId, bool enabled) async {
    if (kIsWeb) {
      // Browser storage can fill localStorage with larger cached app data.
      // Save this small setting in the app's existing IndexedDB journal.
      await WebRecordJournal.writePreferenceBool(deviceKey, enabled);
      if (await WebRecordJournal.readPreferenceBool(deviceKey) != enabled) {
        throw StateError('Browser morning prompt preference verification failed');
      }
      changes.value++;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(deviceKey, enabled)) {
      throw StateError('Could not persist morning check-in setting');
    }
    if (prefs.getBool(deviceKey) != enabled) {
      throw StateError('Morning check-in preference readback failed');
    }
    changes.value++;
  }
}
