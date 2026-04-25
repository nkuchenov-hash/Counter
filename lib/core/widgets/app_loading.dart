// AppLoading — single source of truth for circular loading indicators.
// Replaces 17+ inline `CircularProgressIndicator` calls with drifting strokeWidth.
// Tier 1 / ROADMAP April 2026.

import 'package:flutter/material.dart';

/// Standard sizes for the app's loading indicator.
enum AppLoadingSize {
  /// Inline / button-sized spinner. ~16px box, 2px stroke.
  small,

  /// Default page / sheet spinner. ~28px box, 3px stroke.
  medium,

  /// Hero / full-screen spinner. ~44px box, 4px stroke.
  large,
}

/// Shared circular loading indicator. Always wraps in a `Center`.
///
/// Use this instead of `CircularProgressIndicator` directly so spacing,
/// stroke width, and color stay consistent across the app.
///
/// ```dart
/// // before:
/// const Center(child: CircularProgressIndicator(strokeWidth: 2))
/// // after:
/// const AppLoading(size: AppLoadingSize.small)
/// ```
class AppLoading extends StatelessWidget {
  const AppLoading({
    super.key,
    this.size = AppLoadingSize.medium,
    this.color,
  });

  final AppLoadingSize size;

  /// Override the spinner color. Defaults to `colorScheme.primary`.
  final Color? color;

  double get _box => switch (size) {
        AppLoadingSize.small => 16,
        AppLoadingSize.medium => 28,
        AppLoadingSize.large => 44,
      };

  double get _stroke => switch (size) {
        AppLoadingSize.small => 2,
        AppLoadingSize.medium => 3,
        AppLoadingSize.large => 4,
      };

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Center(
      child: SizedBox(
        width: _box,
        height: _box,
        child: CircularProgressIndicator(
          strokeWidth: _stroke,
          valueColor: AlwaysStoppedAnimation<Color>(c),
        ),
      ),
    );
  }
}
