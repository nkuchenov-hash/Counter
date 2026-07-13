// One-off GLM parity screenshot capture — run with:
// flutter run -d windows -t lib/features/notes/debug/capture_notes_glm_main.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:counter/features/notes/debug/notes_glm_parity_fixture.dart';
import 'package:counter/features/notes/debug/notes_production_library_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

final _editorKey = GlobalKey();
final _libraryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _captureWidget(
    key: _editorKey,
    child: const NotesGlmParityFixture(),
    path: 'test/fixtures/notes_glm_production_editor_capture.png',
    size: kNotesGlmParityViewport,
  );

  await _captureWidget(
    key: _libraryKey,
    child: const NotesProductionLibraryCapture(),
    path: 'test/fixtures/notes_glm_production_library_capture.png',
    size: kNotesGlmParityViewport,
  );

  exit(0);
}

Future<void> _captureWidget({
  required GlobalKey key,
  required Widget child,
  required String path,
  required Size size,
}) async {
  final done = Completer<void>();
  runApp(
    MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      stderr.writeln('Missing RepaintBoundary for $path');
      exit(1);
    }
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      stderr.writeln('Failed to encode $path');
      exit(1);
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    stdout.writeln('Wrote $path');
    if (!done.isCompleted) {
      done.complete();
    }
  });
  await done.future;
}
