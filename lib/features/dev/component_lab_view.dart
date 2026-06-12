import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
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
          _LabSection(title: 'Icon Button', child: _IconButtonsDemo()),
          _LabSection(
            title: 'Loading / Empty / Error states',
            child: _StateViewsDemo(),
          ),
          _LabSection(title: 'Chips / Tags', child: _ChipsDemo()),
          _LabSection(
            title: 'Cards',
            child: _PlaceholderDemo(
              figmaName: 'Card',
              flutterMapping: 'Future: AppTaskCard or AppCard',
              variant: 'placeholder',
              note:
                  'No card migration in V7E. Surface reserved for future V7 pass.',
            ),
          ),
          _LabSection(
            title: 'Tabs / Segments',
            child: _PlaceholderDemo(
              figmaName: 'Tabs',
              flutterMapping: 'Future: AppSegmentedTabs',
              variant: 'placeholder',
              note: 'No tabs/segments migration in V7E.',
            ),
          ),
          _LabSection(title: 'Headers', child: _HeadersDemo()),
          _LabSection(
            title: 'Sheets / Inputs',
            child: _PlaceholderDemo(
              figmaName: 'Sheet / Input',
              flutterMapping: 'Future: AppSheet / AppTextField',
              variant: 'placeholder',
              note: 'No sheet/input migration in V7E.',
            ),
          ),
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
            _LabExample(
              title: 'Button / Primary / M',
              flutterMapping: 'AppButton.primary(size: AppButtonSize.m)',
              variant: 'primary',
              size: 'M',
              state: 'enabled',
              child: AppButton.primary(
                label: 'Primary enabled',
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Button / Primary / M',
              flutterMapping: 'AppButton.primary(size: AppButtonSize.m)',
              variant: 'primary',
              size: 'M',
              state: 'disabled',
              child: AppButton.primary(
                label: 'Primary disabled',
                onPressed: null,
              ),
            ),
            _LabExample(
              title: 'Button / Primary / M',
              flutterMapping:
                  'AppButton.primary(size: AppButtonSize.m, loading: true)',
              variant: 'primary',
              size: 'M',
              state: 'loading',
              child: AppButton.primary(
                label: 'Primary loading',
                onPressed: _mockAction,
                loading: true,
              ),
            ),
          ],
        ),
        const _ButtonGroup(
          label: 'Secondary',
          children: [
            _LabExample(
              title: 'Button / Secondary / M',
              flutterMapping: 'AppButton.secondary(size: AppButtonSize.m)',
              variant: 'secondary',
              size: 'M',
              state: 'enabled',
              child: AppButton.secondary(
                label: 'Secondary enabled',
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Button / Secondary / M',
              flutterMapping: 'AppButton.secondary(size: AppButtonSize.m)',
              variant: 'secondary',
              size: 'M',
              state: 'disabled',
              child: AppButton.secondary(
                label: 'Secondary disabled',
                onPressed: null,
              ),
            ),
            _LabExample(
              title: 'Button / Secondary / M',
              flutterMapping:
                  'AppButton.secondary(size: AppButtonSize.m, loading: true)',
              variant: 'secondary',
              size: 'M',
              state: 'loading',
              child: AppButton.secondary(
                label: 'Secondary loading',
                onPressed: _mockAction,
                loading: true,
              ),
            ),
          ],
        ),
        const _ButtonGroup(
          label: 'Danger / destructive',
          children: [
            _LabExample(
              title: 'Button / Danger / M',
              flutterMapping: 'AppButton.danger(size: AppButtonSize.m)',
              variant: 'danger',
              size: 'M',
              state: 'enabled',
              child: AppButton.danger(
                label: 'Danger enabled',
                icon: Icons.delete_outline_rounded,
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Button / Danger / M',
              flutterMapping: 'AppButton.danger(size: AppButtonSize.m)',
              variant: 'danger',
              size: 'M',
              state: 'disabled',
              child: AppButton.danger(
                label: 'Danger disabled',
                onPressed: null,
              ),
            ),
            _LabExample(
              title: 'Button / Danger / M',
              flutterMapping:
                  'AppButton.danger(size: AppButtonSize.m, loading: true)',
              variant: 'danger',
              size: 'M',
              state: 'loading',
              child: AppButton.danger(
                label: 'Danger loading',
                onPressed: _mockAction,
                loading: true,
              ),
            ),
          ],
        ),
        const _ButtonGroup(
          label: 'Ghost / outlined / icon',
          children: [
            _LabExample(
              title: 'Button / Ghost / M',
              flutterMapping: 'AppButton.ghost(size: AppButtonSize.m)',
              variant: 'ghost',
              size: 'M',
              state: 'enabled',
              child: AppButton.ghost(
                label: 'Ghost button',
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Button / Outlined / M',
              flutterMapping: 'AppButton.outlined(size: AppButtonSize.m)',
              variant: 'outlined',
              size: 'M',
              state: 'enabled',
              child: AppButton.outlined(
                label: 'Outlined button',
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Button / Primary / M / Icon',
              flutterMapping:
                  'AppButton.primary(size: AppButtonSize.m, icon: Icons.add_rounded)',
              variant: 'primary',
              size: 'M',
              state: 'enabled',
              note:
                  'Use for app actions with a supporting icon and visible label.',
              child: AppButton.primary(
                label: 'Icon + label',
                icon: Icons.add_rounded,
                onPressed: _mockAction,
              ),
            ),
          ],
        ),
        const _ButtonGroup(
          label: 'Sizes',
          children: [
            _LabExample(
              title: 'Button / Primary / S',
              flutterMapping: 'AppButton.primary(size: AppButtonSize.s)',
              variant: 'primary',
              size: 'S',
              state: 'enabled',
              child: AppButton.primary(
                label: 'Small',
                size: AppButtonSize.s,
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Button / Primary / M',
              flutterMapping: 'AppButton.primary(size: AppButtonSize.m)',
              variant: 'primary',
              size: 'M',
              state: 'enabled',
              child: AppButton.primary(
                label: 'Medium',
                size: AppButtonSize.m,
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Button / Primary / L',
              flutterMapping: 'AppButton.primary(size: AppButtonSize.l)',
              variant: 'primary',
              size: 'L',
              state: 'enabled',
              child: AppButton.primary(
                label: 'Large',
                size: AppButtonSize.l,
                onPressed: _mockAction,
              ),
            ),
          ],
        ),
        const _ButtonGroup(
          label: 'Width',
          children: [
            _LabExample(
              title: 'Button / Secondary / M / Content width',
              flutterMapping: 'AppButton.secondary(size: AppButtonSize.m)',
              variant: 'secondary',
              size: 'M',
              state: 'enabled',
              note: 'Default width follows content.',
              child: AppButton.secondary(
                label: 'Content width',
                onPressed: _mockAction,
              ),
            ),
          ],
        ),
        const _LabExample(
          title: 'Button / Primary / M / Full width',
          flutterMapping:
              'AppButton.primary(size: AppButtonSize.m, fullWidth: true)',
          variant: 'primary',
          size: 'M',
          state: 'enabled',
          note: 'Use for full-row sheet or page actions.',
          fullWidth: true,
          child: AppButton.primary(
            label: 'Full width',
            fullWidth: true,
            onPressed: _mockAction,
          ),
        ),
      ],
    );
  }
}

void _mockAction() {}

class _IconButtonsDemo extends StatelessWidget {
  const _IconButtonsDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ButtonGroup(
          label: 'Variants',
          children: [
            _LabExample(
              title: 'Icon Button / Standard / M',
              flutterMapping:
                  'AppIconButton(variant: AppIconButtonVariant.standard, size: AppIconButtonSize.m)',
              variant: 'standard',
              size: 'M',
              state: 'enabled',
              note: 'Default icon-only action. Tooltip is required.',
              child: AppIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: 'More actions',
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Icon Button / Standard / M',
              flutterMapping:
                  'AppIconButton(variant: AppIconButtonVariant.standard, size: AppIconButtonSize.m)',
              variant: 'standard',
              size: 'M',
              state: 'disabled',
              child: AppIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: 'More actions disabled',
                onPressed: null,
              ),
            ),
            _LabExample(
              title: 'Icon Button / Subtle / M',
              flutterMapping:
                  'AppIconButton(variant: AppIconButtonVariant.subtle, size: AppIconButtonSize.m)',
              variant: 'subtle',
              size: 'M',
              state: 'enabled',
              child: AppIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Adjust options',
                variant: AppIconButtonVariant.subtle,
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Icon Button / Filled / M',
              flutterMapping:
                  'AppIconButton(variant: AppIconButtonVariant.filled, size: AppIconButtonSize.m)',
              variant: 'filled',
              size: 'M',
              state: 'enabled',
              child: AppIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Add item',
                variant: AppIconButtonVariant.filled,
                onPressed: _mockAction,
              ),
            ),
          ],
        ),
        _ButtonGroup(
          label: 'Danger / selected',
          children: [
            _LabExample(
              title: 'Icon Button / Danger / M',
              flutterMapping:
                  'AppIconButton(variant: AppIconButtonVariant.danger, size: AppIconButtonSize.m)',
              variant: 'danger',
              size: 'M',
              state: 'enabled',
              note: 'Use for destructive icon-only actions after confirmation.',
              child: AppIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete sample',
                variant: AppIconButtonVariant.danger,
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Icon Button / Danger / M',
              flutterMapping:
                  'AppIconButton(variant: AppIconButtonVariant.danger, size: AppIconButtonSize.m)',
              variant: 'danger',
              size: 'M',
              state: 'disabled',
              child: AppIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete sample disabled',
                variant: AppIconButtonVariant.danger,
                onPressed: null,
              ),
            ),
            _LabExample(
              title: 'Icon Button / Selected / M',
              flutterMapping:
                  'AppIconButton(selected: true, size: AppIconButtonSize.m)',
              variant: 'standard',
              size: 'M',
              state: 'selected',
              child: AppIconButton(
                icon: Icons.check_rounded,
                tooltip: 'Selected sample',
                selected: true,
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Icon Button / Standard / M / Loading',
              flutterMapping:
                  'AppIconButton(loading: true, size: AppIconButtonSize.m)',
              variant: 'standard',
              size: 'M',
              state: 'loading',
              child: AppIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Loading sample',
                loading: true,
                onPressed: _mockAction,
              ),
            ),
          ],
        ),
        _ButtonGroup(
          label: 'Sizes',
          children: [
            _LabExample(
              title: 'Icon Button / Standard / S',
              flutterMapping:
                  'AppIconButton(size: AppIconButtonSize.s, variant: AppIconButtonVariant.standard)',
              variant: 'standard',
              size: 'S',
              state: 'enabled',
              child: AppIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Small close',
                size: AppIconButtonSize.s,
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Icon Button / Standard / M',
              flutterMapping:
                  'AppIconButton(size: AppIconButtonSize.m, variant: AppIconButtonVariant.standard)',
              variant: 'standard',
              size: 'M',
              state: 'enabled',
              child: AppIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Medium close',
                size: AppIconButtonSize.m,
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Icon Button / Standard / L',
              flutterMapping:
                  'AppIconButton(size: AppIconButtonSize.l, variant: AppIconButtonVariant.standard)',
              variant: 'standard',
              size: 'L',
              state: 'enabled',
              child: AppIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Large close',
                size: AppIconButtonSize.l,
                onPressed: _mockAction,
              ),
            ),
          ],
        ),
        _ButtonGroup(
          label: 'Usage examples',
          children: [
            _LabExample(
              title: 'Icon Button / Navigation Control / M',
              flutterMapping:
                  'AppIconButton(icon: Icons.arrow_back_rounded, tooltip: ...)',
              variant: 'standard',
              size: 'M',
              state: 'enabled',
              note:
                  'Navigation/control example; no production migration in V7F.',
              child: AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Icon Button / Inline Action / M',
              flutterMapping:
                  'AppIconButton(variant: AppIconButtonVariant.subtle, icon: Icons.edit_rounded, tooltip: ...)',
              variant: 'subtle',
              size: 'M',
              state: 'enabled',
              note: 'Inline action example for future sheet/list migrations.',
              child: AppIconButton(
                icon: Icons.edit_rounded,
                tooltip: 'Edit item',
                variant: AppIconButtonVariant.subtle,
                onPressed: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Icon Button / Destructive Action / M',
              flutterMapping:
                  'AppIconButton(variant: AppIconButtonVariant.danger, icon: Icons.delete_outline_rounded, tooltip: ...)',
              variant: 'danger',
              size: 'M',
              state: 'enabled',
              note: 'Destructive action example only; no real delete.',
              child: AppIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete item',
                variant: AppIconButtonVariant.danger,
                onPressed: _mockAction,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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

class _LabExample extends StatelessWidget {
  const _LabExample({
    required this.title,
    required this.flutterMapping,
    required this.child,
    this.variant,
    this.size,
    this.state,
    this.note,
    this.fullWidth = false,
  });

  final String title;
  final String flutterMapping;
  final Widget child;
  final String? variant;
  final String? size;
  final String? state;
  final String? note;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.8);
    final content = Container(
      width: fullWidth ? double.infinity : 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LabCodeLabel(title),
          const SizedBox(height: 8),
          _LabMetaLine(label: 'Flutter', value: flutterMapping),
          if (variant != null) _LabMetaLine(label: 'Variant', value: variant!),
          if (size != null) _LabMetaLine(label: 'Size', value: size!),
          if (state != null) _LabMetaLine(label: 'State', value: state!),
          if (note != null) _LabMetaLine(label: 'Note', value: note!),
          const SizedBox(height: 12),
          Align(
            alignment: fullWidth
                ? AlignmentDirectional.center
                : AlignmentDirectional.centerStart,
            child: fullWidth
                ? SizedBox(width: double.infinity, child: child)
                : child,
          ),
        ],
      ),
    );
    return fullWidth ? content : IntrinsicWidth(child: content);
  }
}

class _LabCodeLabel extends StatelessWidget {
  const _LabCodeLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LabMetaLine extends StatelessWidget {
  const _LabMetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _StateViewsDemo extends StatelessWidget {
  const _StateViewsDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabExample(
          title: 'Loading / Spinner / M',
          flutterMapping: 'AppLoading(size: AppLoadingSize.medium)',
          variant: 'spinner',
          size: 'M',
          state: 'loading',
          child: SizedBox(
            height: 48,
            child: AppLoading(size: AppLoadingSize.medium),
          ),
        ),
        SizedBox(height: 12),
        _LabExample(
          title: 'Empty State / Default',
          flutterMapping: 'AppEmptyState(message: ...)',
          variant: 'default',
          state: 'empty',
          child: SizedBox(
            height: 140,
            child: AppEmptyState(message: 'No sample items yet.'),
          ),
        ),
        SizedBox(height: 12),
        _LabExample(
          title: 'Error State / Default',
          flutterMapping: 'AppErrorState(message: ...)',
          variant: 'default',
          state: 'error',
          child: SizedBox(
            height: 140,
            child: AppErrorState(message: 'Sample error state.'),
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LabExample(
          title: 'Chip / Tag Pill / Compact Card',
          flutterMapping:
              'CategoryChip(variant: CategoryChipVariant.compactCard)',
          variant: 'compact card',
          state: 'letter_chip',
          note: 'Stadium pill for task/list cards; parent owns spacing.',
          child: CategoryChip(
            mode: CategoryDisplayMode.letterChip,
            label: 'Focus',
            color: Color(0xFF6750A4),
            icon: Icons.work_outline_rounded,
            variant: CategoryChipVariant.compactCard,
          ),
        ),
        const SizedBox(height: 12),
        const _LabExample(
          title: 'Chip / Tag Pill / Interactive Picker',
          flutterMapping:
              'CategoryChip(variant: CategoryChipVariant.largePicker)',
          variant: 'large picker',
          state: 'selected',
          note: 'Larger stadium pill for edit sheets/menus; no outer margin.',
          child: CategoryChip(
            mode: CategoryDisplayMode.letterChip,
            label: 'Focus',
            color: Color(0xFF6750A4),
            icon: Icons.work_outline_rounded,
            selected: true,
            variant: CategoryChipVariant.largePicker,
            onTap: _mockAction,
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Chip / Tag Picker Strip / Horizontal scroll',
          flutterMapping: 'TagQuickPickStrip(variant: largePicker)',
          variant: 'tag picker',
          state: 'one selected',
          note: 'Horizontal scroll row for edit sheets.',
          fullWidth: true,
          child: SizedBox(
            height: 48,
            child: TagQuickPickStrip(
              tags: _sampleTags,
              selected: const [
                Tag(tagId: 1, name: 'Focus', color: '#6750A4', icon: 'work'),
              ],
              variant: CategoryChipVariant.largePicker,
              onToggle: (_) {},
            ),
          ),
        ),
      ],
    );
  }
}

class _HeadersDemo extends StatelessWidget {
  const _HeadersDemo();

  @override
  Widget build(BuildContext context) {
    return _LabExample(
      title: 'Header / Global / Compact',
      flutterMapping: 'GlobalAppHeader(compact: true)',
      variant: 'compact',
      state: 'disabled sample',
      note:
          'Current shell header primitive; future V7 may rename/expand as AppShellHeader.',
      fullWidth: true,
      child: Container(
        height: kGlobalCompactHeaderHeight,
        color: kGlobalCompactHeaderColor,
        alignment: Alignment.center,
        child: GlobalAppHeader(
          selectedDate: DateTime(2026, 6, 11),
          enabled: false,
          compact: true,
          onDateSelected: (_) {},
        ),
      ),
    );
  }
}

class _PlaceholderDemo extends StatelessWidget {
  const _PlaceholderDemo({
    required this.figmaName,
    required this.flutterMapping,
    required this.variant,
    this.note,
  });

  final String figmaName;
  final String flutterMapping;
  final String variant;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return _LabExample(
      title: figmaName,
      flutterMapping: flutterMapping,
      variant: variant,
      state: 'not implemented',
      note: note,
      fullWidth: true,
      child: Text(
        'Placeholder: canonical component surface will be added here as V7 evolves.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
