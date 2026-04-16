// ---------------------------------------------------------------------------
// MORE — Collapsed navigation: Profile, Categories. UI_ISOLATION.
// ---------------------------------------------------------------------------

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_list_view.dart';
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
      appBar: AppBar(
        title: Text(t(loc, 'tab_more')),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: Text(t(loc, 'more_menu_profile')),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (ctx) => ProfilePage(
                    onSaved: onProfileSaved,
                  ),
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
        ],
      ),
    );
  }
}
