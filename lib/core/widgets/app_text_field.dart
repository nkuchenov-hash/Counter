import 'dart:ui' as ui;

import 'package:counter/core/app_control_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ONE canonical input widget. Every app-owned text/search/form editor uses
/// this surface with a variant rather than defining feature-local decoration.
/// Rich document editors (for example Quill) are not ordinary form inputs.
enum AppTextFieldVariant { text, search, password, multiline, number }
enum AppTextFieldSurface { standard, glass }

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = '',
    this.textInputAction = TextInputAction.done,
    this.variant = AppTextFieldVariant.text,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onSaved,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
    this.showSearchIcon = false,
    this.clearable = false,
    this.clearTooltip,
    this.surface = AppTextFieldSurface.standard,
    this.labelText,
    this.keyboardType,
    this.inputFormatters,
    this.autofillHints,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.minLines,
    this.maxLines,
    this.textAlign = TextAlign.start,
  });

  static const double height = AppControlTokens.height;
  static const double radius = AppControlTokens.radius;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final String? labelText;
  final TextInputAction textInputAction;
  final AppTextFieldVariant variant;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final bool showSearchIcon;
  final bool clearable;
  final String? clearTooltip;
  final AppTextFieldSurface surface;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final bool? obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int? minLines;
  final int? maxLines;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final meta = dark
        ? scheme.onSurfaceVariant.withValues(alpha: 0.92)
        : scheme.onSurfaceVariant;
    final glass = surface == AppTextFieldSurface.glass;
    final multi = variant == AppTextFieldVariant.multiline ||
        (maxLines != null && maxLines != 1);
    final obscured = obscureText ?? (variant == AppTextFieldVariant.password);
    final lines = obscured ? 1 : (maxLines ?? (multi ? 4 : 1));
    final search = showSearchIcon || variant == AppTextFieldVariant.search;
    final flexibleHeight = multi || validator != null;
    final fieldKeyboard = keyboardType ??
        (variant == AppTextFieldVariant.number
            ? TextInputType.number
            : multi ? TextInputType.multiline : TextInputType.text);
    final textStyle = TextStyle(
      fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
      fontSize: AppControlTokens.fontSize,
      color: scheme.onSurface,
      height: 1.2,
    );

    Widget buildInput(Widget? trailing) {
      final decoration = InputDecoration(
        constraints: flexibleHeight
            ? const BoxConstraints(minHeight: height)
            : const BoxConstraints.tightFor(height: height),
        floatingLabelBehavior:
            labelText == null ? FloatingLabelBehavior.never : FloatingLabelBehavior.auto,
        labelText: labelText,
        hintText: hintText,
        hintStyle: TextStyle(fontSize: AppControlTokens.fontSize, color: meta),
        prefixIcon: prefixIcon ??
            (search ? Icon(Icons.search_rounded, size: 18, color: meta) : null),
        prefixIconConstraints: search && prefixIcon == null
            ? const BoxConstraints(minWidth: 40, minHeight: height)
            : null,
        suffixIcon: trailing,
        suffixIconConstraints: trailing != null
            ? const BoxConstraints(minWidth: height, minHeight: height)
            : null,
        filled: true,
        fillColor: glass
            ? scheme.surface.withValues(alpha: dark ? 0.28 : 0.20)
            : scheme.surfaceContainerHighest,
        isDense: true,
        contentPadding: EdgeInsets.fromLTRB(
          search && prefixIcon == null ? 0 : AppControlTokens.horizontalPadding,
          multi ? 12 : 10,
          trailing == null ? AppControlTokens.horizontalPadding : 0,
          multi ? 12 : 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: glass
                ? scheme.onSurface.withValues(alpha: dark ? 0.12 : 0.08)
                : scheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: dark ? 0.72 : 0.34),
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: scheme.outline.withValues(alpha: 0.42),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outline),
        ),
      );

      final field = validator == null && onSaved == null
          ? TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: textInputAction,
              textCapitalization: textCapitalization,
              textAlign: textAlign,
              textAlignVertical: multi ? TextAlignVertical.top : TextAlignVertical.center,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onEditingComplete: onEditingComplete,
              keyboardType: fieldKeyboard,
              inputFormatters: inputFormatters,
              autofillHints: autofillHints,
              autofocus: autofocus,
              enabled: enabled,
              readOnly: readOnly,
              obscureText: obscured,
              autocorrect: autocorrect && !obscured,
              enableSuggestions: enableSuggestions && !obscured,
              minLines: multi ? minLines : 1,
              maxLines: lines,
              style: textStyle,
              decoration: decoration,
            )
          : TextFormField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: textInputAction,
              textCapitalization: textCapitalization,
              textAlign: textAlign,
              textAlignVertical: multi ? TextAlignVertical.top : TextAlignVertical.center,
              onChanged: onChanged,
              onFieldSubmitted: onSubmitted,
              onEditingComplete: onEditingComplete,
              onSaved: onSaved,
              validator: validator,
              keyboardType: fieldKeyboard,
              inputFormatters: inputFormatters,
              autofillHints: autofillHints,
              autofocus: autofocus,
              enabled: enabled,
              readOnly: readOnly,
              obscureText: obscured,
              autocorrect: autocorrect && !obscured,
              enableSuggestions: enableSuggestions && !obscured,
              minLines: multi ? minLines : 1,
              maxLines: lines,
              style: textStyle,
              decoration: decoration,
            );
      final child = flexibleHeight ? field : SizedBox(height: height, child: field);
      if (!glass) return child;
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: child,
        ),
      );
    }

    if (!clearable || suffixIcon != null) return buildInput(suffixIcon);
    // Only the trailing icon rebuilds while typing. The editor, focus,
    // caret and the 48px surface remain stable across every keystroke.
    return buildInput(ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, textValue, _) => textValue.text.isEmpty
          ? const SizedBox(width: height, height: height)
          : IconButton(
              tooltip: clearTooltip ?? 'Clear',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: enabled
                  ? () {
                      controller.clear();
                      onChanged?.call('');
                    }
                  : null,
            ),
    ));
  }
}
