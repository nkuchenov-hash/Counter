// Client-side category quarantine (SharedPreferences). No PocketBase schema changes.

import 'dart:convert';

import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// v1 stored raw local integer category ids globally in the browser/device.
// Those ids can become stale after category-backend migrations and can make an
// unrelated/current catalog appear fully hidden. Do not migrate v1: visibility
// is presentation-only state, so starting clean is safer than hiding real data.
const String _kHiddenCategoryIdsKey = 'hidden_category_ids_json_v2';

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
              .toSet()
              .toList();
        }
      } catch (_) {}
    }

    // Safety invariant: local presentation prefs must never make the entire
    // real category catalog disappear. If every current root is hidden, treat
    // the saved visibility state as stale/corrupt and recover to all-visible.
    final getChildren = CategoryTreeSource.getChildrenOf;
    final pathFromRoot = CategoryTreeSource.pathFromRootToLocalId;
    if (hiddenIds.value.isNotEmpty &&
        getChildren != null &&
        pathFromRoot != null) {
      final roots = getChildren(null);
      if (roots.isNotEmpty && roots.every((r) => isHiddenOrAncestor(r.id))) {
        hiddenIds.value = <int>[];
        try {
          await prefs.remove(_kHiddenCategoryIdsKey);
        } catch (_) {}
      }
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
    final path = CategoryTreeSource.pathFromRoot(categoryId);
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
