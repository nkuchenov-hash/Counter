import 'package:counter/features/settings/timezone_settings.dart' as tz_settings;import 'package:counter/l10n/dictionary.dart';import 'package:flutter/material.dart';class DefaultPlanTimezoneSearchDelegate extends SearchDelegate<String?> {
  DefaultPlanTimezoneSearchDelegate({
    required this.loc,
    required this.options,
  }) : super(searchFieldLabel: t(loc, 'plan_default_time_tz_search'));

  final String loc;
  final List<tz_settings.CategoryDefaultTimezoneOption> options;

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
            return o.searchLabel.toLowerCase().contains(q) ||
                o.ianaId.toLowerCase().contains(q) ||
                o.shortLabel.toLowerCase().contains(q);
          }).toList();
    if (matches.isEmpty) {
      return Center(child: Text(t(loc, 'plan_default_time_tz_search')));
    }
    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final option = matches[index];
        return ListTile(
          title: Text(option.searchLabel),
          subtitle: Text(option.ianaId),
          trailing: Text(option.shortLabel),
          onTap: () => close(context, option.ianaId),
        );
      },
    );
  }
}
