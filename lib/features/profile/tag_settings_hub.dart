// ---------------------------------------------------------------------------
// Unified tag settings: list CRUD + global display mode + default plan durations.
// ---------------------------------------------------------------------------

import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_settings_breadcrumb_bar.dart';
import 'package:counter/features/profile/tag_default_duration_settings_view.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/features/profile/tag_settings_view.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class TagSettingsHub extends StatefulWidget {
  const TagSettingsHub({
    super.key,
    this.initialTabIndex = 0,
    this.tagCreateDomain = 'plan',
    this.backLabel,
  });

  /// 0 = tags list, 1 = display style, 2 = default plan durations (plan domain only).
  final int initialTabIndex;

  /// PocketBase `tags.domain` for creates/fetches in the first tab (`plan` vs `list`).
  final String tagCreateDomain;
  /// The route that actually launched Tags settings.
  final String? backLabel;

  @override
  State<TagSettingsHub> createState() => _TagSettingsHubState();
}

class _TagSettingsHubState extends State<TagSettingsHub>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _tabCount;

  bool get _showDurationsTab => widget.tagCreateDomain != 'list';

  @override
  void initState() {
    super.initState();
    _tabCount = _showDurationsTab ? 3 : 2;
    final i = widget.initialTabIndex.clamp(0, _tabCount - 1);
    _tabController = TabController(length: _tabCount, vsync: this, initialIndex: i);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// The tab body follows the exact same readable grid as the header.
  /// Keep the independently scrollable CRUD/editor views intact.
  Widget _contentFrame(BuildContext context, Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: settingsContentMaxWidth(context),
        ),
        child: SizedBox(
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = settingsNeutralTheme(context).colorScheme;
    return Theme(
      data: settingsNeutralTheme(context),
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppSettingsBreadcrumbBar(
          alignWithSettingsBody: true,
          parentLabel: widget.backLabel ?? (
              loc.toLowerCase().startsWith('ru')
                  ? 'Категории и теги'
                  : 'Categories & tags'),
          title: t(loc, 'tag_settings_hub_title'),
          onBack: () => Navigator.of(context).maybePop(),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: settingsContentMaxWidth(context),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: shellUsesSideNavigation(
                      MediaQuery.sizeOf(context).width,
                    ) ? kShellDesktopContentHorizontalPadding : 16,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: t(loc, 'tag_settings_tab_tags')),
                      Tab(text: t(loc, 'tag_settings_tab_style')),
                      if (_showDurationsTab)
                        Tab(text: t(loc, 'tag_settings_tab_durations')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _contentFrame(
              context,
              TagManagerPage(
                embeddedInHub: true,
                pocketTagDomain: widget.tagCreateDomain,
              ),
            ),
            _contentFrame(
              context,
              const TagSettingsView(embeddedInHub: true),
            ),
            if (_showDurationsTab)
              const TagDefaultDurationSettingsView(embeddedInHub: true),
          ],
        ),
      ),
    );
  }
}
