import 'dart:ui' show ImageFilter;

import 'package:counter/core/app_control_tokens.dart';
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

  /// Clipped, translucent circular control; blur never escapes its bounds.
  frosted,
}

enum AppIconButtonShape { rounded, circular }

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
    this.shape = AppIconButtonShape.rounded,
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
  final AppIconButtonShape shape;
  final bool selected;
  final bool loading;

  double get _iconSize => switch (size) {
    AppIconButtonSize.s => 18,
    AppIconButtonSize.m => 20,
    AppIconButtonSize.l => 24,
  };

  double get _visualSize => switch (size) {
    AppIconButtonSize.s => AppControlTokens.smallHeight,
    AppIconButtonSize.m => AppControlTokens.height,
    AppIconButtonSize.l => AppControlTokens.largeHeight,
  };

  Size get _minimumSize => switch (size) {
    AppIconButtonSize.s => const Size.square(AppControlTokens.smallHeight),
    AppIconButtonSize.m => const Size.square(AppControlTokens.height),
    AppIconButtonSize.l => const Size.square(AppControlTokens.largeHeight),
  };

  ButtonStyle _style(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppControlTokens.radius);

    Color? background(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return null;
      if (states.contains(WidgetState.selected) || selected) {
        return switch (variant) {
          AppIconButtonVariant.danger => scheme.errorContainer,
          AppIconButtonVariant.frosted => null,
          _ => scheme.primary,
        };
      }
      return switch (variant) {
        AppIconButtonVariant.standard || AppIconButtonVariant.subtle => null,
        AppIconButtonVariant.filled => scheme.secondaryContainer,
        AppIconButtonVariant.danger || AppIconButtonVariant.frosted => null,
      };
    }

    Color foreground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return scheme.onSurface.withValues(alpha: 0.38);
      }
      if (states.contains(WidgetState.selected) || selected) {
        return switch (variant) {
          AppIconButtonVariant.danger => scheme.onErrorContainer,
          _ => scheme.onPrimary,
        };
      }
      return switch (variant) {
        AppIconButtonVariant.standard => scheme.onSurfaceVariant,
        AppIconButtonVariant.subtle => scheme.onSurfaceVariant.withValues(
          alpha: 0.82,
        ),
        AppIconButtonVariant.filled => scheme.onSecondaryContainer,
        AppIconButtonVariant.danger => scheme.error,
        AppIconButtonVariant.frosted => scheme.onSurface,
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
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStatePropertyAll(
        shape == AppIconButtonShape.circular || variant == AppIconButtonVariant.frosted
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: radius),
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

    final button = IconButton(
      tooltip: tooltip,
      style: _style(context),
      iconSize: _iconSize,
      isSelected: selected,
      onPressed: effectiveOnPressed,
      icon: iconWidget,
    );
    // A local shadow/glint previously produced an oversized halo around
    // Settings Back. A clipped backdrop is the complete glass boundary;
    // no blur, shadow or gradient may paint outside the 48dp circle.
    final Widget painted = variant == AppIconButtonVariant.frosted
        ? ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.onSurface.withValues(
                    alpha: scheme.brightness == Brightness.dark ? 0.19 : 0.06,
                  ),
                  border: Border.all(
                    color: scheme.onSurface.withValues(
                      alpha: scheme.brightness == Brightness.dark ? 0.42 : 0.18,
                    ),
                    width: 1,
                  ),
                ),
                child: button,
              ),
            ),
          )
        : button;
    return Semantics(
      label: tooltip,
      button: true,
      selected: selected,
      enabled: effectiveOnPressed != null,
      child: painted,
    );
  }
}
