import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

const double kAppCompactControlHeight = 44;
const double kAppQuickEntryControlHeight = AppTextField.height;
const double kAppCompactControlFontSize = 12;

ButtonStyle appCompactSegmentedButtonStyle(
  BuildContext context, {
  double segmentWidth = 84,
}) {
  return SegmentedButton.styleFrom(
    selectedBackgroundColor: Theme.of(context).colorScheme.primary,
    selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
    side: BorderSide(color: Theme.of(context).colorScheme.outline),
    fixedSize: Size(segmentWidth, kAppCompactControlHeight),
    tapTargetSize: MaterialTapTargetSize.padded,
    padding: EdgeInsets.zero,
    textStyle: TextStyle(
      fontSize: kAppCompactControlFontSize,
      fontWeight: FontWeight.w600,
      height: 1.1,
    ),
    visualDensity: VisualDensity.compact,
  );
}

class AppCompactSegmentLabel extends StatelessWidget {
  const AppCompactSegmentLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style;
    final style = inherited.copyWith(
      fontSize: kAppCompactControlFontSize,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );
    return SizedBox(
      height: kAppCompactControlHeight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
            style: style,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
          ),
        ),
      ),
    );
  }
}

class AppCompactTextTab extends StatelessWidget {
  const AppCompactTextTab({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style;
    final style = inherited.copyWith(
      fontSize: kAppCompactControlFontSize,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );
    return SizedBox(
      height: kAppCompactControlHeight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
            style: style,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
          ),
        ),
      ),
    );
  }
}

/// Canonical one-line heading row for desktop primary sections.
///
/// Feature-owned controls live on the same line as the section name; the shell
/// must not add a second copy of the title above this row. Keep this chrome to
/// one visual line; section-specific content starts below it.
class AppDesktopSectionControlRow extends StatelessWidget {
  const AppDesktopSectionControlRow({
    super.key,
    required this.title,
    required this.controls,
  });

  final String title;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kShellDesktopContentHorizontalPadding,
        kShellDesktopContentTopPadding,
        kShellDesktopContentHorizontalPadding,
        6,
      ),
      child: SizedBox(
        height: kAppCompactControlHeight,
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 20),
            const Spacer(),
            controls,
          ],
        ),
      ),
    );
  }
}

/// Canonical quick-entry line shared by desktop Planning and Timeline.
/// The field is the same component as Notes; field and action share height and radius.
class AppQuickEntryRow extends StatelessWidget {
  const AppQuickEntryRow({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.onSubmitted,
    this.loading = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final ValueChanged<String>? onSubmitted;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: controller,
            focusNode: focusNode,
            hintText: hintText,
            textInputAction: TextInputAction.done,
            showSearchIcon: false,
            onSubmitted: onSubmitted,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: kAppQuickEntryControlHeight,
          child: AppButton.primary(
            label: actionLabel,
            icon: actionIcon,
            onPressed: onAction,
            loading: loading,
            size: AppButtonSize.m,
          ),
        ),
      ],
    );
  }
}
