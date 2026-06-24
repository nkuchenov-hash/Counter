import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/time/profile_timezone_catalog.dart';
import 'package:counter/data/database_service.dart';
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
    final current = DatabaseService.instance.settings.preferredTimeZone;
    final selected = await showTimezoneQuickPicker(
      context: context,
      currentTimezone: current,
    );
    if (selected == null || !context.mounted) return;

    final ok = await DatabaseService.instance.updateTimeZone(selected);
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
      stream: DatabaseService.instance.userSettingsStream,
      initialData: DatabaseService.instance.settings,
      builder: (context, snapshot) {
        final label = DatabaseService.instance.profileTimezoneShortLabel();
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
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
      builder: (ctx) => _TimezoneQuickPickerSheet(
        currentTimezone: currentTimezone,
      ),
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
          child: _TimezonePickerRow(
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
                _TimezonePickerRow(
                  entry: currentEntry,
                  selected: true,
                  subtitle: t(loc, 'timezone_current'),
                ),
                const Divider(height: 1),
                for (final entry in entries)
                  if (!profileTimezoneValuesMatch(
                    entry.profileValue,
                    currentEntry.profileValue,
                  ))
                    InkWell(
                      onTap: () => Navigator.of(context).pop(entry.profileValue),
                      child: _TimezonePickerRow(
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

class _TimezonePickerRow extends StatelessWidget {
  const _TimezonePickerRow({
    required this.entry,
    required this.selected,
    this.subtitle,
  });

  final ProfileTimezoneCatalogEntry entry;
  final bool selected;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.pickerLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? scheme.primary : null,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_rounded, size: 20, color: scheme.primary),
        ],
      ),
    );
  }
}
