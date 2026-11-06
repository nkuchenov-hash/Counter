import 'dart:ui' as ui;

import 'package:counter/core/app_control_tokens.dart';
import 'package:flutter/material.dart';

/// Canonical single-line text/search input for Life OS.
///
/// This is the only standard one-line input surface allowed in feature UI.
/// Variants are parameters; feature screens must not recreate border, height,
/// radius, fill, padding, typography, hover, or focus styling locally.
enum AppTextFieldSurface { standard, glass }

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    this.showSearchIcon = false,
    this.surface = AppTextFieldSurface.standard,
  });

  static const double height = AppControlTokens.height;
  static const double radius = AppControlTokens.radius;

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final bool showSearchIcon;
  final AppTextFieldSurface surface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final meta = dark
        ? scheme.onSurfaceVariant.withValues(alpha: 0.92)
        : scheme.onSurfaceVariant;
    final fill = scheme.surfaceContainerHighest;
    final borderColor = scheme.outline;

    final glass = surface == AppTextFieldSurface.glass;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      textAlignVertical: TextAlignVertical.center,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontSize: AppControlTokens.fontSize,
        color: scheme.onSurface,
        height: 1.2,
      ),
      decoration: InputDecoration(
        constraints: const BoxConstraints.tightFor(height: height),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintText: hintText,
        hintStyle: TextStyle(fontSize: AppControlTokens.fontSize, color: meta),
        prefixIcon: showSearchIcon
            ? Icon(Icons.search_rounded, size: 18, color: meta)
            : null,
        prefixIconConstraints: showSearchIcon
            ? const BoxConstraints(minWidth: 40, minHeight: height)
            : null,
        suffixIcon: suffixIcon,
        suffixIconConstraints: suffixIcon != null
            ? const BoxConstraints.tightFor(width: height, height: height)
            : null,
        filled: true,
        fillColor: glass
            ? scheme.surface.withValues(alpha: dark ? 0.28 : 0.20)
            : fill,
        isDense: true,
        contentPadding: EdgeInsets.fromLTRB(
          showSearchIcon ? 0 : AppControlTokens.horizontalPadding,
          10,
          AppControlTokens.horizontalPadding,
          10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: glass
                ? scheme.onSurface.withValues(alpha: dark ? 0.12 : 0.08)
                : borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: dark ? 0.72 : 0.34),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: glass
                ? scheme.onSurface.withValues(alpha: dark ? 0.12 : 0.08)
                : borderColor,
          ),
        ),
      ),
    );

    final child = SizedBox(height: height, child: field);
    if (!glass) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: child,
      ),
    );
  }
}
