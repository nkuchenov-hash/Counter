import 'package:counter/core/widgets/app_button.dart';
import 'package:flutter/material.dart';

const double kAppCompactControlHeight = 44;
const double kAppQuickEntryControlHeight = 40;
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
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
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

/// Canonical input surface shared with the Notes library.
///
/// This is the Notes quick-add/search field promoted to core so Planning,
/// Timeline and Notes cannot drift to different input geometry or surfaces.
class AppLibraryInput extends StatefulWidget {
  const AppLibraryInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    this.showSearchIcon = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final bool showSearchIcon;

  @override
  State<AppLibraryInput> createState() => _AppLibraryInputState();
}

class _AppLibraryInputState extends State<AppLibraryInput> {
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant AppLibraryInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode.removeListener(_handleFocusChanged);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final meta = dark
        ? scheme.onSurfaceVariant.withValues(alpha: 0.92)
        : const Color(0xFF94A3B8);
    final normalFill = dark
        ? scheme.surfaceContainerHigh.withValues(alpha: 0.82)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.82);
    final hoverFill = dark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.92)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.96);
    final normalBorder = dark
        ? scheme.outlineVariant.withValues(alpha: 0.82)
        : const Color(0xFFD9E0EA);
    final focusBorder = scheme.primary.withValues(alpha: dark ? 0.86 : 0.62);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        height: kAppQuickEntryControlHeight,
        decoration: BoxDecoration(
          color: _hovered ? hoverFill : normalFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.focusNode.hasFocus ? focusBorder : normalBorder,
            width: widget.focusNode.hasFocus && dark ? 1.2 : 1,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          textAlignVertical: TextAlignVertical.center,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: TextStyle(fontSize: 14, color: scheme.onSurface),
          decoration: InputDecoration(
            constraints: const BoxConstraints.tightFor(
              height: kAppQuickEntryControlHeight,
            ),
            hintText: widget.hintText,
            hintStyle: TextStyle(fontSize: 14, color: meta),
            prefixIcon: widget.showSearchIcon
                ? Icon(Icons.search_rounded, size: 18, color: meta)
                : const SizedBox.shrink(),
            prefixIconConstraints: BoxConstraints.tightFor(
              width: widget.showSearchIcon ? kAppQuickEntryControlHeight : 0,
              height: kAppQuickEntryControlHeight,
            ),
            suffixIcon: widget.suffixIcon,
            suffixIconConstraints: widget.suffixIcon != null
                ? const BoxConstraints.tightFor(
                    width: kAppQuickEntryControlHeight,
                    height: kAppQuickEntryControlHeight,
                  )
                : null,
            isDense: true,
            filled: false,
            hoverColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
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
          child: AppLibraryInput(
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
