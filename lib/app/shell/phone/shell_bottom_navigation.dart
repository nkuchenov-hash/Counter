import 'dart:ui' show ImageFilter;

import 'package:counter/core/app_colors.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Material [NavigationBar] wraps/clips 5 labels on ~390px phone widths (iOS web
/// is worse with text scaling). This compact bar matches APK phone metrics:
/// equal columns, single-line labels, no platform branches.
const double kShellBottomNavHeight = 66;

class ShellCompactBottomNav extends StatelessWidget {
  const ShellCompactBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.viewportWidth,
    this.seamlessGlass = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final double viewportWidth;
  final bool seamlessGlass;

  static const double _iconSize = 24;
  static const double _labelFontSize = 11;

  String _navLabel(String loc, String fullKey, String compactKey) {
    if (viewportWidth < kShellCompactNavLabelBreakpoint) {
      return t(loc, compactKey);
    }
    return t(loc, fullKey);
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final navTheme = Theme.of(context).navigationBarTheme;
    final indicator = navTheme.indicatorColor ?? scheme.primaryContainer;

    final items = <({IconData icon, IconData selectedIcon, String label, int index})>[
      (
        icon: Icons.timeline_outlined,
        selectedIcon: Icons.timeline_rounded,
        label: _navLabel(loc, 'tab_timeline', 'tab_timeline_compact'),
        index: 0,
      ),
      (
        icon: Icons.checklist_outlined,
        selectedIcon: Icons.checklist_rounded,
        label: _navLabel(loc, 'tab_planning', 'tab_planning_compact'),
        index: 1,
      ),
      (
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: _navLabel(loc, 'calendar', 'tab_calendar_compact'),
        index: 2,
      ),
      (
        icon: Icons.format_list_bulleted_outlined,
        selectedIcon: Icons.format_list_bulleted_rounded,
        label: _navLabel(loc, 'tab_lists', 'tab_lists_compact'),
        index: 3,
      ),
      (
        icon: AppMenuIcons.icon(AppMenuIconRole.menu),
        selectedIcon: AppMenuIcons.icon(AppMenuIconRole.menu),
        label: loc.toLowerCase().startsWith('ru') ? 'Настройки' : 'Settings',
        index: 4,
      ),
    ];

    final navigation = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SizedBox(
          height: kShellBottomNavHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Expanded(
                  child: _ShellBottomNavItem(
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    label: item.label,
                    selected: selectedIndex == item.index,
                    indicatorColor: indicator,
                    onTap: () => onDestinationSelected(item.index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    // Ordinary tabs have no full-width backplate. Settings alone adds a
    // downward feathered glass overlay where content scrolls under the dock.
    final content = !seamlessGlass ? navigation : Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0, 0.48, 1],
                colors: [
                  AppNeutralTones.white,
                  AppNeutralTones.white,
                  AppNeutralTones.transparent,
                ],
              ).createShader(bounds),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0, 0.4, 1],
                        colors: [
                          scheme.surfaceContainerLowest.withValues(alpha: 0.76),
                          scheme.surfaceContainerLowest.withValues(alpha: 0.28),
                          AppNeutralTones.transparent,
                        ],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
        navigation,
      ],
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: content,
    );
  }
}

// A neutral reflective surface, never a dark opaque selected indicator.
Color darkGlassHighlight(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppNeutralTones.white.withValues(alpha: 0.23)
        : AppNeutralTones.white.withValues(alpha: 0.83);

class _ShellBottomNavItem extends StatelessWidget {
  const _ShellBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.indicatorColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final Color indicatorColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return Material(
      color: AppNeutralTones.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: selected
                    ? BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            darkGlassHighlight(context),
                            indicatorColor.withValues(alpha: 0.35),
                          ],
                        ),
                        border: Border.all(
                          color: AppNeutralTones.white.withValues(alpha:
                            Theme.of(context).brightness == Brightness.dark
                                ? 0.31 : 0.82),
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(19),
                      )
                    : null,
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: ShellCompactBottomNav._iconSize,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ShellCompactBottomNav._labelFontSize,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.0,
                    color: fg,
                  ),
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
