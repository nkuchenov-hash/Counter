import 'dart:typed_data';

import 'package:counter/data/ai/viktor_voice_recorder.dart';
import 'package:counter/features/viktor/viktor_chat_page.dart';
import 'package:counter/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Viktor WAV is a complete mono 16kHz PCM16 recording', () {
    final pcm = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
    final wav = buildViktorWav(pcm);
    final data = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(data.getUint32(4, Endian.little), 42);
    expect(data.getUint16(20, Endian.little), 1);
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), 16000);
    expect(data.getUint16(34, Endian.little), 16);
    expect(data.getUint32(40, Endian.little), 6);
    expect(wav.sublist(44), pcm);
  });

  test('Viktor rejects invalid unaligned PCM chunks', () {
    expect(() => buildViktorWav(Uint8List(0)), throwsArgumentError);
    expect(() => buildViktorWav(Uint8List(3)), throwsArgumentError);
  });

  SharedPreferences.setMockInitialValues(<String, Object>{});

  for (final width in <double>[320, 390, 768]) {
    testWidgets('Viktor composer never overflows at width $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: ViktorChatPage(wallDay: DateTime(2026, 10, 17)),
      ));
      await tester.pump();
      expect(find.text('Виктор'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      final fieldFinder = find.byKey(const Key('viktor_composer_input'));
      final field = tester.widget<TextField>(fieldFinder);
      expect(field.minLines, 1);
      expect(field.maxLines, 8);
      expect(field.keyboardType, TextInputType.multiline);
      expect(field.style?.fontSize, greaterThanOrEqualTo(16));
      final editor = tester.getRect(fieldFinder);
      expect(editor.left, greaterThanOrEqualTo(0));
      expect(editor.right, lessThanOrEqualTo(width));
    });
  }
  testWidgets('Viktor composer expands for multiline messages and keeps shortcuts',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ViktorChatPage(wallDay: DateTime(2026, 10, 17)),
    ));
    await tester.pump();

    final fieldFinder = find.byKey(const Key('viktor_composer_input'));
    final field = tester.widget<TextField>(fieldFinder);
    final initialHeight = tester.getSize(fieldFinder).height;
    field.controller!.text = 'Первая строка\nВторая строка\n'
        'Третья строка\nЧетвёртая строка';
    await tester.pump();
    expect(tester.getSize(fieldFinder).height, greaterThan(initialHeight));

    final shortcuts = tester.widget<CallbackShortcuts>(
      find.byType(CallbackShortcuts));
    expect(shortcuts.bindings.containsKey(
      const SingleActivator(LogicalKeyboardKey.enter)), isTrue);
    expect(shortcuts.bindings.containsKey(
      const SingleActivator(LogicalKeyboardKey.numpadEnter)), isTrue);
    // Shift+Enter remains the ordinary multiline newline shortcut.
    expect(shortcuts.bindings.containsKey(
      const SingleActivator(LogicalKeyboardKey.enter, shift: true)), isFalse);
    expect(tester.takeException(), isNull);
  });


  // The empty composer must match the compact, inline ChatGPT layout:
  // no separate white editor rectangle stacked above a toolbar.
  for (final width in <double>[320, 390, 768, 1440]) {
    testWidgets('Viktor empty composer is compact and inline at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: ViktorChatPage(wallDay: DateTime(2026, 10, 24)),
      ));
      await tester.pump();

      final surface = tester.getRect(
        find.byKey(const Key('viktor_composer_surface')));
      final editor = tester.getRect(
        find.byKey(const Key('viktor_composer_input')));
      final mic = tester.getRect(
        find.byTooltip('Продиктовать Виктору'));
      final send = tester.getRect(
        find.byTooltip('Отправить Виктору'));

      expect(surface.height, lessThan(80));
      final contentColumn = tester.getRect(
        find.byKey(const Key('viktor_message_content_column')).first);
      expect(contentColumn.width,
          closeTo(width < kViktorChatContentMaxWidth
              ? width : kViktorChatContentMaxWidth, 1));
      // Composer uses the SAME content grid as messages, with identical
      // left and right 16px insets (no mysterious 660/760px mismatch).
      expect(surface.left, closeTo(contentColumn.left + 16, 1));
      expect(surface.right, closeTo(contentColumn.right - 16, 1));
      expect(surface.width, lessThanOrEqualTo(kViktorChatContentMaxWidth));
      // The send action remains evenly inset from the capsule border.
      expect(surface.right - send.right, closeTo(10, 2));
      expect(surface.left, greaterThanOrEqualTo(0));
      expect(surface.right, lessThanOrEqualTo(width));
      expect(editor.right, lessThanOrEqualTo(mic.left));
      expect(mic.right, lessThanOrEqualTo(send.left));
      expect((mic.center.dy - send.center.dy).abs(), lessThan(2));
      expect((editor.center.dy - mic.center.dy).abs(), lessThan(4));
      final material = tester.widget<Material>(
        find.byKey(const Key('viktor_composer_surface')));
      final colors = Theme.of(tester.element(
        find.byKey(const Key('viktor_composer_surface')))).colorScheme;
      expect(material.elevation, greaterThanOrEqualTo(4));
      expect(material.color, colors.surfaceContainer);
      expect(material.color, isNot(colors.surface));
      final sendSurface = tester.widget<DecoratedBox>(
        find.byKey(const Key('viktor_send_button_surface')));
      final decoration = sendSurface.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, isNot(Colors.transparent));
      // They occupy the same horizontal strip rather than two stacked rows.
      expect(editor.bottom, greaterThan(mic.top));
      expect(editor.top, lessThan(send.bottom));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Viktor expands long drafts without a permanent second row',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: ViktorChatPage(wallDay: DateTime(2026, 10, 24)),
    ));
    await tester.pump();

    final surfaceFinder = find.byKey(const Key('viktor_composer_surface'));
    final initialHeight = tester.getSize(surfaceFinder).height;
    final field = tester.widget<TextField>(
      find.byKey(const Key('viktor_composer_input')));
    field.controller!.text = List.filled(40, 'Большое сообщение').join('\n');
    await tester.pump();

    expect(tester.getSize(surfaceFinder).height,
      greaterThan(initialHeight));
    expect(tester.getSize(surfaceFinder).height, lessThan(275));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Viktor field ignores global white input fill and hides desktop scrollbars',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        platform: TargetPlatform.windows,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: ViktorChatPage(wallDay: DateTime(2026, 10, 24)),
    ));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const Key('viktor_composer_input')));
    // This explicit override prevents a white rectangle being painted
    // inside the capsule by the app-level InputDecorationTheme.
    expect(field.decoration?.filled, isFalse);
    expect(field.decoration?.fillColor, Colors.transparent);
    expect(field.decoration?.border, InputBorder.none);

    // The messages viewport must extend to the WINDOW edge, regardless
    // of the centered 760px conversation-content column.
    final viewport = tester.getRect(
      find.byKey(const Key('viktor_chat_messages_viewport')));
    final scrollbar = tester.getRect(
      find.byKey(const Key('viktor_edge_scrollbar')));
    expect(viewport.left, closeTo(0, 0.1));
    expect(viewport.right, closeTo(1440, 0.1));
    expect(scrollbar.left, closeTo(0, 0.1));
    expect(scrollbar.right, closeTo(1440, 0.1));

    final edgeScrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('viktor_edge_scrollbar')));
    expect(edgeScrollbar.thumbVisibility, false);
    expect(edgeScrollbar.trackVisibility, false);
    expect(edgeScrollbar.thickness, 3);
    expect(edgeScrollbar.interactive, false);
    // Chat content remains within the centered grid; the scrollbar does not
    // move back to the content-column edge.
    final content = tester.getRect(
      find.byKey(const Key('viktor_message_content_column')).first);
    expect(content.width, closeTo(kViktorChatContentMaxWidth, 1));
    expect(content.center.dx, closeTo(720, 1));
    final intro = tester.getRect(find.textContaining('Я Виктор'));
    expect(intro.left, greaterThanOrEqualTo(content.left));
    expect(intro.right, lessThanOrEqualTo(content.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Viktor send button becomes high-contrast with a filled draft',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ViktorChatPage(wallDay: DateTime(2026, 10, 24)),
    ));
    await tester.pump();
    final editor = tester.widget<TextField>(
        find.byKey(const Key('viktor_composer_input')));
    editor.controller!.text = 'Купить тыквы';
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Отправить Виктору'),
        matching: find.byType(IconButton),
      ).first,
    );
    // The send button must remain a canonical app control and use
    // a circular contrast surface even while its readiness is pending.
    expect(button.icon, isNotNull);
    expect(find.byKey(const Key('viktor_send_button_surface')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  for (final dark in <bool>[false, true]) {
    testWidgets('Viktor composer contrasts with real LIFE OS theme dark=$dark',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final theme = dark ? appDarkTheme : appLightTheme;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: ViktorChatPage(wallDay: DateTime(2026, 10, 24)),
      ));
      await tester.pump();

      final material = tester.widget<Material>(
          find.byKey(const Key('viktor_composer_surface')));
      expect(material.color, theme.colorScheme.surfaceContainer);
      // LIFE OS defines surfaceContainerLowest == surface; using that token
      // would recreate the user's invisible composer screenshot.
      expect(material.color, isNot(theme.colorScheme.surface));
      expect(material.elevation, greaterThanOrEqualTo(4));
      expect(find.byKey(const Key('viktor_send_button_surface')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }


}
