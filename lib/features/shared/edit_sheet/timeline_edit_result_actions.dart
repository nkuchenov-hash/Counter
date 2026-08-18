import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

abstract final class TimelineEditResultActions {
  static Future<void> deletePersisted(
    BuildContext context,
    String recordId,
  ) async {
    final ok = await DatabaseService.instance.deleteRecordByDocId(recordId);
    if (!context.mounted || ok) return;

    final messenger = ScaffoldMessenger.of(context);
    final loc = currentLocale.value;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(t(loc, 'sync_failed_retry')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: t(loc, 'try_again'),
          onPressed: () => unawaited(deletePersisted(context, recordId)),
        ),
      ),
    );
  }

  static Future<void> stopPersisted(String recordId) async {
    await DatabaseService.instance.stopRecordByDocId(recordId);
  }
}
