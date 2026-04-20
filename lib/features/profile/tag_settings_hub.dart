// ---------------------------------------------------------------------------
// Unified tag settings: list CRUD + global display mode ([profiles.tag_display_mode]).
// ---------------------------------------------------------------------------

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

  /// 0 = tags list, 1 = display style.
  final int initialTabIndex;

  /// PocketBase `tags.domain` for creates/fetches in the first tab (`plan` vs `list`).
  final String tagCreateDomain;

  @override
  State<TagSettingsHub> createState() => _TagSettingsHubState();
}

class _TagSettingsHubState extends State<TagSettingsHub>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final i = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(length: 2, vsync: this, initialIndex: i);
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
          tabs: [
            Tab(text: t(loc, 'tag_settings_tab_tags')),
            Tab(text: t(loc, 'tag_settings_tab_style')),
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
        ],
      ),
    );
  }
}
