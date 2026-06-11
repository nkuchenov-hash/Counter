import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/chip_component.dart';
import 'package:flutter/material.dart';

/// Internal visual control surface for canonical components.
///
/// Admin-only, mock data only, and no database writes.
class ComponentLabPage extends StatelessWidget {
  const ComponentLabPage({super.key});

  static const routeName = '/internal/component-lab';

  @override
  Widget build(BuildContext context) {
    final isAdmin = DatabaseService.instance.settings.isAdmin;
    if (!isAdmin) {
      return const Scaffold(
        body: AppErrorState(
          message: 'Component Lab is available to admins only.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dev / Design Lab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _LabSection(title: 'Buttons', child: _ButtonsDemo()),
          _LabSection(
            title: 'Loading / Empty / Error states',
            child: _StateViewsDemo(),
          ),
          _LabSection(title: 'Chips / Tags', child: _ChipsDemo()),
          _LabSection(title: 'Cards', child: _PlaceholderDemo()),
          _LabSection(title: 'Tabs / Segments', child: _PlaceholderDemo()),
          _LabSection(title: 'Headers', child: _HeadersDemo()),
          _LabSection(title: 'Sheets / Inputs', child: _PlaceholderDemo()),
        ],
      ),
    );
  }
}

class _LabSection extends StatelessWidget {
  const _LabSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ButtonsDemo extends StatelessWidget {
  const _ButtonsDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ButtonGroup(
          label: 'Primary',
          children: [
            AppButton.primary(label: 'Primary enabled', onPressed: _mockAction),
            AppButton.primary(label: 'Primary disabled', onPressed: null),
            AppButton.primary(
              label: 'Primary loading',
              onPressed: _mockAction,
              loading: true,
            ),
          ],
        ),
        const _ButtonGroup(
          label: 'Secondary',
          children: [
            AppButton.secondary(
              label: 'Secondary enabled',
              onPressed: _mockAction,
            ),
            AppButton.secondary(label: 'Secondary disabled', onPressed: null),
            AppButton.secondary(
              label: 'Secondary loading',
              onPressed: _mockAction,
              loading: true,
            ),
          ],
        ),
        const _ButtonGroup(
          label: 'Danger / destructive',
          children: [
            AppButton.danger(
              label: 'Danger enabled',
              icon: Icons.delete_outline_rounded,
              onPressed: _mockAction,
            ),
            AppButton.danger(label: 'Danger disabled', onPressed: null),
            AppButton.danger(
              label: 'Danger loading',
              onPressed: _mockAction,
              loading: true,
            ),
          ],
        ),
        const _ButtonGroup(
          label: 'Ghost / outlined / icon',
          children: [
            AppButton.ghost(label: 'Ghost button', onPressed: _mockAction),
            AppButton.outlined(
              label: 'Outlined button',
              onPressed: _mockAction,
            ),
            AppButton.primary(
              label: 'Icon + label',
              icon: Icons.add_rounded,
              onPressed: _mockAction,
            ),
          ],
        ),
        const _ButtonGroup(
          label: 'Sizes',
          children: [
            AppButton.primary(
              label: 'Small',
              size: AppButtonSize.s,
              onPressed: _mockAction,
            ),
            AppButton.primary(
              label: 'Medium',
              size: AppButtonSize.m,
              onPressed: _mockAction,
            ),
            AppButton.primary(
              label: 'Large',
              size: AppButtonSize.l,
              onPressed: _mockAction,
            ),
          ],
        ),
        const _ButtonGroup(
          label: 'Width',
          children: [
            AppButton.secondary(label: 'Content width', onPressed: _mockAction),
          ],
        ),
        const AppButton.primary(
          label: 'Full width',
          fullWidth: true,
          onPressed: _mockAction,
        ),
      ],
    );
  }
}

void _mockAction() {}

class _ButtonGroup extends StatelessWidget {
  const _ButtonGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _StateViewsDemo extends StatelessWidget {
  const _StateViewsDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 48, child: AppLoading(size: AppLoadingSize.medium)),
        SizedBox(
          height: 140,
          child: AppEmptyState(message: 'No sample items yet.'),
        ),
        SizedBox(
          height: 140,
          child: AppErrorState(message: 'Sample error state.'),
        ),
      ],
    );
  }
}

class _ChipsDemo extends StatelessWidget {
  const _ChipsDemo();

  static const _sampleTags = [
    Tag(tagId: 1, name: 'Focus', color: '#6750A4', icon: 'work'),
    Tag(tagId: 2, name: 'Health', color: '#2E7D32', icon: 'favorite'),
    Tag(tagId: 3, name: 'Learning', color: '#EF6C00', icon: 'school'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TagQuickPickStrip(
        tags: _sampleTags,
        selected: const [
          Tag(tagId: 1, name: 'Focus', color: '#6750A4', icon: 'work'),
        ],
        onToggle: (_) {},
      ),
    );
  }
}

class _HeadersDemo extends StatelessWidget {
  const _HeadersDemo();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kGlobalCompactHeaderHeight,
      color: kGlobalCompactHeaderColor,
      alignment: Alignment.center,
      child: GlobalAppHeader(
        selectedDate: DateTime(2026, 6, 11),
        enabled: false,
        compact: true,
        onDateSelected: (_) {},
      ),
    );
  }
}

class _PlaceholderDemo extends StatelessWidget {
  const _PlaceholderDemo();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Placeholder: canonical component surface will be added here as V7 evolves.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
