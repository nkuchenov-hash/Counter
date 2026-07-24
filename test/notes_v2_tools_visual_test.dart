import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notes/fixtures/notes_v2_tools_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the production Notes v2 tools system', (tester) async {
    await _loadCaptureFonts();

    tester.view.physicalSize = kNotesV2ToolsViewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'NotesCaptureSans',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        ),
        home: const Scaffold(body: NotesV2ToolsFixture()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(kNotesV2ToolsCaptureKey), findsOneWidget);
    expect(find.text('Aa · text and block formatting'), findsOneWidget);
    expect(find.text('+ · insert blocks'), findsOneWidget);
    expect(find.text('Active table · contextual editing'), findsOneWidget);

    await expectLater(
      find.byKey(kNotesV2ToolsCaptureKey),
      matchesGoldenFile('fixtures/notes_v2_tools_capture.png'),
    );
  });
}

Future<void> _loadCaptureFonts() async {
  final textFile = _firstExisting(<String>[
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
  ]);
  final boldFile = _firstExisting(<String>[
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    '/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf',
  ]);
  if (textFile == null) {
    throw StateError('No deterministic capture text font found');
  }

  final textLoader = FontLoader('NotesCaptureSans')
    ..addFont(_fontBytes(textFile));
  if (boldFile != null) textLoader.addFont(_fontBytes(boldFile));
  await textLoader.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    throw StateError('FLUTTER_ROOT is required for Material Icons capture');
  }
  final iconFile = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!iconFile.existsSync()) {
    throw StateError('Material Icons font not found at ${iconFile.path}');
  }
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(_fontBytes(iconFile));
  await iconLoader.load();
}

File? _firstExisting(List<String> paths) {
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

Future<ByteData> _fontBytes(File file) async {
  final bytes = await file.readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}
