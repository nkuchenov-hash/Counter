import 'package:counter/core/app_snackbar.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

  Future<void> exportVisibleListAsText({
  required BuildContext context,
  required String locale,
  required List<PlanningTask> visible,
}) async {
    
    if (visible.isEmpty) {
      AppSnack.show(t(locale, 'lists_export_empty'), error: true);
      return;
    }
    final lines = <String>[];
    for (var i = 0; i < visible.length; i++) {
      lines.add('${i + 1}. ${visible[i].title.trim()}');
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    AppSnack.show(t(locale, 'lists_export_copied'));
  }

