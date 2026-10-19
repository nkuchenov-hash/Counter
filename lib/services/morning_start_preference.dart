import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local, profile-scoped visibility setting for the morning check-in.
/// Independent from sleep imports and the check-in's per-day completion flags.
class MorningStartPreference {
  MorningStartPreference._();

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static String _keyFor(String? profileId) {
    final id = profileId?.trim();
    final scope = id == null || id.isEmpty ? 'local' : id;
    return 'lifeos.morning_start.$scope.enabled';
  }

  /// Existing users retain the current automatic prompt until they turn it off.
  static Future<bool> isEnabled(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFor(profileId)) ?? true;
  }

  static Future<void> setEnabled(String? profileId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(profileId);
    if (prefs.getBool(key) == enabled) return;
    final saved = await prefs.setBool(key, enabled);
    if (!saved) throw StateError('Could not save morning prompt preference');
    changes.value++;
  }
}
