// ---------------------------------------------------------------------------
// Global SnackBar helper — root [ScaffoldMessenger] (@MaterialApp.scaffoldMessengerKey).
// ---------------------------------------------------------------------------

import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> appSnackMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Brief feedback after DB mutations (success = green, error = red).
class AppSnack {
  AppSnack._();

  static void show(
    String message, {
    bool error = false,
  }) {
    final messenger = appSnackMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              error ? Colors.red.shade800 : Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  static void saved() =>
      show(t(currentLocale.value, 'toast_saved'), error: false);

  static void deleted() =>
      show(t(currentLocale.value, 'toast_deleted'), error: false);

  static void updated() =>
      show(t(currentLocale.value, 'toast_updated'), error: false);

  static void failed() =>
      show(t(currentLocale.value, 'toast_error'), error: true);

  static void warning(String message) {
    final messenger = appSnackMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange.shade900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }
}
