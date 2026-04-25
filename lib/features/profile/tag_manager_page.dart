// ---------------------------------------------------------------------------
// TAG MANAGER — CRUD for @DATA_MAP `tags` (user_id, tag_id, name, color, icon, sort_order).
// UI_ISOLATION: strings via t(); HTTP only via DatabaseService.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/tag_contrast.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:counter/core/widgets/app_loading.dart';

/// Preset hex colors for @DATA_MAP `tags.color` (stored as "#RRGGBB").
const List<String> kTagManagerPalette = [
  '#E53935',
  '#FB8C00',
  '#FDD835',
  '#43A047',
  '#1E88E5',
  '#8E24AA',
  '#9E9E9E',
  '#000000',
  '#6D4C41',
  '#EC407A',
];

/// Ten Material icon keys (`tags.icon`).
const List<String> kTagManagerIconKeys = [
  'label',
  'star',
  'bookmark',
  'flag',
  'home',
  'work',
  'favorite',
  'event',
  'local_offer',
  'sell',
];

IconData iconForTagKey(String? key) {
  switch (key) {
    case 'star':
      return Icons.star_rounded;
    case 'bookmark':
      return Icons.bookmark_rounded;
    case 'flag':
      return Icons.flag_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'work':
      return Icons.work_rounded;
    case 'favorite':
      return Icons.favorite_rounded;
    case 'event':
      return Icons.event_rounded;
    case 'local_offer':
      return Icons.local_offer_rounded;
    case 'sell':
      return Icons.sell_rounded;
    case 'label':
    default:
      return Icons.label_rounded;
  }
}

Color? parseTagHexColor(String? hex) {
  if (hex == null || hex.length < 7) return null;
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}

class TagManagerPage extends StatefulWidget {
  const TagManagerPage({
    super.key,
    this.embeddedInHub = false,
    this.pocketTagDomain = 'plan',
  });

  /// When true, no [AppBar] — shown as a tab in the unified tag settings screen.
  final bool embeddedInHub;

  /// PocketBase `tags.domain` for list vs plan ecosystem (`plan` | `list`).
  final String pocketTagDomain;

  @override
  State<TagManagerPage> createState() => _TagManagerPageState();
}

class _TagManagerPageState extends State<TagManagerPage> {
  List<Tag> _tags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  TagCatalogScope get _tagScope =>
      widget.pocketTagDomain.trim().toLowerCase() == 'list'
          ? TagCatalogScope.list
          : TagCatalogScope.plan;

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list =
        await DatabaseService.instance.fetchTagsForCurrentUser(scope: _tagScope);
    if (!mounted) return;
    setState(() {
      _tags = list;
      _loading = false;
    });
  }

  String _initialColorHex(Tag? existing) {
    final c = existing?.color?.trim();
    if (c != null && c.length >= 7 && c.startsWith('#')) return c;
    return kTagManagerPalette.first;
  }

  String _initialIconKey(Tag? existing) {
    final ik = existing?.icon?.trim();
    if (ik != null && kTagManagerIconKeys.contains(ik)) return ik;
    return kTagManagerIconKeys.first;
  }

  /// [existing] null = create; non-null = edit (PATCH via [DatabaseService.patchTagForCurrentUser]).
  Future<void> _presentTagEditor({Tag? existing}) async {
    final loc = currentLocale.value;
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    var pickedColor = _initialColorHex(existing);
    var pickedIcon = _initialIconKey(existing);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              title: Text(t(
                loc,
                existing == null
                    ? 'tag_create_dialog_title'
                    : 'tag_edit_dialog_title',
              )),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: t(loc, 'tag_name_label'),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    Text(t(loc, 'tag_pick_color'),
                        style: Theme.of(ctx).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in kTagManagerPalette)
                          InkWell(
                            onTap: () => setD(() => pickedColor = c),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: parseTagHexColor(c),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: pickedColor == c
                                      ? Theme.of(ctx).colorScheme.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(t(loc, 'tag_pick_icon'),
                        style: Theme.of(ctx).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final ik in kTagManagerIconKeys)
                          IconButton.filledTonal(
                            onPressed: () => setD(() => pickedIcon = ik),
                            style: IconButton.styleFrom(
                              backgroundColor: pickedIcon == ik
                                  ? Theme.of(ctx).colorScheme.primaryContainer
                                  : null,
                            ),
                            icon: Icon(iconForTagKey(ik)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(t(loc, 'cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(t(loc, existing == null ? 'add' : 'save')),
                ),
              ],
            );
          },
        );
      },
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (ok != true || !mounted) return;
    if (name.isEmpty) return;

    if (existing == null) {
      final created = await DatabaseService.instance.createTagForCurrentUser(
        name: name,
        colorHex: pickedColor,
        iconKey: pickedIcon,
        domain: widget.pocketTagDomain.trim().toLowerCase() == 'list'
            ? 'list'
            : 'plan',
      );
      if (!mounted) return;
      if (created == null) {
        AppSnack.failed();
        return;
      }
      AppSnack.saved();
      await _reload();
      return;
    }

    final pbr = existing.pbRecordId?.trim() ?? '';
    if (pbr.isEmpty) {
      AppSnack.failed();
      return;
    }
    final patchOk = await DatabaseService.instance.patchTagForCurrentUser(
      pocketRecordId: pbr,
      name: name,
      colorHex: pickedColor,
      iconKey: pickedIcon,
    );
    if (!mounted) return;
    if (!patchOk) {
      AppSnack.failed();
      return;
    }
    AppSnack.saved();
    await _reload();
  }

  Future<void> _confirmDelete(Tag tag) async {
    final pbr = tag.pbRecordId?.trim() ?? '';
    if (pbr.isEmpty) {
      AppSnack.failed();
      return;
    }
    final loc = currentLocale.value;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(loc, 'tag_delete_title')),
       content: Text(
          t(loc, 'tag_delete_body').replaceFirst('%s', tag.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(loc, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t(loc, 'delete')),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final delOk = await DatabaseService.instance.deleteTagByPocketRecordId(pbr);
    if (!mounted) return;
    if (delOk) {
      AppSnack.deleted();
      await _reload();
    } else {
      AppSnack.failed();
    }
  }

  /// Indices match [_tags] only — the reorder hint lives above [ReorderableListView], not in it.
  void _onReorder(int oldIndex, int newIndex) {
    if (_tags.length < 2) return;
    if (oldIndex < 0 || oldIndex >= _tags.length) return;
    if (newIndex < 0 || newIndex > _tags.length) return;
    var ni = newIndex;
    if (oldIndex < ni) ni -= 1;
    if (ni < 0 || ni >= _tags.length) return;

    final previous = List<Tag>.from(_tags);
    final row = previous[oldIndex];
    final reordered = List<Tag>.from(previous);
    reordered.removeAt(oldIndex);
    reordered.insert(ni, row);
    final withSortOrder = <Tag>[
      for (var i = 0; i < reordered.length; i++)
        reordered[i].copyWith(sortOrder: i),
    ];
    setState(() => _tags = withSortOrder);
    unawaited(_persistReorderedTags(previous, withSortOrder));
  }

  Future<void> _persistReorderedTags(
    List<Tag> previousUiOrder,
    List<Tag> ordered,
  ) async {
    final ok = await DatabaseService.instance
        .persistTagsSortOrderForCurrentUser(ordered);
    if (!mounted) return;
    if (ok) return;
    setState(() => _tags = List<Tag>.from(previousUiOrder));
    AppSnack.failed();
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.embeddedInHub
          ? null
          : AppBar(
              title: Text(t(loc, 'tag_manager_title')),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _presentTagEditor(existing: null),
        icon: const Icon(Icons.add_rounded),
        label: Text(t(loc, 'tag_create')),
      ),
      body: _loading
          ? const AppLoading()
          : _tags.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      t(loc, 'tag_manager_empty'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        t(loc, 'tag_manager_reorder_hint'),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        buildDefaultDragHandles: false,
                        itemCount: _tags.length,
                        onReorder: _onReorder,
                        itemBuilder: (ctx, i) {
                          final tag = _tags[i];
                          final c =
                              parseTagHexColor(tag.color) ?? scheme.primary;
                          final avatarPlate =
                              tagManagerAvatarPlate(c, scheme.surface);
                          final avatarFg = tagVibrantForeground(c);
                          return ReorderableDragStartListener(
                            key: ValueKey<Object>(
                              tag.pbRecordId ?? 'tag-${tag.tagId}',
                            ),
                            index: i,
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: avatarPlate,
                                  foregroundColor: avatarFg,
                                  child: Icon(
                                      iconForTagKey(tag.icon), size: 22),
                                ),
                                title: Text(tag.name),
                                subtitle: Text('#${tag.tagId}'),
                                onTap: () => _presentTagEditor(existing: tag),
                                trailing: IconButton(
                                  tooltip: t(loc, 'delete'),
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: scheme.error),
                                  onPressed: () => _confirmDelete(tag),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
