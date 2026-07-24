// Temporary real-runtime capture for Notes v2 tool panels.
// Run with: flutter run -d windows -t scripts/manual/capture_notes_v2_tools_main.dart --release

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:window_manager/window_manager.dart';

import '../../test/notes/fixtures/notes_v2_tools_fixture.dart';

final _captureKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final options = WindowOptions(
    size: Size(
      kNotesV2ToolsViewport.width + 24,
      kNotesV2ToolsViewport.height + 48,
    ),
    minimumSize: Size(
      kNotesV2ToolsViewport.width + 24,
      kNotesV2ToolsViewport.height + 48,
    ),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
  );

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: _captureKey,
          child: const NotesV2ToolsFixture(),
        ),
      ),
    ),
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 900));
  await WidgetsBinding.instance.endOfFrame;

  final boundary =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    stderr.writeln('Missing Notes v2 capture boundary');
    exit(1);
  }
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    stderr.writeln('Failed to encode Notes v2 capture');
    exit(1);
  }
  final file = File('test/fixtures/notes_v2_tools_capture.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(byteData.buffer.asUint8List());
  stdout.writeln('Wrote ${file.path} (${image.width}x${image.height})');
  await windowManager.close();
  exit(0);
}
