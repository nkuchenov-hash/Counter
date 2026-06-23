// ---------------------------------------------------------------------------
// Per-tag default plan block durations (`tags.default_plan_duration_minutes`).
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class TagDefaultDurationSettingsView extends StatefulWidget {
  const TagDefaultDurationSettingsView({super.key, this.embeddedInHub = false});

  final bool embeddedInHub;

  @override
  State<TagDefaultDurationSettingsView> createState() =>
      _TagDefaultDurationSettingsViewState();
}

class _TagDefaultDurationSettingsViewState
    extends State<TagDefaultDurationSettingsView> {
  List<Tag> _tags = const [];
  bool _loading = true;

  static const List<int> _presets = [10, 15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _load();
    DatabaseService.instance.tagsCatalogUpdated.listen((_) {
      if (mounted) _syncFromCache();
    });
  }

  Future<void> _load() async {
    await DatabaseService.instance.fetchTagsForCurrentUser(
      scope: TagCatalogScope.plan,
    );
    if (!mounted) return;
    _syncFromCache(markLoaded: true);
  }

  void _syncFromCache({bool markLoaded = false}) {
    setState(() {
      _tags = DatabaseService.instance.cachedUserTagsCatalog
          .where(TagCatalogScope.plan.matchesTag)
          .toList();
      if (markLoaded) _loading = false;
    });
  }

  String _durationLabel(int minutes, String loc) {
    return t(loc, 'tag_default_duration_minutes_value')
        .replaceAll('{n}', '$minutes');
  }

  List<Tag> _tagsWithDuration(String pocketRecordId, int? minutes) {
    final rid = pocketRecordId.trim();
    return [
      for (final t in _tags)
        if (t.pbRecordId?.trim() == rid)
          t.copyWith(
            defaultPlanDurationMinutes: minutes,
            clearDefaultPlanDuration: minutes == null,
          )
        else
          t,
    ];
  }

  Future<void> _editDuration(Tag tag) async {
    final loc = currentLocale.value;
    final rid = tag.pbRecordId?.trim() ?? '';
    if (rid.isEmpty) {
      AppSnack.show(t(loc, 'toast_error'), error: true);
      return;
    }
    final current = tag.defaultPlanDurationMinutes;
    // ignore: avoid_print
    print(
      'TAG_DURATION_EDIT_OPEN tagId=${tag.tagId} pbId=$rid current=${current ?? 'null'}',
    );
    final customCtrl = TextEditingController(
      text: current?.toString() ?? '',
    );

    final picked = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t(loc, 'tag_default_duration_edit_title'),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in _presets)
                      AppButton(
                        label: _durationLabel(m, loc),
                        variant: current == m
                            ? AppButtonVariant.primary
                            : AppButtonVariant.outlined,
                        onPressed: () => Navigator.of(ctx).pop(m),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: customCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t(loc, 'tag_default_duration_custom'),
                    suffixText: t(loc, 'tag_default_duration_min_suffix'),
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: t(loc, 'tag_default_duration_apply_custom'),
                  onPressed: () {
                    final n = int.tryParse(customCtrl.text.trim());
                    if (n == null || n < 1) return;
                    Navigator.of(ctx).pop(n.clamp(1, 24 * 60));
                  },
                ),
                if (current != null) ...[
                  const SizedBox(height: 8),
                  AppButton(
                    label: t(loc, 'tag_default_duration_clear'),
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(ctx).pop(-1),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    customCtrl.dispose();
    if (!mounted || picked == null) return;

    final clear = picked < 0;
    final nextMinutes = clear ? null : picked;
    final snapshot = _tags;
    setState(() => _tags = _tagsWithDuration(rid, nextMinutes));

    final err = await DatabaseService.instance
        .patchTagDefaultPlanDurationForCurrentUser(
          pocketRecordId: rid,
          durationMinutes: nextMinutes,
        );
    if (!mounted) return;
    if (err == null) {
      _syncFromCache();
      AppSnack.updated();
    } else {
      setState(() => _tags = snapshot);
      AppSnack.show(t(loc, err), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tags.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t(loc, 'tag_default_durations_empty'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final body = ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _tags.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              t(loc, 'tag_default_durations_subtitle'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        final tag = _tags[index - 1];
        final dur = tag.defaultPlanDurationMinutes;
        final durLabel = dur == null
            ? t(loc, 'tag_default_duration_not_set')
            : _durationLabel(dur, loc);
        return Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: CategoryChip(
              mode: DatabaseService.instance.settings.tagDisplayMode,
              label: tag.name,
              color: parseTagHexColor(tag.color) ?? scheme.primary,
              icon: iconForTagKey(tag.icon),
              compactGlyphLayout: true,
              variant: CategoryChipVariant.compactCard,
            ),
            subtitle: Text(durLabel),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: t(loc, 'tag_default_duration_edit'),
              onPressed: () => unawaited(_editDuration(tag)),
            ),
          ),
        );
      },
    );

    if (widget.embeddedInHub) return body;
    return Scaffold(
      appBar: AppBar(title: Text(t(loc, 'tag_default_durations_title'))),
      body: body,
    );
  }
}
