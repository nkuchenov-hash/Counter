import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Desktop/web left navigation rail (replaces bottom nav at wide breakpoints).
class ShellSideNavigation extends StatelessWidget {
  const ShellSideNavigation({
    required this.width,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final double width;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final isRu = loc.toLowerCase().startsWith('ru');
    final items = <({IconData icon, IconData selectedIcon, String label, int index})>[
      (
        icon: Icons.timeline_outlined,
        selectedIcon: Icons.timeline_rounded,
        label: t(loc, 'tab_timeline'),
        index: 0,
      ),
      (
        icon: Icons.checklist_outlined,
        selectedIcon: Icons.checklist_rounded,
        label: t(loc, 'tab_planning'),
        index: 1,
      ),
      (
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: t(loc, 'calendar'),
        index: 2,
      ),
      (
        icon: Icons.format_list_bulleted_outlined,
        selectedIcon: Icons.format_list_bulleted_rounded,
        label: t(loc, 'tab_lists'),
        index: 3,
      ),
      (
        icon: Icons.alt_route_outlined,
        selectedIcon: Icons.alt_route_rounded,
        label: isRu ? 'Пути' : 'Paths',
        index: 6,
      ),
      (
        icon: Icons.label_outlined,
        selectedIcon: Icons.label_rounded,
        label: t(loc, 'more_menu_categories'),
        index: 4,
      ),
      (
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: t(loc, 'more_menu_profile'),
        index: 5,
      ),
      (
        icon: Icons.more_horiz_rounded,
        selectedIcon: Icons.more_horiz_rounded,
        label: t(loc, 'tab_more'),
        index: 7,
      ),
    ];
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
      child: SizedBox(
        width: width,
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ShellSideNavItem(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: item.label,
                      selected: selectedIndex == item.index,
                      onTap: () => onTabSelected(item.index),
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
    final bg = selected ? scheme.surfaceContainerHighest : Colors.transparent;
    final fg = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final indicator = selected ? scheme.primary : Colors.transparent;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: indicator, width: selected ? 3 : 0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
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
