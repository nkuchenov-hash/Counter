import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Prompt to pick a category chip before showing backlog rows.
class ListsNoCategoryEmptyPanel extends StatelessWidget {
  const ListsNoCategoryEmptyPanel({super.key, required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
        AppEmptyState(
          message: t(locale, 'lists_no_category_chosen'),
          icon: Icons.category_outlined,
        ),
      ],
    );
  }
}

/// Empty backlog for the active category filter.
class ListsFilteredEmptyPanel extends StatelessWidget {
  const ListsFilteredEmptyPanel({super.key, required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
        AppEmptyState(
          message: t(locale, 'lists_empty'),
          icon: Icons.inbox_outlined,
        ),
      ],
    );
  }
}

/// Centered loading indicator while backlog fetch is in flight.
class ListsLoadingPanel extends StatelessWidget {
  const ListsLoadingPanel({super.key});

  @override
  Widget build(BuildContext context) => const AppLoading();
}
