// Client-side category quarantine (SharedPreferences). No PocketBase schema changes.

import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kHiddenCategoryIdsKey = 'hidden_category_ids_json';

/// Local-only hidden category ids; descendants are hidden when an ancestor is hidden.
class CategoryVisibilityPrefs {
  CategoryVisibilityPrefs._();

  static final ValueNotifier<List<int>> hiddenIds = ValueNotifier<List<int>>([]);

  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kHiddenCategoryIdsKey);
    if (s != null && s.isNotEmpty) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is List) {
          hiddenIds.value = decoded
              .map((e) => int.tryParse('$e'))
              .whereType<int>()
              .toList();
        }
      } catch (_) {}
    }
    _loaded = true;
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHiddenCategoryIdsKey, jsonEncode(hiddenIds.value));
  }

  /// True if [categoryId] or any ancestor on the path to root is in the hidden set.
  static bool isHiddenOrAncestor(int categoryId) {
    final h = hiddenIds.value.toSet();
    if (h.isEmpty) return false;
    final path = DatabaseService.instance.categoryPathFromRootToLocalId(categoryId);
    if (path.isEmpty) return false;
    for (final id in path) {
      if (h.contains(id)) return true;
    }
    return false;
  }

  static Future<void> toggle(int categoryId) async {
    await ensureLoaded();
    final next = List<int>.from(hiddenIds.value);
    if (next.contains(categoryId)) {
      next.remove(categoryId);
    } else {
      next.add(categoryId);
    }
    hiddenIds.value = next;
    await _persist();
  }

  /// Filter top-level or sibling lists for pickers / chips (non-edit views).
  static List<T> filterPairs<T>(
    List<T> items,
    int Function(T item) idOf,
  ) {
    return [
      for (final item in items)
        if (!isHiddenOrAncestor(idOf(item))) item
    ];
  }
}
