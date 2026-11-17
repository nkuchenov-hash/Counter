/// Per-device timezone UX preferences. The current profile timezone remains
/// the Brain's single wall-clock authority; device detection is opt-in only.
library;

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

  static Future<TimezoneQuickPreferences> load(
    String profileId, {
    required String currentTimezone,
  }) async {
    if (profileId.trim().isEmpty) {
      return TimezoneQuickPreferences(
        automatic: false,
        favorites: [currentTimezone],
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key(profileId, 'favorites'));
    return TimezoneQuickPreferences(
      automatic: prefs.getBool(_key(profileId, 'automatic')) ?? false,
      favorites: (stored ?? <String>[currentTimezone])
          .where((item) => item.trim().isNotEmpty)
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
  ) async {
    if (profileId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(profileId, 'favorites'),
      timezoneIds.toSet().toList(growable: false),
    );
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
