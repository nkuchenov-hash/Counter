import 'package:counter/features/timeline/unfilled_time_gap_banner.dart';
import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// App-wide desktop navigation. The menu content must not draw a second rail.
class ShellSideNavigation extends StatelessWidget {
  const ShellSideNavigation({
    required this.width,
    required this.selectedIndex,
    required this.onTabSelected,
    super.key,
  });

  final double width;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  Widget _sectionLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 23, 8, 11),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _entry(
    AppMenuIconRole role,
    String label,
    int index,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Builder(
      builder: (context) => ShellSideNavItem(
        icon: AppMenuIcons.icon(role),
        selectedIcon: AppMenuIcons.icon(role),
        label: label,
        selected: selectedIndex == index,
        onTap: () => onTabSelected(index),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = currentLocale.value;
    final ru = locale.toLowerCase().startsWith('ru');
    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : const Color(0xFFECECEC),
      shape: Border(
        right: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: SizedBox(
        width: width,
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _sectionLabel(context,
                        ru ? 'РАБОЧЕЕ ПРОСТРАНСТВО' : 'WORKSPACE'),
                      _entry(AppMenuIconRole.timeline, t(locale, 'tab_timeline'), 0),
                      _entry(AppMenuIconRole.planning, t(locale, 'tab_planning'), 1),
                      _entry(AppMenuIconRole.calendar, t(locale, 'calendar'), 2),
                      _entry(AppMenuIconRole.notes, t(locale, 'tab_lists'), 3),
                      _sectionLabel(context,
                        ru ? 'ДОПОЛНИТЕЛЬНО' : 'MORE'),
                      _entry(AppMenuIconRole.paths, ru ? 'Пути' : 'Paths', 6),
                      _entry(AppMenuIconRole.categories,
                        t(locale, 'more_menu_categories'), 4),
                      _entry(AppMenuIconRole.people, ru ? 'Люди' : 'People', 8),
                      _entry(AppMenuIconRole.menu,
                        ru ? 'Меню' : 'Menu', 7),
                    ],
                  ),
                ),
                const UnfilledTimeGapSidebarCard(),
                const SizedBox(height: 12),
                Divider(height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.7)),
                const SizedBox(height: 7),
                _entry(AppMenuIconRole.account,
                  ru ? 'Профиль' : 'Profile', 5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShellSideNavItem extends StatelessWidget {
  const ShellSideNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? (scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerLow
            : const Color(0xFFDDDDDD))
        : Colors.transparent;
    final fg = scheme.brightness == Brightness.dark
        ? scheme.onSurface
        : const Color(0xFF454545);
    final indicator = selected ? scheme.onSurface : Colors.transparent;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: scheme.brightness == Brightness.dark
            ? scheme.onSurface.withValues(alpha: 0.06)
            : const Color(0xFFE1E1E1),
        splashColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: indicator, width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(selected ? selectedIcon : icon, size: 22, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontSize: 15.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
