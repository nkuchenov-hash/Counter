import 'package:flutter/material.dart';

const double kAppCompactControlHeight = 44;
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
    textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
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
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
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
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
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
