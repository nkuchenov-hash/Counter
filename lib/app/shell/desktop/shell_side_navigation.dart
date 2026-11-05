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
      color: scheme.surfaceContainerHigh,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 0, 16),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.onSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Icon(
                            AppMenuIcons.icon(AppMenuIconRole.viktor),
                            size: 19,
                            color: scheme.surfaceContainerHigh,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('LIFE OS',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                    ],
                  ),
                ),
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
    final bg = selected ? scheme.surfaceContainerLow : Colors.transparent;
    final fg = selected
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.86);
    final indicator = selected ? scheme.onSurface : Colors.transparent;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: scheme.brightness == Brightness.dark
            ? scheme.onSurface.withValues(alpha: 0.06)
            : const Color(0xFFF1F5F9),
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      letterSpacing: -0.1,
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
