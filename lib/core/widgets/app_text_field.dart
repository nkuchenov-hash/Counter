import 'dart:ui' as ui;

import 'package:counter/core/app_control_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single canonical input element. Search, passwords, numeric/email input,
/// validation and multi-line editors are variants, not feature-local controls.
enum AppTextFieldVariant { text, search, email, number, password, multiline }

enum AppTextFieldSurface { standard, glass }

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = '',
    this.labelText,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.suffixIcon,
    this.showSearchIcon = false,
    this.variant = AppTextFieldVariant.text,
    this.surface = AppTextFieldSurface.standard,
    this.obscureText,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.autocorrect = true,
    this.autofillHints,
    this.inputFormatters,
    this.minLines,
    this.maxLines,
    this.validator,
  });

  static const double height = AppControlTokens.height;
  static const double radius = AppControlTokens.radius;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final String? labelText;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final bool showSearchIcon;
  final AppTextFieldVariant variant;
  final AppTextFieldSurface surface;
  final bool? obscureText;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final bool autocorrect;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int? maxLines;
  final String? Function(String?)? validator;

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
    final search = showSearchIcon || variant == AppTextFieldVariant.search;
    final multiline = variant == AppTextFieldVariant.multiline;
    final hidden = obscureText ?? (variant == AppTextFieldVariant.password);
    final lines = hidden ? 1 : (maxLines ?? (multiline ? 6 : 1));
    final minVisibleLines = hidden ? null : (minLines ?? (multiline ? 3 : null));
    final action = textInputAction ??
        (multiline ? TextInputAction.newline : TextInputAction.done);
    final type = keyboardType ??
        switch (variant) {
          AppTextFieldVariant.email => TextInputType.emailAddress,
          AppTextFieldVariant.number => TextInputType.number,
          AppTextFieldVariant.multiline => TextInputType.multiline,
          _ => TextInputType.text,
        };
    final decoration = InputDecoration(
      constraints: multiline || validator != null
          ? null
          : const BoxConstraints.tightFor(height: height),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      hintText: hintText,
      hintStyle: TextStyle(fontSize: AppControlTokens.fontSize, color: meta),
      prefixIcon: search ? Icon(Icons.search_rounded, size: 18, color: meta) : null,
      prefixIconConstraints: search
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
        search ? 0 : AppControlTokens.horizontalPadding,
        multiline ? 12 : 10,
        AppControlTokens.horizontalPadding,
        multiline ? 12 : 10,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(
          color: glass
              ? scheme.onSurface.withValues(alpha: dark ? 0.12 : 0.08)
              : borderColor,
        ),
      ),
    );

    final style = TextStyle(
      fontSize: AppControlTokens.fontSize,
      color: scheme.onSurface,
      height: 1.2,
    );
    final Widget field = validator == null
        ? TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: type,
            obscureText: hidden,
            autofocus: autofocus,
            enabled: enabled,
            readOnly: readOnly,
            autocorrect: autocorrect,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            minLines: minVisibleLines,
            maxLines: lines,
            textInputAction: action,
            textCapitalization: textCapitalization,
            textAlignVertical: TextAlignVertical.center,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onEditingComplete: onEditingComplete,
            onTap: onTap,
            style: style,
            decoration: decoration,
          )
        : TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: type,
            obscureText: hidden,
            autofocus: autofocus,
            enabled: enabled,
            readOnly: readOnly,
            autocorrect: autocorrect,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            minLines: minVisibleLines,
            maxLines: lines,
            textInputAction: action,
            textCapitalization: textCapitalization,
            textAlignVertical: TextAlignVertical.center,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            onEditingComplete: onEditingComplete,
            onTap: onTap,
            validator: validator,
            style: style,
            decoration: decoration,
          );

    Widget control = multiline || validator != null
        ? field
        : SizedBox(height: height, child: field);
    if (glass) {
      control = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: control,
        ),
      );
    }
    final label = labelText;
    if (label == null || label.isEmpty) return control;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        control,
      ],
    );
  }
}
