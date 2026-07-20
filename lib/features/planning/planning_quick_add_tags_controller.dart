// Quick-add tag strip state: catalog merge, “No Tags” prefs, creation selection, reorder.
import 'dart:async';
import 'dart:convert';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/widgets/planning_list_grouping.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns Planning quick-add tag strip state and local/server order prefs.
///
/// [PlanningPage] keeps text-field submit / smart-plan inject; this controller
/// only owns tag catalog UI state, synthetic “No Tags”, and creation selection.
class PlanningQuickAddTagsController {
  PlanningQuickAddTagsController({
    required this.notifySetState,
    required this.isMounted,
  });

  final void Function([VoidCallback? fn]) notifySetState;
  final bool Function() isMounted;

  /// Persisted order of tag ids in the quick-add strip, including
  /// [kPlanningUntaggedPlanGroupId] for “No Tags”.
  static const String prefsKeyQuickBarTagOrder =
      'planning_quick_bar_tag_ids_v1';

  /// Local-only prefs for the synthetic “No Tags” chip (not PocketBase).
  static const String prefsKeyNoTagsVisible = 'no_tags_visible';
  static const String prefsKeyNoTagsColor = 'no_tags_color';
  static const String defaultNoTagsColorHex = '#9E9E9E';

  /// Tags for quick-add row; reloaded after returning from [TagSettingsHub].
  List<Tag> availableTags = [];
  bool tagsLoading = false;
  bool noTagsChipVisible = true;
  String noTagsColorHex = defaultNoTagsColorHex;

  /// M2M tags selected before submitting the inline task.
  List<Tag> creationSelectedTags = [];

  Tag syntheticNoTagsTag() {
    final loc = currentLocale.value;
    return Tag(
      tagId: kPlanningUntaggedPlanGroupId,
      name: t(loc, 'plan_filter_no_tags'),
      color: noTagsColorHex,
      sortOrder: 0,
      isSynced: true,
    );
  }

  void applyNoTagsChipSettings(bool visible, String colorHex) {
    notifySetState(() {
      noTagsChipVisible = visible;
      noTagsColorHex = colorHex;
    });
  }

  void clearCreationSelectedTags() {
    creationSelectedTags = [];
  }

  List<Tag> mergeQuickBarTagsFromServer(
    List<Tag> serverTags,
    List<int>? savedOrder,
  ) {
    final synthetic = syntheticNoTagsTag();
    if (savedOrder == null || savedOrder.isEmpty) {
      return [...serverTags, synthetic];
    }
    final byId = {for (final t in serverTags) t.tagId: t};
    final out = <Tag>[];
    final usedServer = <int>{};
    var placedSynthetic = false;
    for (final id in savedOrder) {
      if (id == 0) continue;
      if (id == kPlanningUntaggedPlanGroupId) {
        if (!placedSynthetic) {
          out.add(synthetic);
          placedSynthetic = true;
        }
        continue;
      }
      final t = byId[id];
      if (t != null) {
        out.add(t);
        usedServer.add(id);
      }
    }
    for (final t in serverTags) {
      if (!usedServer.contains(t.tagId)) {
        out.add(t);
      }
    }
    if (!placedSynthetic) {
      out.add(synthetic);
    }
    return out;
  }

  Future<void> persistQuickBarTagIdOrderPrefs(List<Tag> ordered) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefsKeyQuickBarTagOrder,
        jsonEncode(ordered.map((t) => t.tagId).toList()),
      );
    } catch (_) {}
  }

  Future<void> reload() async {
    if (!isMounted()) return;
    notifySetState(() => tagsLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final visible = prefs.getBool(prefsKeyNoTagsVisible) ?? true;
    final cr = prefs.getString(prefsKeyNoTagsColor)?.trim();
    final colorHex =
        (cr != null &&
            cr.startsWith('#') &&
            cr.length >= 7 &&
            parseTagHexColor(cr) != null)
        ? cr
        : defaultNoTagsColorHex;

    final list = await DatabaseService.instance.fetchTagsForCurrentUser(
      scope: TagCatalogScope.plan,
    );
    List<int>? order;
    try {
      final raw = prefs.getString(prefsKeyQuickBarTagOrder);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          order = decoded
              .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
              .where((id) => id != 0)
              .toList();
        }
      }
    } catch (_) {}
    if (!isMounted()) return;
    noTagsChipVisible = visible;
    noTagsColorHex = colorHex;
    var merged = mergeQuickBarTagsFromServer(list, order);
    if (!visible) {
      merged = merged
          .where((t) => t.tagId != kPlanningUntaggedPlanGroupId)
          .toList();
    }
    notifySetState(() {
      availableTags = merged;
      tagsLoading = false;
    });
  }

  Future<void> openTagManager(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (ctx) => const TagSettingsHub()),
    );
    await reload();
  }

  void toggleCreationTag(Tag tag) {
    if (tag.tagId == kPlanningUntaggedPlanGroupId) return;
    notifySetState(() {
      final next = List<Tag>.from(creationSelectedTags);
      final i = next.indexWhere((x) => x.tagId == tag.tagId);
      if (i >= 0) {
        next.removeAt(i);
      } else {
        next.add(tag);
      }
      creationSelectedTags = next;
    });
  }

  void onQuickBarReorder(int oldIndex, int newIndex) {
    if (availableTags.length < 2) return;
    if (oldIndex < 0 || oldIndex >= availableTags.length) return;
    if (newIndex < 0 || newIndex > availableTags.length) return;
    var ni = newIndex;
    if (oldIndex < ni) ni -= 1;
    if (ni < 0 || ni >= availableTags.length) return;

    final previous = List<Tag>.from(availableTags);
    final row = previous[oldIndex];
    final next = List<Tag>.from(previous);
    next.removeAt(oldIndex);
    next.insert(ni, row);
    final withSort = <Tag>[
      for (var i = 0; i < next.length; i++) next[i].copyWith(sortOrder: i),
    ];
    notifySetState(() => availableTags = withSort);
    unawaited(persistQuickBarTagIdOrderPrefs(withSort));
    unawaited(_persistPlanningQuickBarSortOrder(previous, withSort));
  }

  Future<void> _persistPlanningQuickBarSortOrder(
    List<Tag> previousUiOrder,
    List<Tag> ordered,
  ) async {
    final persistable = ordered
        .where((t) => t.tagId != kPlanningUntaggedPlanGroupId)
        .toList();
    final withSort = <Tag>[
      for (var i = 0; i < persistable.length; i++)
        persistable[i].copyWith(sortOrder: i),
    ];
    final ok = await DatabaseService.instance
        .persistTagsSortOrderForCurrentUser(withSort);
    if (!isMounted()) return;
    if (ok) {
      await persistQuickBarTagIdOrderPrefs(ordered);
      DatabaseService.instance.notifyPlanningRefresh();
      return;
    }
    notifySetState(() => availableTags = List<Tag>.from(previousUiOrder));
    AppSnack.failed();
  }
}
