import 'dart:ui' as ui;

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

  static const double height = 42;
  static const double radius = 18;

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
        : const Color(0xFF6B7280);
    final fill = dark
        ? scheme.surfaceContainerHigh.withValues(alpha: 0.82)
        : const Color(0xFFF7F8FA).withValues(alpha: 0.78);
    final borderColor = dark
        ? scheme.outlineVariant.withValues(alpha: 0.78)
        : const Color(0xFFDFE3E8).withValues(alpha: 0.76);

    final glass = surface == AppTextFieldSurface.glass;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      textAlignVertical: TextAlignVertical.center,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
      decoration: InputDecoration(
        constraints: const BoxConstraints.tightFor(height: height),
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 13.5, color: meta),
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
          showSearchIcon ? 0 : 13,
          11,
          13,
          11,
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
