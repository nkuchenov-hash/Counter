import 'dart:ui' as ui;

import 'package:counter/core/app_control_tokens.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/features/settings/categories/category_tag_input_field.dart';
import 'package:counter/features/timeline/timeline_header_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all standard control components use one geometry source', () {
    expect(AppTextField.height, AppControlTokens.height);
    expect(AppTextField.radius, AppControlTokens.radius);
    expect(kAppQuickEntryControlHeight, AppControlTokens.height);
    expect(AppControlTokens.height, 44);
    expect(AppControlTokens.radius, 22);
    // Full pill, not the previous 14px rounded rectangle.
    expect(AppControlTokens.radius * 2, AppControlTokens.height);
    expect(AppControlTokens.fontSize, 16);
  });

  for (final dark in <bool>[false, true]) {
    testWidgets('quick-entry field, search and neighboring buttons align in '
        '${dark ? 'dark' : 'light'} mode', (tester) async {
      final entry = TextEditingController();
      final search = TextEditingController();
      final entryFocus = FocusNode();
      final searchFocus = FocusNode();
      addTearDown(() {
        entry.dispose();
        search.dispose();
        entryFocus.dispose();
        searchFocus.dispose();
      });

      await tester.pumpWidget(MaterialApp(
        theme: dark ? appDarkTheme : appLightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 650,
            child: Column(
              children: [
                AppQuickEntryRow(
                  controller: entry,
                  focusNode: entryFocus,
                  hintText: 'Add a record',
                  actionLabel: 'Start',
                  actionIcon: Icons.play_arrow,
                  onAction: () {},
                ),
                Row(children: [
                  Expanded(child: AppTextField(
                    controller: search,
                    focusNode: searchFocus,
                    hintText: 'Search categories',
                    showSearchIcon: true,
                    textInputAction: TextInputAction.search,
                  )),
                  const SizedBox(width: AppControlTokens.horizontalGap),
                  AppIconButton(
                    tooltip: 'Expand',
                    icon: Icons.unfold_more,
                    onPressed: () {},
                  ),
                ]),
              ],
            ),
          ),
        ),
      ));

      final entryField = find.descendant(
        of: find.byType(AppQuickEntryRow),
        matching: find.byType(AppTextField),
      );
      final actionButton = find.descendant(
        of: find.byType(AppQuickEntryRow),
        matching: find.byType(AppButton),
      );
      expect(tester.getSize(entryField).height, AppControlTokens.height);
      expect(tester.getSize(actionButton).height, AppControlTokens.height);
      expect(tester.getSize(find.byType(AppTextField).last).height,
          AppControlTokens.height);
      expect(tester.getSize(find.byType(AppIconButton)).height,
          AppControlTokens.height);

      // Compare the actual visual controls, not just their sized wrappers.
      final paintedField = find.descendant(
        of: entryField,
        matching: find.byKey(const ValueKey('app-text-field-painted-surface')),
      );
      final paintedButton = find.descendant(
        of: actionButton,
        matching: find.byType(FilledButton),
      );
      final fieldRect = tester.getRect(paintedField);
      final buttonRect = tester.getRect(paintedButton);
      // Verify the actual editing line and optional search ornament live
      // within the same compact capsule, vertically centered.
      final editor = find.descendant(
        of: entryField,
        matching: find.byType(EditableText),
      );
      expect(tester.getRect(editor).height,
          lessThan(AppControlTokens.height));
      expect((tester.getRect(editor).center.dy -
              (fieldRect.center.dy + AppControlTokens.singleLineOpticalOffsetY))
          .abs(), lessThanOrEqualTo(1));
      final searchField = find.byType(AppTextField).last;
      final searchPaint = find.descendant(
        of: searchField,
        matching: find.byKey(const ValueKey('app-text-field-painted-surface')),
      );
      final searchRect = tester.getRect(searchPaint);
      expect(searchRect.height, AppControlTokens.height);
      final searchIcon = find.descendant(
        of: searchField,
        matching: find.byIcon(Icons.search_rounded),
      );
      expect(searchIcon, findsOneWidget);
      expect(find.descendant(of: entryField, matching: find.byIcon(Icons.search_rounded)),
          findsNothing);
      expect((tester.getRect(searchIcon).center.dy - searchRect.center.dy).abs(),
          lessThanOrEqualTo(1));
      expect(fieldRect.height, AppControlTokens.height);
      expect(buttonRect.height, AppControlTokens.height);
      expect(buttonRect.top, fieldRect.top);
      expect(buttonRect.bottom, fieldRect.bottom);
      final fieldDecoration =
          tester.widget<DecoratedBox>(paintedField).decoration as BoxDecoration;
      expect(fieldDecoration.borderRadius,
          BorderRadius.circular(AppControlTokens.radius));
      final filled = tester.widget<FilledButton>(paintedButton);
      final shape = filled.style?.shape?.resolve({});
      expect(filled.style?.maximumSize?.resolve({})?.height, AppControlTokens.height);
      expect(shape, isA<RoundedRectangleBorder>());
      expect((shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(AppControlTokens.radius));
      expect(AppControlTokens.radius, AppControlTokens.height / 2);
    });
  }

  // Regression for the real desktop Timeline screenshot: the button painted
  // ~72 px while the field painted ~46 px even though layout tests passed.
  // Raster-sample both surfaces, including scaled device viewports.
  for (final pixelRatio in <double>[1, 1.5, 2]) {
    testWidgets('quick entry PAINTED pixels have identical vertical bounds '
        'at DPR $pixelRatio', (tester) async {
      final entry = TextEditingController();
      final focus = FocusNode();
      addTearDown(() {
        entry.dispose();
        focus.dispose();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
      tester.view.devicePixelRatio = pixelRatio;
      tester.view.physicalSize = Size(1596 * pixelRatio, 340 * pixelRatio);
      const boundaryKey = ValueKey('quick-entry-paint-geometry');
      const background = Color(0xffabbcca);
      await tester.pumpWidget(MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: background,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: 1400,
                    child: AppQuickEntryRow(
                      controller: entry,
                      focusNode: focus,
                      hintText: 'Добавить запись',
                      actionLabel: 'Старт',
                      actionIcon: Icons.play_arrow_rounded,
                      onAction: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final bounds = tester.getRect(find.byKey(boundaryKey));
      final fieldBounds = tester.getRect(find.descendant(
        of: find.byType(AppQuickEntryRow),
        matching: find.byType(AppTextField),
      ));
      final buttonBounds = tester.getRect(find.descendant(
        of: find.byType(AppQuickEntryRow),
        matching: find.byType(AppButton),
      ));
      // GPU image encoding is real asynchronous work; Flutter's fake-async
      // widget binding cannot drive it while directly awaiting toByteData.
      final capture = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          if (bytes == null) throw StateError('Raster capture returned null');
          return (
            width: image.width,
            height: image.height,
            pixels: bytes.buffer.asUint8List(),
          );
        } finally {
          image.dispose();
        }
      });
      expect(capture, isNotNull);
      final pixels = capture!.pixels;
      final imageWidth = capture.width;
      final imageHeight = capture.height;
      // Sample the horizontal center of each surface. This bypasses the
      // rounded corners, icons, focus outlines and font antialiasing.
      final fx = ((fieldBounds.center.dx - bounds.left) * pixelRatio).round();
      final bx = ((buttonBounds.center.dx - bounds.left) * pixelRatio).round();
      int differenceAt(int x, int y) {
        final offset = (y * imageWidth + x) * 4;
        return (pixels[offset] - background.r * 255).abs().round() +
            (pixels[offset + 1] - background.g * 255).abs().round() +
            (pixels[offset + 2] - background.b * 255).abs().round();
      }
      (int, int) paintedRange(int x) {
        final ys = <int>[];
        for (var y = 0; y < imageHeight; y++) {
          if (differenceAt(x, y) > 48) ys.add(y);
        }
        expect(ys, isNotEmpty, reason: 'No painted pixels at x=$x');
        return (ys.first, ys.last);
      }
      final fieldPaint = paintedRange(fx);
      final buttonPaint = paintedRange(bx);
      expect((fieldPaint.$1 - buttonPaint.$1).abs(), lessThanOrEqualTo(1));
      expect((fieldPaint.$2 - buttonPaint.$2).abs(), lessThanOrEqualTo(1));
      final expected = (AppControlTokens.height * pixelRatio).round();
      expect(fieldPaint.$2 - fieldPaint.$1 + 1, inInclusiveRange(expected - 2, expected + 2));
      expect(buttonPaint.$2 - buttonPaint.$1 + 1, inInclusiveRange(expected - 2, expected + 2));

      // Screenshot-level SHAPE regression: a full capsule must leave all four
      // corners transparent to the row background. Checking borderRadius
      // properties alone cannot detect a rectangular overlay/paint layer.
      int pixelDifferenceAt(Offset logical) {
        final x = ((logical.dx - bounds.left) * pixelRatio).round();
        final y = ((logical.dy - bounds.top) * pixelRatio).round();
        return differenceAt(x, y);
      }
      for (final rect in [fieldBounds, buttonBounds]) {
        final corners = [
          Offset(rect.left + 2, rect.top + 2),
          Offset(rect.right - 3, rect.top + 2),
          Offset(rect.left + 2, rect.bottom - 3),
          Offset(rect.right - 3, rect.bottom - 3),
        ];
        for (final corner in corners) {
          expect(pixelDifferenceAt(corner), lessThan(48),
              reason: 'Rounded capsule must expose background at $corner');
        }
        expect(pixelDifferenceAt(Offset(rect.left + 2, rect.center.dy)),
            greaterThan(48),
            reason: 'Capsule mid-side must be visibly painted');
        expect(pixelDifferenceAt(Offset(rect.center.dx, rect.top + 2)),
            greaterThan(48),
            reason: 'Capsule top-midpoint must be visibly painted');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Timeline and Settings search paint their hint glyphs '
      'at the SAME vertical center in the canonical capsule',
      (tester) async {
    final timeline = TextEditingController();
    final settings = TextEditingController();
    final focus = FocusNode();
    addTearDown(() {
      timeline.dispose();
      settings.dispose();
      focus.dispose();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    const ratio = 1.5;
    tester.view.devicePixelRatio = ratio;
    tester.view.physicalSize = const Size(1200, 700);
    const surfaceKey = ValueKey('cross-screen-canonical-control-pixels');
    await tester.pumpWidget(MaterialApp(
      theme: appLightTheme,
      home: Scaffold(
        body: RepaintBoundary(
          key: surfaceKey,
          child: ColoredBox(
            color: const Color(0xffabbcca),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AppQuickEntryRow(
                    controller: timeline,
                    focusNode: focus,
                    hintText: 'Добавить запись',
                    actionLabel: 'Старт',
                    actionIcon: Icons.play_arrow_rounded,
                    onAction: () {},
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Builder(
                      builder: (context) => Theme(
                        data: settingsNeutralTheme(context),
                        child: AppSettingsPageBody(
                          children: [
                            AppTextField(
                              controller: settings,
                              variant: AppTextFieldVariant.search,
                              hintText: 'Найти настройку',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final timelineField = find.descendant(
      of: find.byType(AppQuickEntryRow),
      matching: find.byType(AppTextField),
    );
    final settingsField = find.descendant(
      of: find.byType(AppSettingsPageBody),
      matching: find.byType(AppTextField),
    );
    final r1 = tester.getRect(timelineField);
    final r2 = tester.getRect(settingsField);
    expect(r1.height, AppControlTokens.height);
    expect(r2.height, AppControlTokens.height);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(surfaceKey),
    );
    final boundaryRect = tester.getRect(find.byKey(surfaceKey));
    final imageData = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return (width: image.width, pixels: bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
    expect(imageData, isNotNull);
    final img = imageData!;
    double textOpticalCenter(
      Rect rect, {
      required bool search,
      required int imageWidth,
      required List<int> pixels,
    }) {
      final left = ((rect.left + (search ? 42 : 18) -
              boundaryRect.left) * ratio).ceil();
      final right = ((rect.left + (search ? 210 : 200) -
              boundaryRect.left) * ratio).floor();
      final top = ((rect.top + 3 - boundaryRect.top) * ratio).ceil();
      final bottom = ((rect.bottom - 3 - boundaryRect.top) * ratio).floor();
      final visibleRows = <int>[];
      for (var y = top; y < bottom; y++) {
        var glyphPixels = 0;
        for (var x = left; x < right; x++) {
          final offset = (y * imageWidth + x) * 4;
          if (pixels[offset] < 165 &&
              pixels[offset + 1] < 165 &&
              pixels[offset + 2] < 165) {
            glyphPixels++;
          }
        }
        if (glyphPixels >= 2) visibleRows.add(y);
      }
      expect(visibleRows, isNotEmpty);
      return (visibleRows.first + visibleRows.last) / (2 * ratio) +
          boundaryRect.top;
    }

    final timelineHintCenter = textOpticalCenter(
      r1, search: false, imageWidth: img.width, pixels: img.pixels);
    final settingsHintCenter = textOpticalCenter(
      r2, search: true, imageWidth: img.width, pixels: img.pixels);
    expect((timelineHintCenter - r1.center.dy).abs(),
        lessThanOrEqualTo(1.5),
        reason: 'Timeline hint glyph ink must align, not merely its layout box');
    expect((settingsHintCenter - r2.center.dy).abs(),
        lessThanOrEqualTo(1.5),
        reason: 'Settings hint glyph ink must align with its capsule center');

    // The user's requirement includes INPUT text, not only placeholder hint.
    // Controller changes also prove that the centered shared hint disappears.
    // Regression: Latin input seen on Nov 9 screenshot was ~4 physical px low.
    timeline.text = 'sdfdfds';
    settings.text = 'Результаты';
    await tester.pump();
    final typedImage = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return (width: image.width, pixels: bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
    expect(typedImage, isNotNull);
    final typed = typedImage!;
    final timelineTypedCenter = textOpticalCenter(
      r1, search: false, imageWidth: typed.width, pixels: typed.pixels);
    final settingsTypedCenter = textOpticalCenter(
      r2, search: true, imageWidth: typed.width, pixels: typed.pixels);
    expect((timelineTypedCenter - r1.center.dy).abs(),
        lessThanOrEqualTo(1.5),
        reason: 'Typed Latin input ink must be centered within 1.5 logical px');
    expect((settingsTypedCenter - r2.center.dy).abs(),
        lessThanOrEqualTo(1.5),
        reason: 'Typed Settings text ink must be centered within 1.5 logical px');
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick-entry whole painted surface accepts taps, not just the text line',
      (tester) async {
    final draft = TextEditingController();
    final focus = FocusNode();
    addTearDown(() {
      draft.dispose();
      focus.dispose();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 500,
            child: AppQuickEntryRow(
              controller: draft,
              focusNode: focus,
              hintText: 'Record',
              actionLabel: 'Start',
              actionIcon: Icons.play_arrow,
              onAction: () {},
            ),
          ),
        ),
      ),
    ));
    final field = find.descendant(
      of: find.byType(AppQuickEntryRow),
      matching: find.byType(AppTextField),
    );
    final bounds = tester.getRect(field);
    // The actual text box is only 21px high inside the full 44px pill.
    await tester.tapAt(Offset(bounds.left + 80, bounds.top + 3));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.enterText(find.descendant(
      of: field, matching: find.byType(TextField),
    ), 'AGE Planning');
    expect(draft.text, 'AGE Planning');
    focus.unfocus();
    await tester.pump();
    await tester.tapAt(Offset(bounds.left + 80, bounds.bottom - 3));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(draft.text, 'AGE Planning');
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive Timeline header cannot steal the live quick-entry FocusNode',
      (tester) async {
    final draft = TextEditingController();
    final liveFocus = FocusNode();
    addTearDown(() {
      draft.dispose();
      liveFocus.dispose();
    });
    final today = DateUtils.dateOnly(DateTime.now());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            TimelineHeaderControls(
              showStatsView: false,
              visibleDate: today,
              visibleIsFuture: false,
              titleController: draft,
              titleFocus: liveFocus,
              inputActive: true,
              onShowStatsViewChanged: (_) {},
              onStart: () {},
              onPlan: () {},
              onNewTaskForPastDate: () {},
            ),
            TimelineHeaderControls(
              showStatsView: false,
              visibleDate: today,
              visibleIsFuture: false,
              titleController: draft,
              titleFocus: liveFocus,
              inputActive: false,
              onShowStatsViewChanged: (_) {},
              onStart: () {},
              onPlan: () {},
              onNewTaskForPastDate: () {},
            ),
          ]),
        ),
      ),
    ));
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, hasLength(2));
    expect(fields.where((field) => identical(field.focusNode, liveFocus)), hasLength(1));
    expect(fields.where((field) => field.focusNode == null), hasLength(1));
    await tester.tap(find.byType(AppQuickEntryRow).first);
    await tester.pump();
    expect(liveFocus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tag input and its adjacent Add button share painted geometry',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: appLightTheme,
      home: const Scaffold(body: SizedBox(
        width: 390,
        child: TagInputField(tags: [], onChanged: _noopTagChanged),
      )),
    ));
    final field = find.descendant(
      of: find.byType(TagInputField),
      matching: find.byType(AppTextField),
    );
    final button = find.descendant(
      of: find.byType(TagInputField),
      matching: find.byType(AppButton),
    );
    final fieldRect = tester.getRect(find.descendant(
      of: field, matching: find.byKey(
          const ValueKey('app-text-field-painted-surface'))));
    final buttonRect = tester.getRect(find.descendant(
      of: button, matching: find.byType(FilledButton)));
    expect(fieldRect.height, AppControlTokens.height);
    expect(buttonRect.height, AppControlTokens.height);
    expect(fieldRect.top, buttonRect.top);
    expect(fieldRect.bottom, buttonRect.bottom);
    expect(tester.takeException(), isNull);
  });

  testWidgets('email, password, numeric, search, multiline and validation '
      'use the same canonical field', (tester) async {
    final controllers = List.generate(6, (_) => TextEditingController());
    addTearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          child: SingleChildScrollView(
            child: Column(children: [
              AppTextField(controller: controllers[0],
                  variant: AppTextFieldVariant.email,
                  labelText: 'Email', hintText: 'mail@example.com'),
              AppTextField(controller: controllers[1],
                  variant: AppTextFieldVariant.password),
              AppTextField(controller: controllers[2],
                  variant: AppTextFieldVariant.number),
              AppTextField(controller: controllers[3],
                  variant: AppTextFieldVariant.search),
              AppTextField(controller: controllers[4],
                  variant: AppTextFieldVariant.multiline),
              AppTextField(controller: controllers[5],
                  validator: (value) => value!.isEmpty ? 'Required' : null),
            ]),
          ),
        ),
      ),
    ));
    expect(find.byType(AppTextField), findsNWidgets(6));
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).obscureText, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField).at(2)).keyboardType,
        TextInputType.number);
    expect(tester.widget<TextField>(find.byType(TextField).at(0)).keyboardType,
        TextInputType.emailAddress);
    expect(tester.widget<TextField>(find.byType(TextField).at(4)).maxLines, 6);
    expect(tester.takeException(), isNull);
  });
}

void _noopTagChanged(List<String> tags) {}
