import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/shared/time/profile_timezone_actions.dart';
import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'package:counter/core/widgets/app_timezone_icon.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Header timezone label — tap opens quick picker (profile timezone only).
class HeaderTimezoneQuickSwitcher extends StatelessWidget {
  const HeaderTimezoneQuickSwitcher({
    super.key,
    required this.textStyle,
    this.enabled = true,
  });

  final TextStyle textStyle;
  final bool enabled;

  Future<void> _openPicker(BuildContext context) async {
    final loc = currentLocale.value;
    final actions = ProfileTimezoneActions.currentSettings;
    final save = ProfileTimezoneActions.saveTimezone;
    if (actions == null || save == null) return;

    final current = actions().preferredTimeZone;
    final selected = await showTimezoneQuickPicker(
      context: context,
      currentTimezone: current,
    );
    if (selected == null || !context.mounted) return;

    final ok = await save(selected);
    if (!context.mounted) return;
    if (!ok) {
      AppSnack.show(t(loc, 'timezone_save_failed'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final tooltip = t(loc, 'change_timezone');

    return StreamBuilder<UserSettings>(
      stream: ProfileTimezoneActions.settingsStream,
      initialData: ProfileTimezoneActions.currentSettings?.call(),
      builder: (context, snapshot) {
        final label = ProfileTimezoneActions.shortLabel?.call() ?? '';
        final child = Text(label, style: textStyle);

        if (!enabled) return child;

        return Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            label: tooltip,
            child: Builder(
              builder: (anchorContext) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => unawaited(_openPicker(anchorContext)),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TimezonePickerField extends StatelessWidget {
  const TimezonePickerField({
    super.key,
    required this.currentTimezone,
    required this.label,
    required this.onSelected,
    this.enabled = true,
  });

  final String currentTimezone;
  final String label;
  final ValueChanged<String> onSelected;
  final bool enabled;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showTimezoneQuickPicker(
      context: context,
      currentTimezone: currentTimezone,
    );
    if (selected == null || !context.mounted) return;
    onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry =
        catalogEntryForStoredTimezone(currentTimezone) ??
        kProfileTimezoneCatalog.first;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => unawaited(_openPicker(context)) : null,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              enabled: enabled,
              suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
            ),
            isFocused: false,
            isEmpty: false,
            child: Row(
              children: [
                AppTimezoneIcon(
                  timezoneKey: entry.iconKey,
                  size: 28,
                  color: enabled ? scheme.onSurfaceVariant : scheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimezoneOptionText(entry: entry, selected: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Adaptive quick timezone picker — bottom sheet (compact) or anchored menu.
Future<String?> showTimezoneQuickPicker({
  required BuildContext context,
  required String currentTimezone,
}) async {
  final width = MediaQuery.sizeOf(context).width;
  final useSheet = width < 600;

  if (useSheet) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) =>
          _TimezoneQuickPickerSheet(currentTimezone: currentTimezone),
    );
  }

  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 480),
          child: _TimezoneQuickPickerSheet(currentTimezone: currentTimezone),
        ),
      ),
    );
  }

  final offset = box.localToGlobal(Offset.zero);
  final rect = RelativeRect.fromLTRB(
    offset.dx,
    offset.dy + box.size.height,
    offset.dx + box.size.width,
    offset.dy,
  );

  return showMenu<String>(
    context: context,
    position: rect,
    constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
    items: [
      for (final entry in kProfileTimezoneCatalog)
        PopupMenuItem<String>(
          value: entry.profileValue,
          child: TimezonePickerOptionRow(
            entry: entry,
            selected: profileTimezoneValuesMatch(
              currentTimezone,
              entry.profileValue,
            ),
          ),
        ),
    ],
  );
}

class _TimezoneQuickPickerSheet extends StatefulWidget {
  const _TimezoneQuickPickerSheet({required this.currentTimezone});

  final String currentTimezone;

  @override
  State<_TimezoneQuickPickerSheet> createState() =>
      _TimezoneQuickPickerSheetState();
}

class _TimezoneQuickPickerSheetState extends State<_TimezoneQuickPickerSheet> {
  final _searchController = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final entries = filterProfileTimezoneCatalog(_query);
    final currentEntry =
        catalogEntryForStoredTimezone(widget.currentTimezone) ??
        kProfileTimezoneCatalog.first;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t(loc, 'time_zone'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: t(loc, 'search_timezones'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: math.min(300, MediaQuery.sizeOf(context).height * 0.42),
            child: ListView(
              children: [
                TimezonePickerOptionRow(entry: currentEntry, selected: true),
                const Divider(height: 1),
                for (final entry in entries)
                  if (!profileTimezoneValuesMatch(
                    entry.profileValue,
                    currentEntry.profileValue,
                  ))
                    InkWell(
                      onTap: () =>
                          Navigator.of(context).pop(entry.profileValue),
                      child: TimezonePickerOptionRow(
                        entry: entry,
                        selected: false,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class TimezonePickerOptionRow extends StatelessWidget {
  const TimezonePickerOptionRow({
    super.key,
    required this.entry,
    required this.selected,
  });

  final ProfileTimezoneCatalogEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppTimezoneIcon(
              timezoneKey: entry.iconKey,
              size: 30,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimezoneOptionText(entry: entry, selected: selected),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _TimezoneOptionText extends StatelessWidget {
  const _TimezoneOptionText({required this.entry, required this.selected});

  final ProfileTimezoneCatalogEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveSubtitle = formatProfileTimezoneSecondaryLine(entry);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatProfileTimezonePrimaryLine(entry),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          effectiveSubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
