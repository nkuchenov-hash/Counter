// ---------------------------------------------------------------------------
// TAG / CATEGORY DISPLAY — global chip style (profiles.tag_display_mode).
// UI_ISOLATION: strings via t(); persistence via DatabaseService.saveSettings.
// ---------------------------------------------------------------------------

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/chip_component.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// PocketBase field `tag_display_mode` — live preview + radio selector.
class TagSettingsView extends StatefulWidget {
  const TagSettingsView({super.key});

  @override
  State<TagSettingsView> createState() => _TagSettingsViewState();
}

class _TagSettingsViewState extends State<TagSettingsView> {
  bool _saving = false;

  static const Color _previewColor = Color(0xFF00897B);
  static const IconData _previewIcon = Icons.star_rounded;

  String _modeLabel(String loc, CategoryDisplayMode m) {
    switch (m) {
      case CategoryDisplayMode.letterChip:
        return t(loc, 'tag_display_mode_letter_chip');
      case CategoryDisplayMode.chip:
        return t(loc, 'tag_display_mode_chip');
      case CategoryDisplayMode.round:
        return t(loc, 'tag_display_mode_round');
      case CategoryDisplayMode.icon:
        return t(loc, 'tag_display_mode_icon');
      case CategoryDisplayMode.iconCircle:
        return t(loc, 'tag_display_mode_icon_circle');
    }
  }

  Future<void> _setMode(CategoryDisplayMode m) async {
    if (_saving) return;
    final cur = DatabaseService.instance.settings.tagDisplayMode;
    if (cur == m) return;
    setState(() => _saving = true);
    try {
      final ok = await DatabaseService.instance.saveSettings(
        DatabaseService.instance.settings.copyWith(tagDisplayMode: m),
      );
      if (!mounted) return;
      if (ok) {
        AppSnack.saved();
      } else {
        AppSnack.failed();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final mockName = t(loc, 'tag_display_preview_mock_name');

    return Scaffold(
      appBar: AppBar(title: Text(t(loc, 'tag_display_settings_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t(loc, 'tag_display_settings_subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t(loc, 'tag_display_preview_heading'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in CategoryDisplayMode.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: CategoryChip(
                            mode: m,
                            label: mockName,
                            color: _previewColor,
                            icon: _previewIcon,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 92,
                          child: Text(
                            _modeLabel(loc, m),
                            style: theme.textTheme.labelSmall,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            t(loc, 'tag_display_your_style'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          StreamBuilder<UserSettings>(
            stream: DatabaseService.instance.userSettingsStream,
            initialData: DatabaseService.instance.settings,
            builder: (context, snap) {
              final active =
                  snap.data?.tagDisplayMode ?? CategoryDisplayMode.letterChip;
              return Column(
                children: [
                  for (final m in CategoryDisplayMode.values)
                    RadioListTile<CategoryDisplayMode>(
                      contentPadding: EdgeInsets.zero,
                      value: m,
                      groupValue: active,
                      onChanged: _saving
                          ? null
                          : (CategoryDisplayMode? v) {
                              if (v != null) {
                                _setMode(v);
                              }
                            },
                      title: Text(_modeLabel(loc, m)),
                    ),
                ],
              );
            },
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
