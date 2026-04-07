import 'package:flutter/material.dart';
import 'package:wear/wear.dart';

/// Wraps the app on Wear: uses [WatchShape] and insets on **round** displays.
class WearMainWrapper extends StatelessWidget {
  const WearMainWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WatchShape(
      builder: (context, shape, _) {
        final pad = shape == WearShape.round
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : EdgeInsets.zero;
        return Padding(padding: pad, child: child);
      },
    );
  }
}
