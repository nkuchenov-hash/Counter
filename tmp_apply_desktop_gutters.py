from pathlib import Path


def repl(path, old, new, expected=1):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    n = s.count(old)
    if n != expected:
        raise SystemExit(f'{path}: expected {expected} matches, got {n}: {old[:100]!r}')
    p.write_text(s.replace(old, new), encoding='utf-8')


# Shared desktop geometry.
repl('lib/core/shell_adaptive.dart',
     "const double kShellSideNavWidth = 272;\n",
     "const double kShellSideNavWidth = 272;\n\n/// Canonical desktop content gutter from the side navigation and window edge.\nconst double kShellDesktopContentHorizontalPadding = 24;\n\n/// Canonical top inset for the first row of every primary desktop section.\nconst double kShellDesktopContentTopPadding = 6;\n")

repl('lib/core/widgets/compact_nav_controls.dart',
     "import 'package:counter/core/widgets/app_button.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/core/widgets/app_button.dart';\n")
repl('lib/core/widgets/compact_nav_controls.dart',
     "padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),",
     "padding: const EdgeInsets.fromLTRB(\n        kShellDesktopContentHorizontalPadding,\n        kShellDesktopContentTopPadding,\n        kShellDesktopContentHorizontalPadding,\n        6,\n      ),")

# Timeline.
repl('lib/features/timeline/timeline_header_controls.dart',
     "padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),",
     "padding: const EdgeInsets.fromLTRB(\n                kShellDesktopContentHorizontalPadding,\n                0,\n                kShellDesktopContentHorizontalPadding,\n                8,\n              ),")
repl('lib/features/timeline/timeline_day_page.dart',
     "import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';\n")
repl('lib/features/timeline/timeline_day_page.dart',
     "padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),",
     "padding: EdgeInsets.fromLTRB(\n        shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n            ? kShellDesktopContentHorizontalPadding\n            : 12,\n        12,\n        shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n            ? kShellDesktopContentHorizontalPadding\n            : 12,\n        12,\n      ),")

# Statistics surfaces inside Timeline.
repl('lib/features/stats/stats_view.dart',
     "import 'package:counter/core/widgets/compact_nav_controls.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/core/widgets/compact_nav_controls.dart';\n")
repl('lib/features/stats/stats_view.dart',
     "padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),",
     "padding: EdgeInsets.fromLTRB(\n            shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n                ? kShellDesktopContentHorizontalPadding\n                : 12,\n            8,\n            shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n                ? kShellDesktopContentHorizontalPadding\n                : 12,\n            4,\n          ),")
repl('lib/features/stats/stats_detail_tree.dart',
     "import 'package:counter/data/database_service.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/data/database_service.dart';\n")
repl('lib/features/stats/stats_detail_tree.dart',
     "padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),",
     "padding: EdgeInsets.symmetric(\n            horizontal: shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n                ? kShellDesktopContentHorizontalPadding\n                : 16,\n            vertical: 8,\n          ),")
repl('lib/features/stats/stats_detail_tree.dart',
     "padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),",
     "padding: EdgeInsets.fromLTRB(\n              shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n                  ? kShellDesktopContentHorizontalPadding\n                  : 12,\n              8,\n              shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n                  ? kShellDesktopContentHorizontalPadding\n                  : 12,\n              24,\n            ),")
repl('lib/features/stats/stats_visual_overview.dart',
     "import 'package:counter/data/database_service.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/data/database_service.dart';\n")
repl('lib/features/stats/stats_visual_overview.dart',
     "padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),",
     "padding: EdgeInsets.fromLTRB(\n        shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n            ? kShellDesktopContentHorizontalPadding\n            : 12,\n        10,\n        shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n            ? kShellDesktopContentHorizontalPadding\n            : 12,\n        28,\n      ),")

# Planning.
repl('lib/features/planning/widgets/planning_filter_controls.dart',
     "import 'package:counter/core/widgets/compact_nav_controls.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/core/widgets/compact_nav_controls.dart';\n")
repl('lib/features/planning/widgets/planning_filter_controls.dart',
     "? const EdgeInsets.fromLTRB(24, 0, 16, 10)",
     "? const EdgeInsets.fromLTRB(\n              kShellDesktopContentHorizontalPadding,\n              0,\n              kShellDesktopContentHorizontalPadding,\n              10,\n            )")
repl('lib/features/planning/planning_page.dart',
     "padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),",
     "padding: EdgeInsets.symmetric(\n        horizontal: shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n            ? kShellDesktopContentHorizontalPadding\n            : 8,\n        vertical: 8,\n      ),", expected=2)
for path in [
    'lib/features/planning/widgets/planning_category_grouped_list.dart',
    'lib/features/planning/widgets/planning_tag_grouped_list.dart',
]:
    repl(path,
         "import 'package:counter/data/models.dart';\n",
         "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/data/models.dart';\n")
    repl(path,
         "return ListView(\n      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),\n      children: children,\n    );",
         "final sidePadding = shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n        ? kShellDesktopContentHorizontalPadding\n        : 8.0;\n    return ListView(\n      padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 8),\n      children: children,\n    );")

# Calendar.
repl('lib/features/calendar/calendar_chrome_header.dart',
     "padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),",
     "padding: const EdgeInsets.fromLTRB(\n          kShellDesktopContentHorizontalPadding,\n          kShellDesktopContentTopPadding,\n          kShellDesktopContentHorizontalPadding,\n          6,\n        ),")
repl('lib/features/calendar/calendar_view.dart',
     "viewportW >= kShellDesktopNavBreakpoint ? 16 : 12,\n        4,\n        viewportW >= kShellDesktopNavBreakpoint ? 16 : 12,",
     "desktopCalendar ? kShellDesktopContentHorizontalPadding : 12,\n        4,\n        desktopCalendar ? kShellDesktopContentHorizontalPadding : 12,")
repl('lib/features/calendar/calendar_day_panel.dart',
     "import 'package:counter/core/widgets/app_button.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/core/widgets/app_button.dart';\n")
repl('lib/features/calendar/calendar_day_panel.dart',
     "padding: EdgeInsets.fromLTRB(12, desktopQuickAdd ? 8 : 0, 12, 8),",
     "padding: EdgeInsets.fromLTRB(\n            desktopQuickAdd ? kShellDesktopContentHorizontalPadding : 12,\n            desktopQuickAdd ? 8 : 0,\n            desktopQuickAdd ? kShellDesktopContentHorizontalPadding : 12,\n            8,\n          ),")
repl('lib/features/calendar/calendar_day_panel.dart',
     "padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),",
     "padding: EdgeInsets.fromLTRB(\n                  desktopQuickAdd ? kShellDesktopContentHorizontalPadding : 12,\n                  4,\n                  desktopQuickAdd ? kShellDesktopContentHorizontalPadding : 12,\n                  16,\n                ),")

# Paths.
repl('lib/features/paths/paths_page.dart',
     "return ListView(\n      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),\n      children: widgets,\n    );",
     "final sidePadding = shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n        ? kShellDesktopContentHorizontalPadding\n        : 12.0;\n    return ListView(\n      padding: EdgeInsets.fromLTRB(sidePadding, 12, sidePadding, 24),\n      children: widgets,\n    );")

# Categories.
repl('lib/features/settings/categories/category_row_widget.dart',
     "import 'package:counter/data/database_service.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/data/database_service.dart';\n")
repl('lib/features/settings/categories/category_row_widget.dart',
     "final bandMath = Padding(\n      padding: const EdgeInsets.fromLTRB(\n        kCategoryBandScreenMarginH,\n        6,\n        kCategoryBandScreenMarginH,\n        6,\n      ),",
     "final sideMargin = shellUsesSideNavigation(MediaQuery.sizeOf(context).width)\n        ? kShellDesktopContentHorizontalPadding\n        : kCategoryBandScreenMarginH;\n    final bandMath = Padding(\n      padding: EdgeInsets.fromLTRB(sideMargin, 6, sideMargin, 6),")

# Lists / Notes: same desktop edge, but keep tablet/mobile layout unchanged.
repl('lib/features/notes/notes_glm_surface.dart',
     "import 'package:counter/core/widgets/compact_nav_controls.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/core/widgets/compact_nav_controls.dart';\n")
repl('lib/features/notes/notes_glm_surface.dart',
     "final wide = MediaQuery.sizeOf(context).width >= 900;\n    return NotesGlmBackground(",
     "final width = MediaQuery.sizeOf(context).width;\n    final wide = width >= 900;\n    final desktop = shellUsesSideNavigation(width);\n    return NotesGlmBackground(")
repl('lib/features/notes/notes_glm_surface.dart',
     "constraints: BoxConstraints(maxWidth: maxWidth),\n            child: Padding(\n              padding: EdgeInsets.symmetric(\n                horizontal: wide ? 24 : 20,\n                vertical: 16,\n              ),",
     "constraints: BoxConstraints(\n              maxWidth: desktop ? double.infinity : maxWidth,\n            ),\n            child: Padding(\n              padding: EdgeInsets.fromLTRB(\n                desktop\n                    ? kShellDesktopContentHorizontalPadding\n                    : wide\n                    ? 24\n                    : 20,\n                desktop ? kShellDesktopContentTopPadding : 16,\n                desktop\n                    ? kShellDesktopContentHorizontalPadding\n                    : wide\n                    ? 24\n                    : 20,\n                16,\n              ),")

# Profile: same edge and no centered narrower desktop body.
repl('lib/app/shell/app_shell.dart',
     "import 'package:counter/core/shell_layout_state.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/core/shell_layout_state.dart';\n")
repl('lib/app/shell/shared/shell_chrome.dart',
     "padding: const EdgeInsets.fromLTRB(\n                                        24,\n                                        18,\n                                        24,\n                                        12,\n                                      ),",
     "padding: const EdgeInsets.fromLTRB(\n                                        kShellDesktopContentHorizontalPadding,\n                                        kShellDesktopContentTopPadding,\n                                        kShellDesktopContentHorizontalPadding,\n                                        12,\n                                      ),")
repl('lib/core/widgets/app_settings_layout.dart',
     "import 'package:flutter/material.dart';\n",
     "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:flutter/material.dart';\n")
repl('lib/core/widgets/app_settings_layout.dart',
     "final scheme = Theme.of(context).colorScheme;\n    return ColoredBox(",
     "final scheme = Theme.of(context).colorScheme;\n    final desktop = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);\n    return ColoredBox(")
repl('lib/core/widgets/app_settings_layout.dart',
     "constraints: BoxConstraints(maxWidth: settingsContentMaxWidth(context)),",
     "constraints: BoxConstraints(\n          maxWidth: desktop ? double.infinity : settingsContentMaxWidth(context),\n        ),")
repl('lib/core/widgets/app_settings_layout.dart',
     "padding: EdgeInsets.fromLTRB(\n              16,\n              16,\n              16,\n              16 + MediaQuery.viewPaddingOf(context).bottom,\n            ),",
     "padding: EdgeInsets.fromLTRB(\n              desktop ? kShellDesktopContentHorizontalPadding : 16,\n              desktop ? 0 : 16,\n              desktop ? kShellDesktopContentHorizontalPadding : 16,\n              16 + MediaQuery.viewPaddingOf(context).bottom,\n            ),")

# Design-system invariant.
p = Path('docs/DESIGN_SYSTEM.md')
s = p.read_text(encoding='utf-8')
marker = '### Desktop primary-section gutters'
if marker not in s:
    s += "\n\n### Desktop primary-section gutters\n\n- Primary desktop sections use one outer horizontal gutter: `kShellDesktopContentHorizontalPadding = 24px` from the side-navigation divider and from the right window edge.\n- The first desktop section row starts at `kShellDesktopContentTopPadding = 6px`. Do not add feature-local top padding above it.\n- Section headers, quick-entry rows, calendar surfaces, Timeline/Stats, list/card bodies, Paths folders/detail, Categories bands, Notes/Lists library and Profile settings must align to this same outer gutter. Desktop library/settings shells must not add a narrower centered max-width on top of that gutter.\n- Phone/tablet spacing is form-factor-owned and is not changed by this desktop contract.\n"
    p.write_text(s, encoding='utf-8')
