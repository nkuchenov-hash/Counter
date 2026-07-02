import 'package:flutter/material.dart';

/// Max content width for settings screens by form factor.
double settingsContentMaxWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1100) return 1120;
  if (w >= 760) return 960;
  return w;
}

bool settingsIsWideDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 960;

/// Black/neutral accent theme for settings tabs and toggles.
ThemeData settingsNeutralTheme(BuildContext context) {
  final base = Theme.of(context);
  final scheme = base.colorScheme.copyWith(
    primary: base.colorScheme.onSurface,
    onPrimary: base.colorScheme.surface,
  );
  return base.copyWith(
    colorScheme: scheme,
    tabBarTheme: base.tabBarTheme.copyWith(
      indicatorColor: scheme.onSurface,
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        return scheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.onSurface;
        return scheme.surfaceContainerHighest;
      }),
    ),
  );
}

enum AppSettingsTab {
  account,
  preferences,
  desktopVoice,
  notifications,
  appearance,
  about,
}

/// Horizontal category tabs for desktop settings (Account, Preferences, …).
class AppSettingsCategoryTabs extends StatelessWidget {
  const AppSettingsCategoryTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.labels,
  });

  final AppSettingsTab selected;
  final ValueChanged<AppSettingsTab> onSelected;
  final Map<AppSettingsTab, String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AppSettingsTab.values.map((tab) {
          final active = tab == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () => onSelected(tab),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labels[tab] ?? tab.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 2,
                      width: active ? 28 : 0,
                      color: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Visual keycap row for hotkey display (Ctrl + Shift + Space).
///
/// Desktop: single [Row] with fixed keycap widths — no [Wrap], no [Expanded].
class AppHotkeyKeycaps extends StatelessWidget {
  const AppHotkeyKeycaps({super.key, required this.label});

  final String label;

  static const double _keycapHeight = 48;

  static double _keycapWidth(String text) {
    final key = text.trim().toLowerCase();
    if (key == 'ctrl') return 72;
    if (key == 'shift') return 84;
    if (key == 'space') return 108;
    if (text.trim().length == 1) return 52;
    return 72;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = label
        .split('+')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      children.add(
        _Keycap(
          text: parts[i],
          theme: theme,
          width: _keycapWidth(parts[i]),
          height: _keycapHeight,
        ),
      );
      if (i < parts.length - 1) {
        children.add(
          SizedBox(
            width: 22,
            height: _keycapHeight,
            child: Center(
              child: Text(
                '+',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

class _Keycap extends StatelessWidget {
  const _Keycap({
    required this.text,
    required this.theme,
    required this.width,
    required this.height,
  });

  final String text;
  final ThemeData theme;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral settings page shell: soft background + centered max width.
class AppSettingsPageBody extends StatelessWidget {
  const AppSettingsPageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: settingsContentMaxWidth(context)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// White card section for settings groups.
class AppSettingsSectionCard extends StatelessWidget {
  const AppSettingsSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Standard settings switch row (min 48px tap target).
class AppSettingsSwitchRow extends StatelessWidget {
  const AppSettingsSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Label + value info row.
class AppSettingsInfoRow extends StatelessWidget {
  const AppSettingsInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline action buttons — content width, not full-width bars.
class AppSettingsActionRow extends StatelessWidget {
  const AppSettingsActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }
}

/// Two-column card grid on wide desktop; single column otherwise.
class AppSettingsCardGrid extends StatelessWidget {
  const AppSettingsCardGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map(
                (c) => SizedBox(
                  width: cardWidth.clamp(280, 540),
                  child: c,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

/// Compact card shell (title optional) for desktop grid cells.
class AppSettingsGridCard extends StatelessWidget {
  const AppSettingsGridCard({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null || title != null || trailing != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            if (title != null || leading != null) const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
