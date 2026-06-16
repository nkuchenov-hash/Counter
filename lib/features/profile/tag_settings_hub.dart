// ---------------------------------------------------------------------------
// Unified tag settings: list CRUD + global display mode + default plan durations.
// ---------------------------------------------------------------------------

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
  });

  /// 0 = tags list, 1 = display style, 2 = default plan durations (plan domain only).
  final int initialTabIndex;

  /// PocketBase `tags.domain` for creates/fetches in the first tab (`plan` vs `list`).
  final String tagCreateDomain;

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

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(t(loc, 'tag_settings_hub_title')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: _showDurationsTab,
          tabs: [
            Tab(text: t(loc, 'tag_settings_tab_tags')),
            Tab(text: t(loc, 'tag_settings_tab_style')),
            if (_showDurationsTab)
              Tab(text: t(loc, 'tag_settings_tab_durations')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TagManagerPage(
            embeddedInHub: true,
            pocketTagDomain: widget.tagCreateDomain,
          ),
          const TagSettingsView(embeddedInHub: true),
          if (_showDurationsTab)
            const TagDefaultDurationSettingsView(embeddedInHub: true),
        ],
      ),
    );
  }
}
