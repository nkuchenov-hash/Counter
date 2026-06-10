import 'package:flutter/material.dart';

const double kAppCompactControlHeight = 44;

ButtonStyle appCompactSegmentedButtonStyle(
  BuildContext context, {
  double segmentWidth = 84,
}) {
  return SegmentedButton.styleFrom(
    fixedSize: Size(segmentWidth, kAppCompactControlHeight),
    tapTargetSize: MaterialTapTargetSize.padded,
    textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    visualDensity: VisualDensity.compact,
  );
}

class AppCompactTextTab extends StatelessWidget {
  const AppCompactTextTab({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: kAppCompactControlHeight,
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1)),
    );
  }
}
