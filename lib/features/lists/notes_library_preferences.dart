import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single owner for Notes grid/list choice across local Notes controls and
/// the unified Settings menu. The persisted key remains unchanged.
abstract final class NotesLibraryPreferences {
  static const String key = 'lifeos.notes.view';
  static const String checkboxModeKey = 'lifeos.notes.checkboxMode';
  static final ValueNotifier<bool> checkboxMode = ValueNotifier<bool>(false);
  static final ValueNotifier<String> mode = ValueNotifier<String>('grid');
  static final ValueNotifier<int> categoryBarRequests = ValueNotifier<int>(0);
  static void requestCategoryBarEditor() => categoryBarRequests.value++;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(key);
    mode.value = stored == 'list' ? 'list' : 'grid';
    checkboxMode.value = prefs.getBool(checkboxModeKey) ?? false;
  }

  static Future<void> setCheckboxMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(await prefs.setBool(checkboxModeKey, enabled))) {
      throw StateError('Could not persist checkbox mode');
    }
    checkboxMode.value = enabled;
  }

  static Future<void> select(String next) async {
    final normalized = next == 'list' ? 'list' : 'grid';
    final prefs = await SharedPreferences.getInstance();
    if (!(await prefs.setString(key, normalized))) {
      throw StateError('Could not persist Notes layout');
    }
    mode.value = normalized;
  }
}
