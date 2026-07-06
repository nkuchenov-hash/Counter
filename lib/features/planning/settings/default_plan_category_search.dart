import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/features/categories/create_category_from_picker.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class DefaultPlanCategoryOption {
  const DefaultPlanCategoryOption({required this.id, required this.path});

  final int id;
  final String path;

  String get name {
    final parts = path.split('>');
    return parts.isEmpty ? path.trim() : parts.last.trim();
  }
}

class DefaultPlanCategorySearchDelegate
    extends SearchDelegate<DefaultPlanCategoryOption?> {
  DefaultPlanCategorySearchDelegate({required this.loc, required this.options})
    : super(searchFieldLabel: t(loc, 'plan_default_time_search_category'));

  final String loc;
  final List<DefaultPlanCategoryOption> options;

  Future<void> _createCategory(BuildContext context, {String? initialName}) async {
    final id = await showCreateCategoryFromPickerDialog(
      context,
      initialName: initialName,
      target: const CategoryPickerCreateTarget.root(),
    );
    if (id == null || !context.mounted) return;
    final path = DatabaseService.instance.getCategoryPath(id);
    close(context, DefaultPlanCategoryOption(id: id, path: path));
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (categoryCreateFromPickerAllowed())
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: t(loc, 'category_picker_add_root'),
          onPressed: () => unawaited(_createCategory(context)),
        ),
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final q = query.trim().toLowerCase();
    final matches = q.isEmpty
        ? options
        : options.where((o) {
            return o.path.toLowerCase().contains(q) ||
                o.name.toLowerCase().contains(q);
          }).toList();
    final canCreate = categoryCreateFromPickerAllowed();
    final offlineHint = canCreate
        ? null
        : t(loc, 'category_create_requires_connection');

    if (matches.isEmpty) {
      return ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: Text(t(loc, 'category_picker_add_root')),
            subtitle: offlineHint != null ? Text(offlineHint) : null,
            enabled: canCreate,
            onTap: canCreate ? () => unawaited(_createCategory(context)) : null,
          ),
          if (q.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(
                t(loc, 'category_picker_create_named')
                    .replaceFirst('%s', query.trim()),
              ),
              enabled: canCreate,
              onTap: canCreate
                  ? () => unawaited(
                        _createCategory(context, initialName: query.trim()),
                      )
                  : null,
            ),
          if (q.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t(loc, 'plan_default_time_search_category'),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    }

    return ListView.separated(
      itemCount: matches.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListTile(
            leading: const Icon(Icons.add_rounded),
            title: Text(t(loc, 'category_picker_add_root')),
            subtitle: offlineHint != null ? Text(offlineHint) : null,
            enabled: canCreate,
            onTap: canCreate ? () => unawaited(_createCategory(context)) : null,
          );
        }
        final option = matches[index - 1];
        return ListTile(
          title: Text(option.path),
          onTap: () => close(context, option),
        );
      },
    );
  }
}
