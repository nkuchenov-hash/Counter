// showConfirmDialog — single source of truth for yes/no confirms.
// Replaces 8+ inline `AlertDialog` confirms scattered across the codebase.
// Tier 1 / ROADMAP April 2026.

import 'package:flutter/material.dart';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/l10n/dictionary.dart';

/// Show a standard confirmation dialog. Returns `true` if the user confirms,
/// `false` if they cancel, `null` if dismissed (tap outside / back button).
///
/// Use this for any binary confirm. For destructive actions (delete, archive,
/// reset) pass `destructive: true` so the confirm button uses the error color.
///
/// ```dart
/// final ok = await showConfirmDialog(
///   context,
///   title: 'Delete plan?',
///   body: 'This cannot be undone.',
///   destructive: true,
/// );
/// if (ok == true) { ... }
/// ```
///
/// `confirmText` and `cancelText` accept localized strings; pass `null` to use
/// the app's standard "OK" / "Cancel" labels (read from the active locale).
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  String? confirmText,
  String? cancelText,
  bool destructive = false,
  bool barrierDismissible = true,
}) {
  final loc = currentLocale.value;
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          AppButton.ghost(
            label: cancelText ?? t(loc, 'cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: confirmText ?? t(loc, 'confirm'),
            variant: destructive
                ? AppButtonVariant.destructive
                : AppButtonVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      );
    },
  );
}
