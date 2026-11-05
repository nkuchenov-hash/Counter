import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/core/app_colors.dart';
import 'package:flutter/material.dart';

/// Max content width for settings screens by form factor.
double settingsContentMaxWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1100) return 960;
  if (w >= 760) return 840;
  return w;
}

bool settingsIsWideDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 960;

/// Black/neutral accent theme for settings tabs and toggles.
ThemeData settingsNeutralTheme(BuildContext context) {
  final base = Theme.of(context);
  final dark = base.brightness == Brightness.dark;
  final scheme = base.colorScheme.copyWith(
    primary: base.colorScheme.onSurface,
    onPrimary: dark ? AppColors.darkAppBackground : Colors.white,
    // Neutral TECNO-inspired surfaces: distinct white cards, no blue tint.
    surface: dark ? const Color(0xFF161616) : AppColors.appBackground,
    surfaceContainerLowest:
        dark ? const Color(0xFF161616) : AppColors.appBackground,
    surfaceContainerLow:
        dark ? const Color(0xFF222222) : AppColors.appBackground,
    surfaceContainer:
        dark ? const Color(0xFF303030) : const Color(0xFFF4F4F4),
    surfaceContainerHigh:
        dark ? const Color(0xFF252525) : Colors.white,
    surfaceContainerHighest:
        dark ? const Color(0xFF303030) : Colors.white,
    onSurface: dark ? base.colorScheme.onSurface : const Color(0xFF282828),
    onSurfaceVariant: dark
        ? base.colorScheme.onSurfaceVariant
        : const Color(0xFF707070),
    outlineVariant: dark
        ? base.colorScheme.outlineVariant
        : const Color(0xFFF0F0F0),
  );
  return base.copyWith(
    colorScheme: scheme,
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: scheme.surfaceContainerLowest,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
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
    final desktop = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      // The scrollable owns the entire page viewport, so its native scrollbar
      // stays at the far-right page edge, not beside the centered white cards.
      child: ListView(
        padding: EdgeInsets.only(
          top: desktop ? 16 : 20,
          bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: settingsContentMaxWidth(context),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: desktop
                      ? kShellDesktopContentHorizontalPadding
                      : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 20),
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
          width: 0.7,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
            const SizedBox(height: 16),
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
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
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
    return Wrap(spacing: 8, runSpacing: 8, children: children);
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
              .map((c) => SizedBox(width: cardWidth.clamp(280, 540), child: c))
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
      color: scheme.surfaceContainerHigh,
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


/// Canonical navigation row for grouped settings and nested menus.
/// Prefer this over feature-local ListTile variants.
class AppSettingsNavigationRow extends StatelessWidget {
  const AppSettingsNavigationRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.value,
    this.showDivider = false,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? value;
  final VoidCallback? onTap;
  final bool showDivider;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final grouped = _AppSettingsRowPosition.maybeOf(context) != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          // Explicit group height: default ListTile density made adjacent icons
          // nearly touch. Card-edge breathing room belongs to the group below.
          contentPadding: grouped
              ? const EdgeInsets.symmetric(horizontal: 24)
              : const EdgeInsets.fromLTRB(24, 10, 24, 10),
          minTileHeight: grouped ? 74 : null,
          minVerticalPadding: 8,
          leading: leading,
          title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            height: 1.38,
          )),
          subtitle: subtitle == null ? null : Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(AppMenuIcons.icon(AppMenuIconRole.arrow), color: scheme.onSurfaceVariant),
            ],
          ),
          onTap: onTap,
          enabled: onTap != null,
          // Grouped rows use the full-width background owned by the group,
          // so InkWell cannot paint a second rectangle over the separator.
          hoverColor: _AppSettingsRowPosition.maybeOf(context) != null
              ? Colors.transparent
              : (scheme.brightness == Brightness.dark
                  ? scheme.onSurface.withValues(alpha: 0.06)
                  : const Color(0xFFE8E8E8)),
          splashColor: Colors.transparent,
          shape: const RoundedRectangleBorder(),
        ),
        if (showDivider) Divider(
          height: 1,
          thickness: 0.8,
          color: scheme.outlineVariant,
        ),
      ],
    );
  }
}


/// Icon-leading switch row for the approved grouped Settings surfaces.
/// Unlike a navigation row, its trailing switch changes the persisted setting.
class AppSettingsControlRow extends StatelessWidget {
  const AppSettingsControlRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      secondary: leading,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
      ),
      subtitle: subtitle == null ? null : Text(
        subtitle!,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Shared action row for overflow menus and modal sheets.
class AppMenuActionTile extends StatelessWidget {
  const AppMenuActionTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.destructive = false,
  });
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    return ListTile(
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: leading == null
          ? null
          : IconTheme(
              data: IconThemeData(color: foreground, size: 23),
              child: leading!,
            ),
      title: DefaultTextStyle.merge(
        style: TextStyle(color: foreground, fontWeight: FontWeight.w500),
        child: title,
      ),
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}


/// Marks rows belonging to a grouped card so ListTile uses the
/// canonical menu rhythm rather than its platform-dependent minimum.
class _AppSettingsRowPosition extends InheritedWidget {
  const _AppSettingsRowPosition({
    required this.first,
    required this.last,
    required super.child,
  });
  final bool first;
  final bool last;
  static _AppSettingsRowPosition? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppSettingsRowPosition>();
  @override
  bool updateShouldNotify(_AppSettingsRowPosition oldWidget) =>
      first != oldWidget.first || last != oldWidget.last;
}

/// Borderless white group with independently hoverable full-width rows.
///
/// The divider is painted as part of the same visual surface. When the pointer
/// is on either neighboring item, that divider gently disappears into the
/// hover shade instead of showing as a separate line.
class AppSettingsNavigationGroup extends StatefulWidget {
  const AppSettingsNavigationGroup({
    super.key,
    required this.children,
  });
  final List<Widget> children;
  @override
  State<AppSettingsNavigationGroup> createState() =>
      _AppSettingsNavigationGroupState();
}

class _AppSettingsNavigationGroupState
    extends State<AppSettingsNavigationGroup> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final hoverFill = dark
        ? scheme.onSurface.withValues(alpha: 0.06)
        : const Color(0xFFE8E8E8);
    final dividerFill = dark
        ? scheme.outlineVariant
        : const Color(0xFFF0F0F0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < widget.children.length; index++) ...[
              MouseRegion(
                onEnter: (_) {
                  if (_hoveredIndex != index) {
                    setState(() => _hoveredIndex = index);
                  }
                },
                onExit: (_) {
                  if (_hoveredIndex == index) {
                    setState(() => _hoveredIndex = null);
                  }
                },
                child: ColoredBox(
                  key: ValueKey('settings-row-$index'),
                  // A single immediate fill replaces three overlapping
                  // animations that flashed on mouse movement and crossing
                  // the divider. Hover never covers the whole group.
                  color: _hoveredIndex == index
                      ? hoverFill
                      : scheme.surfaceContainerHigh,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 8 : 0,
                      bottom: index == widget.children.length - 1 ? 8 : 0,
                    ),
                    child: _AppSettingsRowPosition(
                      first: index == 0,
                      last: index == widget.children.length - 1,
                      child: widget.children[index],
                    ),
                  ),
                ),
              ),
              if (index != widget.children.length - 1)
                SizedBox(
                  height: 1,
                  child: ColoredBox(
                    key: ValueKey('settings-divider-$index'),
                    color: _hoveredIndex == index ||
                            _hoveredIndex == index + 1
                        ? hoverFill
                        : scheme.surfaceContainerHigh,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 78, right: 20),
                      child: ColoredBox(
                        key: ValueKey('settings-divider-line-$index'),
                        color: _hoveredIndex == index ||
                                _hoveredIndex == index + 1
                            ? hoverFill
                            : dividerFill,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact neutral icon treatment shared by settings index destinations.
class AppSettingsMenuIcon extends StatelessWidget {
  const AppSettingsMenuIcon({super.key, required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 42,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: scheme.onSurface),
      ),
    );
  }
}

/// Saved theme selection with clear light/dark previews and a system option.
/// All modes remain backed by the existing profile setting.
class AppSettingsThemeModePicker extends StatelessWidget {
  const AppSettingsThemeModePicker({
    super.key,
    required this.value,
    required this.lightLabel,
    required this.darkLabel,
    required this.systemLabel,
    required this.onChanged,
    this.saving = false,
  });

  final String value;
  final String lightLabel;
  final String darkLabel;
  final String systemLabel;
  final ValueChanged<String>? onChanged;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final onSelect = saving ? null : onChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _AppSettingsThemeChoice(
                label: lightLabel,
                dark: false,
                selected: value == 'light',
                onTap: onSelect == null ? null : () => onSelect('light'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AppSettingsThemeChoice(
                label: darkLabel,
                dark: true,
                selected: value == 'dark',
                onTap: onSelect == null ? null : () => onSelect('dark'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppSettingsNavigationRow(
          title: systemLabel,
          leading: const AppSettingsMenuIcon(icon: Icons.settings_suggest_rounded),
          value: value == 'system' ? '✓' : null,
          onTap: onSelect == null ? null : () => onSelect('system'),
        ),
        if (saving)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

class _AppSettingsThemeChoice extends StatelessWidget {
  const _AppSettingsThemeChoice({
    required this.label,
    required this.dark,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool dark;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewBg = dark ? const Color(0xFF262626) : const Color(0xFFFFFFFF);
    final previewPanel = dark ? const Color(0xFF383838) : const Color(0xFFF0F0F0);
    final previewStroke = dark ? const Color(0xFF646464) : const Color(0xFFE3E3E3);
    final selectedColor = scheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? selectedColor
                    : scheme.outlineVariant.withValues(alpha: 0.7),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1.3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: previewBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: previewStroke, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: previewPanel,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 13),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: previewPanel,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(height: 5, width: 70, color: previewStroke),
                                const SizedBox(height: 7),
                                Container(height: 5, width: 45, color: previewStroke),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 23,
                  color: selected ? selectedColor : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Single-select option inside a grouped settings surface.
class AppSettingsSelectionRow extends StatelessWidget {
  const AppSettingsSelectionRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.leading,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        minVerticalPadding: 12,
        leading: leading,
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color: selected
              ? theme.colorScheme.onSurface
              : theme.colorScheme.outline,
        ),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
  }
}
