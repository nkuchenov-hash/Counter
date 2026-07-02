import 'package:counter/l10n/dictionary.dart';import 'package:flutter/material.dart';class DefaultPlanCategoryOption {
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

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
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
    if (matches.isEmpty) {
      return Center(child: Text(t(loc, 'plan_default_time_search_category')));
    }
    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final option = matches[index];
        return ListTile(
          title: Text(option.path),
          onTap: () => close(context, option),
        );
      },
    );
  }
}
