// AppButton — single source of truth for primary / secondary / destructive
// buttons. Wraps Material's FilledButton / OutlinedButton / FilledButton.tonal
// with consistent styling, icon support, and a `loading` state that shows
// AppLoading inside the button instead of the label.
// Tier 1 / ROADMAP April 2026.

import 'package:flutter/material.dart';

import 'app_loading.dart';

enum AppButtonVariant {
  /// Solid primary button — main CTA.
  primary,

  /// Tonal / muted button — secondary action.
  secondary,

  /// Outlined button — tertiary action.
  outlined,

  /// Solid red button — destructive action (delete, archive, reset).
  destructive,
}

/// Standard app button. Use this in place of raw `FilledButton` / `OutlinedButton`
/// so spacing, icon size, and loading states stay consistent.
///
/// ```dart
/// AppButton.primary(label: 'Save', onPressed: _save)
/// AppButton.destructive(label: 'Delete', icon: Icons.delete, onPressed: _del)
/// AppButton.secondary(label: 'Saving…', loading: true, onPressed: null)
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  /// Convenience: primary CTA.
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.primary;

  /// Convenience: secondary (tonal) action.
  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.secondary;

  /// Convenience: outlined / tertiary action.
  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.outlined;

  /// Convenience: destructive (delete / archive) action.
  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.destructive;

  final String label;

  /// Pass `null` to disable. While [loading] is true, the button is also disabled.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final IconData? icon;

  /// When true, swap the label/icon for an inline spinner. The button stays
  /// disabled while loading, regardless of [onPressed].
  final bool loading;

  /// When true, the button stretches to fill its parent's width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = loading || onPressed == null;

    final child = loading
        ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: AppLoading(size: AppLoadingSize.small),
          )
        : (icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              )
            : Text(label));

    final btn = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.secondary => FilledButton.tonal(
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.destructive => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
    };

    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
