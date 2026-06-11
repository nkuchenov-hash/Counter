// ---------------------------------------------------------------------------
// MORE — Collapsed navigation: Profile, Categories. UI_ISOLATION.
// ---------------------------------------------------------------------------

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_list_view.dart';
import 'package:counter/features/dev/component_lab_view.dart';
import 'package:counter/features/profile/profile_view.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class MoreMenuPage extends StatelessWidget {
  const MoreMenuPage({
    super.key,
    required this.rules,
    required this.onCategoriesChanged,
    required this.onProfileSaved,
  });

  final List<CategoryRule> rules;
  final Future<void> Function() onCategoriesChanged;
  final VoidCallback onProfileSaved;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    return Scaffold(
      appBar: AppBar(title: Text(t(loc, 'tab_more'))),
      body: StreamBuilder<UserSettings>(
        stream: DatabaseService.instance.userSettingsStream,
        initialData: DatabaseService.instance.settings,
        builder: (context, settingsSnapshot) {
          final isAdmin =
              settingsSnapshot.data?.isAdmin ??
              DatabaseService.instance.settings.isAdmin;
          debugPrint(
            '[ADMIN_FLAG] MoreMenuPage settings.isAdmin=$isAdmin renderDevLab=$isAdmin',
          );
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(t(loc, 'more_menu_profile')),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (ctx) => ProfilePage(onSaved: onProfileSaved),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.label_rounded),
                title: Text(t(loc, 'more_menu_categories')),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (ctx) => StreamBuilder<List<CategoryRule>>(
                        stream: DatabaseService.instance.categoryStream,
                        initialData: rules,
                        builder: (context, snapshot) {
                          final r = snapshot.data ?? rules;
                          return CategoriesPage(
                            rules: r,
                            onChanged: onCategoriesChanged,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.design_services_rounded),
                  title: const Text('Dev / Design Lab'),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (ctx) => const ComponentLabPage(),
                      ),
                    );
                  },
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text(
                  'Admin flag: $isAdmin',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
