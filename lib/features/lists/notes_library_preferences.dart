import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single owner for Notes grid/list choice across local Notes controls and
/// the unified Settings menu. The persisted key remains unchanged.
abstract final class NotesLibraryPreferences {
  static const String key = 'lifeos.notes.view';
  static final ValueNotifier<String> mode = ValueNotifier<String>('grid');

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(key);
    mode.value = stored == 'list' ? 'list' : 'grid';
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
