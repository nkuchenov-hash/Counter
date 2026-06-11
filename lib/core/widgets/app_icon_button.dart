import 'package:flutter/material.dart';

enum AppIconButtonVariant {
  /// Default icon action on a transparent surface.
  standard,

  /// Low-emphasis / ghost icon action.
  subtle,

  /// Tonal filled icon action.
  filled,

  /// Destructive icon action.
  danger,
}

enum AppIconButtonSize {
  /// Small inline icon action.
  s,

  /// Default medium icon action.
  m,

  /// Large prominent icon action.
  l,
}

/// Canonical app icon-only action.
///
/// Use this for app-owned icon actions instead of raw `IconButton` once a
/// surface is migrated. Text/action buttons remain `AppButton`.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppIconButtonVariant.standard,
    this.size = AppIconButtonSize.m,
    this.selected = false,
    this.loading = false,
  });

  final IconData icon;

  /// Required for accessibility and tooltips on icon-only actions.
  final String tooltip;

  /// Pass `null` to disable. While [loading] is true, the button is also
  /// disabled.
  final VoidCallback? onPressed;

  final AppIconButtonVariant variant;
  final AppIconButtonSize size;
  final bool selected;
  final bool loading;

  double get _iconSize => switch (size) {
    AppIconButtonSize.s => 18,
    AppIconButtonSize.m => 20,
    AppIconButtonSize.l => 24,
  };

  double get _visualSize => switch (size) {
    AppIconButtonSize.s => 36,
    AppIconButtonSize.m => 44,
    AppIconButtonSize.l => 52,
  };

  Size get _minimumSize => switch (size) {
    AppIconButtonSize.s => const Size(40, 40),
    AppIconButtonSize.m => const Size(48, 48),
    AppIconButtonSize.l => const Size(56, 56),
  };

  ButtonStyle _style(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);

    Color? background(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return null;
      if (states.contains(WidgetState.selected) || selected) {
        return switch (variant) {
          AppIconButtonVariant.danger => scheme.errorContainer,
          _ => scheme.primaryContainer,
        };
      }
      return switch (variant) {
        AppIconButtonVariant.standard || AppIconButtonVariant.subtle => null,
        AppIconButtonVariant.filled => scheme.secondaryContainer,
        AppIconButtonVariant.danger => null,
      };
    }

    Color foreground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return scheme.onSurface.withValues(alpha: 0.38);
      }
      if (states.contains(WidgetState.selected) || selected) {
        return switch (variant) {
          AppIconButtonVariant.danger => scheme.onErrorContainer,
          _ => scheme.onPrimaryContainer,
        };
      }
      return switch (variant) {
        AppIconButtonVariant.standard => scheme.onSurfaceVariant,
        AppIconButtonVariant.subtle => scheme.onSurfaceVariant.withValues(
          alpha: 0.82,
        ),
        AppIconButtonVariant.filled => scheme.onSecondaryContainer,
        AppIconButtonVariant.danger => scheme.error,
      };
    }

    Color overlay(Set<WidgetState> states) {
      final base = foreground(states);
      if (states.contains(WidgetState.pressed)) {
        return base.withValues(alpha: 0.14);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return base.withValues(alpha: 0.10);
      }
      return Colors.transparent;
    }

    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(background),
      foregroundColor: WidgetStateProperty.resolveWith(foreground),
      overlayColor: WidgetStateProperty.resolveWith(overlay),
      iconColor: WidgetStateProperty.resolveWith(foreground),
      minimumSize: WidgetStatePropertyAll(_minimumSize),
      fixedSize: WidgetStatePropertyAll(Size.square(_visualSize)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;
    final scheme = Theme.of(context).colorScheme;
    final iconWidget = loading
        ? SizedBox.square(
            dimension: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          )
        : Icon(icon, size: _iconSize);

    return Semantics(
      label: tooltip,
      button: true,
      selected: selected,
      enabled: effectiveOnPressed != null,
      child: IconButton(
        tooltip: tooltip,
        style: _style(context),
        iconSize: _iconSize,
        isSelected: selected,
        onPressed: effectiveOnPressed,
        icon: iconWidget,
      ),
    );
  }
}
