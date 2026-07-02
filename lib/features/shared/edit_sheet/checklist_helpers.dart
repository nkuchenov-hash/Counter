import 'package:flutter/material.dart';// --- Checklist editors (_PlanningTaskEditSheet + _TimelineRecordSheetContent) ---
void syncChecklistDoneLength(
  List<TextEditingController> controllers,
  List<bool> done,
) {
  while (done.length < controllers.length) {
    done.add(false);
  }
  if (done.length > controllers.length) {
    done.removeRange(controllers.length, done.length);
  }
}

/// Unchecked rows first (stable order), then checked (stable order). Mutates lists in place.
void partitionChecklistRowsByDone({
  required List<TextEditingController> controllers,
  required List<bool> done,
}) {
  if (controllers.isEmpty) return;
  syncChecklistDoneLength(controllers, done);
  final n = controllers.length;
  final order = List<int>.generate(n, (i) => i);
  order.sort((a, b) {
    final da = done[a] ? 1 : 0;
    final db = done[b] ? 1 : 0;
    if (da != db) return da.compareTo(db);
    return a.compareTo(b);
  });
  var identity = true;
  for (var k = 0; k < n; k++) {
    if (order[k] != k) {
      identity = false;
      break;
    }
  }
  if (identity) return;
  final newControllers = order.map(controllers.elementAt).toList();
  final newDone = order.map(done.elementAt).toList();
  controllers
    ..clear()
    ..addAll(newControllers);
  done
    ..clear()
    ..addAll(newDone);
}

void removeChecklistRowAt(
  int index, {
  required List<TextEditingController> controllers,
  required List<bool> done,
}) {
  if (index < 0 || index >= controllers.length) return;
  controllers[index].dispose();
  controllers.removeAt(index);
  if (index < done.length) {
    done.removeAt(index);
  }
  syncChecklistDoneLength(controllers, done);
  if (controllers.isEmpty) {
    controllers.add(TextEditingController());
    done
      ..clear()
      ..add(false);
  }
}

// ---------------------------------------------------------------------------
// Empty states — first-run / empty collection (grayscale, minimal).
// ---------------------------------------------------------------------------

