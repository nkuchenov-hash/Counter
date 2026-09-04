from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, got {count}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


# Global header: allow desktop shell to keep the same date/time control on a light header.
p = Path('lib/core/widgets/global_app_header.dart')
text = p.read_text(encoding='utf-8')
text = text.replace(
    '    this.compact = false,\n  });',
    '    this.compact = false,\n    this.foregroundColor,\n  });',
    1,
)
text = text.replace(
    '  final bool compact;\n',
    '  final bool compact;\n  final Color? foregroundColor;\n',
    1,
)
start = text.index('    final titleStyle = compact\n')
end = text.index('    final weekday = DateFormat.EEEE(loc).format(selectedDate);\n', start)
new_style = '''    final compactForeground =\n        foregroundColor ?? kGlobalCompactHeaderForeground;\n    final titleStyle = compact\n        ? Theme.of(context).textTheme.titleSmall?.copyWith(\n                color: compactForeground,\n                fontSize: 15,\n                fontWeight: FontWeight.w600,\n                height: 1.1,\n              ) ??\n              TextStyle(\n                color: compactForeground,\n                fontSize: 15,\n                fontWeight: FontWeight.w600,\n                height: 1.1,\n              )\n        : Theme.of(context).appBarTheme.titleTextStyle ??\n              const TextStyle(fontSize: 20, fontWeight: FontWeight.w500);\n    final clockStyle = titleStyle.copyWith(\n      color: compact ? compactForeground : titleStyle.color,\n      fontSize: compact ? 13 : 14,\n      fontWeight: compact ? FontWeight.w600 : FontWeight.w400,\n    );\n'''
text = text[:start] + new_style + text[end:]
p.write_text(text, encoding='utf-8')

# Shell: one desktop-only, light, shell-level header for every desktop section.
p = Path('lib/app/shell/shared/shell_chrome.dart')
text = p.read_text(encoding='utf-8')
needle = '      ];\n\n  Widget buildShellDashboard(BuildContext context) {'
helper = '''      ];\n\n  String _desktopSectionTitle(String loc) => switch (shellPageIndex) {\n        0 => t(loc, 'tab_timeline'),\n        1 => t(loc, 'tab_planning'),\n        2 => t(loc, 'calendar'),\n        3 => t(loc, 'tab_lists'),\n        4 => t(loc, 'more_menu_categories'),\n        5 => t(loc, 'more_menu_profile'),\n        6 => loc.toLowerCase().startsWith('ru') ? 'Пути' : 'Paths',\n        _ => t(loc, 'app_title'),\n      };\n\n  Widget buildShellDashboard(BuildContext context) {'''
if text.count(needle) != 1:
    raise SystemExit('shell_chrome: helper insertion point mismatch')
text = text.replace(needle, helper, 1)
text = text.replace(
    '            final loc = currentLocale.value;\n            final builtTabs =',
    "            final loc = currentLocale.value;\n            final desktopShell = shellFormFactorForWidth(\n                  MediaQuery.sizeOf(context).width,\n                ) ==\n                ShellFormFactor.desktop;\n            final builtTabs =",
    1,
)
start = text.index('                          appBar: shellPageIndex <= 3\n')
end_marker = '                          body: LayoutBuilder(\n'
end = text.index(end_marker, start)
new_appbar = '''                          appBar: desktopShell || shellPageIndex <= 3\n                              ? AppBar(\n                                  toolbarHeight: kGlobalCompactHeaderHeight,\n                                  backgroundColor: desktopShell\n                                      ? scheme.surface\n                                      : kGlobalCompactHeaderColor,\n                                  foregroundColor: desktopShell\n                                      ? scheme.onSurface\n                                      : kGlobalCompactHeaderForeground,\n                                  surfaceTintColor: Colors.transparent,\n                                  automaticallyImplyLeading: false,\n                                  elevation: 0,\n                                  scrolledUnderElevation: 0,\n                                  titleSpacing: 16,\n                                  shape: desktopShell\n                                      ? Border(\n                                          bottom: BorderSide(\n                                            color: scheme.outlineVariant\n                                                .withValues(alpha: 0.65),\n                                          ),\n                                        )\n                                      : null,\n                                  title: Row(\n                                    children: [\n                                      Text(\n                                        desktopShell\n                                            ? _desktopSectionTitle(loc)\n                                            : t(loc, 'app_title'),\n                                        maxLines: 1,\n                                        overflow: TextOverflow.ellipsis,\n                                        style: Theme.of(context)\n                                            .textTheme\n                                            .titleMedium\n                                            ?.copyWith(\n                                              color: desktopShell\n                                                  ? scheme.onSurface\n                                                  : kGlobalCompactHeaderForeground,\n                                              fontWeight: FontWeight.w700,\n                                              height: 1.0,\n                                            ),\n                                      ),\n                                      const SizedBox(width: 12),\n                                      Expanded(\n                                        child: Align(\n                                          alignment:\n                                              AlignmentDirectional.centerEnd,\n                                          child: ListenableBuilder(\n                                            listenable: selectedDateListenable,\n                                            builder: (context, _) =>\n                                                GlobalAppHeader(\n                                              selectedDate: selectedDate,\n                                              onDateSelected:\n                                                  selectShellHeaderDate,\n                                              compact: true,\n                                              foregroundColor: desktopShell\n                                                  ? scheme.onSurface\n                                                  : null,\n                                            ),\n                                          ),\n                                        ),\n                                      ),\n                                    ],\n                                  ),\n                                )\n                              : null,\n'''
text = text[:start] + new_appbar + text[end:]
p.write_text(text, encoding='utf-8')

# Paths: the shell owns the desktop page title; keep only path-specific controls below it.
p = Path('lib/features/paths/paths_page.dart')
text = p.read_text(encoding='utf-8')
text = text.replace(
    "import 'package:counter/core/widgets/app_button.dart';",
    "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/core/widgets/app_button.dart';",
    1,
)
start = text.index('  Widget _header() {\n')
end = text.index('  Widget _body() {\n', start)
new_header = '''  Widget _header() {\n    final scheme = Theme.of(context).colorScheme;\n    final desktopShell = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);\n    return Padding(\n      padding: desktopShell\n          ? const EdgeInsets.fromLTRB(12, 0, 8, 0)\n          : const EdgeInsets.fromLTRB(20, 0, 12, 12),\n      child: Row(\n        children: [\n          if (!desktopShell) ...[\n            Icon(Icons.alt_route_rounded, color: scheme.primary),\n            const SizedBox(width: 10),\n            Expanded(\n              child: Column(\n                crossAxisAlignment: CrossAxisAlignment.start,\n                children: [\n                  Text(\n                    _ru ? 'Пути' : 'Paths',\n                    style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                          fontWeight: FontWeight.w800,\n                        ),\n                  ),\n                  Text(\n                    _ru ? 'Цель → этапы → действия.' : 'Goal → stages → actions.',\n                    style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                          color: scheme.onSurfaceVariant,\n                        ),\n                  ),\n                ],\n              ),\n            ),\n          ] else\n            const Spacer(),\n          AppIconButton(\n            icon: Icons.account_tree_outlined,\n            tooltip: _ru ? 'Папки в Путях' : 'Folders in Paths',\n            onPressed: _loading ? null : () => unawaited(_openFolderSelector()),\n          ),\n          AppIconButton(\n            icon: Icons.refresh_rounded,\n            tooltip: _ru ? 'Обновить' : 'Refresh',\n            onPressed: _loading ? null : () => unawaited(_load()),\n            loading: _loading,\n          ),\n        ],\n      ),\n    );\n  }\n\n'''
text = text[:start] + new_header + text[end:]
p.write_text(text, encoding='utf-8')

# Categories: remove the nested desktop AppBar; keep its two controls as a small local toolbar.
p = Path('lib/features/settings/categories/category_list_view.dart')
text = p.read_text(encoding='utf-8')
text = text.replace(
    "import 'package:counter/core/widgets/app_icon_button.dart';",
    "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/core/widgets/app_icon_button.dart';",
    1,
)
text = text.replace(
    '    final roots = _getItemsForDepth(0);\n',
    '    final roots = _getItemsForDepth(0);\n    final desktopShell = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);\n',
    1,
)
text = text.replace('      appBar: AppBar(\n', '      appBar: desktopShell ? null : AppBar(\n', 1)
text = text.replace(
    '      body: SafeArea(\n        child: Column(',
    '      body: SafeArea(\n        top: !desktopShell,\n        child: Column(',
    1,
)
marker = '          children: [\n            SwitchListTile(\n'
toolbar = '''          children: [\n            if (desktopShell)\n              Padding(\n                padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),\n                child: Row(\n                  mainAxisAlignment: MainAxisAlignment.end,\n                  children: [\n                    AppIconButton(\n                      icon: _useHorizontalScrollLayout\n                          ? Icons.grid_view_rounded\n                          : Icons.view_week_rounded,\n                      tooltip: _useHorizontalScrollLayout\n                          ? t(loc, 'switch_to_wrap')\n                          : t(loc, 'switch_to_scrollable'),\n                      onPressed: () => setState(\n                        () => _useHorizontalScrollLayout =\n                            !_useHorizontalScrollLayout,\n                      ),\n                    ),\n                    AppIconButton(\n                      tooltip: t(loc, 'add_category'),\n                      onPressed: () => unawaited(_addRule()),\n                      icon: Icons.add_rounded,\n                    ),\n                  ],\n                ),\n              ),\n            SwitchListTile(\n'''
if text.count(marker) != 1:
    raise SystemExit('category_list_view: body insertion point mismatch')
text = text.replace(marker, toolbar, 1)
p.write_text(text, encoding='utf-8')

# Profile/settings: desktop shell now owns the page heading, so remove the duplicate 32px title only.
p = Path('lib/features/profile/profile_view.dart')
text = p.read_text(encoding='utf-8')
old = '''        Text(\n          t(locale, 'profile_page_title'),\n          style: Theme.of(context).textTheme.headlineSmall?.copyWith(\n            fontWeight: FontWeight.w700,\n            fontSize: 32,\n            height: 1.15,\n          ),\n        ),\n        const SizedBox(height: 16),\n'''
if text.count(old) != 1:
    raise SystemExit('profile_view: desktop title block mismatch')
text = text.replace(old, '', 1)
p.write_text(text, encoding='utf-8')

# Record the shell rule so future feature work does not reintroduce duplicate desktop headers.
p = Path('docs/DESIGN_SYSTEM.md')
text = p.read_text(encoding='utf-8')
append = '''\n\n## Desktop shell chrome\n\nOn wide desktop layouts, the shell owns one shared top header for every primary section. Feature pages must not stack a second page AppBar/title above their content on desktop; feature-specific commands may remain in a compact secondary toolbar below the shared header. This rule applies to shell/menu chrome only and does not authorize redesigning feature cards, rows, editors, or other local controls. Phone and tablet chrome remain feature-adaptive unless separately specified.\n'''
if '## Desktop shell chrome' not in text:
    text += append
p.write_text(text, encoding='utf-8')
