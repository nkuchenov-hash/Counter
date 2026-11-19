/// Per-device timezone UX preferences. The current profile timezone remains
/// the Brain's single wall-clock authority; device detection is opt-in only.
library;

import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimezoneQuickPreferences {
  const TimezoneQuickPreferences({
    required this.automatic,
    required this.favorites,
  });

  final bool automatic;
  final List<String> favorites;
}

abstract final class TimezoneQuickPreferenceStore {
  static String _key(String profileId, String suffix) =>
      'lifeos.timezone.quick.v1.${profileId.trim()}.$suffix';

  static String _canonicalZone(String value) =>
      catalogEntryForStoredTimezone(value)?.profileValue ?? value.trim();

  // Settings chips can be tapped in rapid succession. Serialize writes so
  // the older selection cannot finish after and overwrite the newer one.
  static Future<void> _favoritesWrite = Future<void>.value();

  static Future<TimezoneQuickPreferences> load(
    String profileId, {
    required String currentTimezone,
  }) async {
    if (profileId.trim().isEmpty) {
      return TimezoneQuickPreferences(
        automatic: false,
        favorites: [_canonicalZone(currentTimezone)],
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key(profileId, 'favorites'));
    return TimezoneQuickPreferences(
      automatic: prefs.getBool(_key(profileId, 'automatic')) ?? false,
      favorites: (stored ?? <String>[currentTimezone])
          .map(_canonicalZone)
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false),
    );
  }

  static Future<void> setAutomatic(String profileId, bool value) async {
    if (profileId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(profileId, 'automatic'), value);
  }

  static Future<void> setFavorites(
    String profileId,
    List<String> timezoneIds,
  ) {
    if (profileId.trim().isEmpty) {
      return Future<void>.error(StateError('Missing profile for time zone favorites'));
    }
    final normalized = timezoneIds.map(_canonicalZone)
        .where((zone) => zone.isNotEmpty).toSet().toList(growable: false);
    final save = _favoritesWrite.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setStringList(_key(profileId, 'favorites'), normalized);
      if (!ok) throw StateError('Could not persist time zone favorites');
    });
    _favoritesWrite = save.catchError((_) {});
    return save;
  }

  /// OS time zone, never the VPN exit address or a geolocation service.
  static Future<String?> deviceTimezone() async {
    try {
      final identifier = (await FlutterTimezone.getLocalTimezone())
          .identifier
          .trim();
      return identifier.isEmpty ? null : identifier;
    } catch (_) {
      return null;
    }
  }

  /// Called after startup's first frame and on resume, never on a hot gesture
  /// or before first-frame rendering. No polling or network IP lookup.
  static Future<bool> reconcileAutomatic({
    required String profileId,
    required String currentTimezone,
    required Future<bool> Function(String timezone) saveTimezone,
  }) async {
    if (profileId.isEmpty) return true;
    final settings = await load(profileId, currentTimezone: currentTimezone);
    if (!settings.automatic) return true;
    final systemZone = await deviceTimezone();
    if (systemZone == null) return false;
    if (systemZone == currentTimezone) return true;
    return saveTimezone(systemZone);
  }
}
