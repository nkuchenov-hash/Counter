import 'package:flutter/material.dart';

enum AppButtonVariant {
  /// Solid primary button — main CTA.
  primary,

  /// Tonal / muted button — secondary action.
  secondary,

  /// Outlined button — tertiary action.
  outlined,

  /// Text-only / ghost action.
  ghost,

  /// Solid red button — destructive action (delete, archive, reset).
  destructive,
}

enum AppButtonSize {
  /// Small inline action.
  s,

  /// Default medium action.
  m,

  /// Large prominent action.
  l,
}

/// Standard app button. Use this in place of raw `FilledButton` / `OutlinedButton`
/// so spacing, icon size, and loading states stay consistent.
///
/// ```dart
/// AppButton.primary(label: 'Save', size: AppButtonSize.m, onPressed: _save)
/// AppButton.danger(label: 'Delete', icon: Icons.delete, onPressed: _del)
/// AppButton.secondary(label: 'Saving...', loading: true, onPressed: null)
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  });

  /// Convenience: primary CTA.
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.primary;

  /// Convenience: secondary (tonal) action.
  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.secondary;

  /// Convenience: outlined / tertiary action.
  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.outlined;

  /// Convenience: text / ghost action.
  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.ghost;

  /// Convenience: destructive (delete / archive) action.
  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.destructive;

  /// Convenience: danger action. Same Flutter behavior as [AppButton.destructive],
  /// matching Figma's "Button / Danger" naming.
  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.destructive;

  final String label;

  /// Pass `null` to disable. While [loading] is true, the button is also disabled.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;

  /// When true, swap the label/icon for an inline spinner. The button stays
  /// disabled while loading, regardless of [onPressed].
  final bool loading;

  /// When true, the button stretches to fill its parent's width.
  final bool expand;

  /// Preferred replacement for [expand]. When null, [expand] is honored for
  /// backwards compatibility.
  final bool? fullWidth;

  double get _height => switch (size) {
    AppButtonSize.s => 36,
    AppButtonSize.m => 44,
    AppButtonSize.l => 52,
  };

  EdgeInsetsGeometry get _padding => switch (size) {
    AppButtonSize.s => const EdgeInsets.symmetric(horizontal: 12),
    AppButtonSize.m => const EdgeInsets.symmetric(horizontal: 16),
    AppButtonSize.l => const EdgeInsets.symmetric(horizontal: 20),
  };

  double get _iconSize => switch (size) {
    AppButtonSize.s => 16,
    AppButtonSize.m => 18,
    AppButtonSize.l => 20,
  };

  TextStyle? _textStyle(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return switch (size) {
      AppButtonSize.s => textTheme.labelMedium,
      AppButtonSize.m => textTheme.labelLarge,
      AppButtonSize.l => textTheme.titleSmall,
    }?.copyWith(fontWeight: FontWeight.w700);
  }

  ButtonStyle _baseStyle(BuildContext context) {
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, _height)),
      padding: WidgetStatePropertyAll(_padding),
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textStyle: WidgetStatePropertyAll(_textStyle(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = loading || onPressed == null;
    final stretch = fullWidth ?? expand;
    final spinnerColor = switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.destructive => scheme.onError,
      AppButtonVariant.secondary ||
      AppButtonVariant.outlined ||
      AppButtonVariant.ghost => scheme.primary,
    };

    final child = loading
        ? SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          )
        : (icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: _iconSize),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                )
              : Text(label));

    final btn = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        style: _baseStyle(context),
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.secondary => FilledButton.tonal(
        style: _baseStyle(context),
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        style: _baseStyle(context),
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        style: _baseStyle(context),
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.destructive => FilledButton(
        style: _baseStyle(context).merge(
          FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
            disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
    };

    return stretch ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
