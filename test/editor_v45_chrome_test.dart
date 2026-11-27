import 'dart:io';
import 'dart:ui' as ui;
import 'package:counter/core/theme.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:counter/features/shared/planning_task_edit_sheet.dart';
import 'package:counter/features/shared/timeline_record_edit_sheet.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:counter/features/shared/edit_sheet/editor_v45_chrome.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  test('range formatter tolerates unset endpoints', () {
    expect(editorV45Range(null, null), '');
    expect(editorV45Time(null), '—:—');
    expect(editorV45Range(DateTime(2026, 11, 27, 18, 30),
        DateTime(2026, 11, 27, 19, 45)), '18:30 — 19:45');
  });

  testWidgets('B1 shows both times, duration and working endpoints', (tester) async {
    var startTapped = false;
    var endTapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 350, child: EditorV45TimeCard(
        start: DateTime(2026, 11, 27, 18, 30),
        end: DateTime(2026, 11, 27, 19, 45),
        onStart: (_) => startTapped = true,
        onEnd: (_) => endTapped = true,
      )),
    ))));
    expect(find.text('18:30'), findsOneWidget);
    expect(find.text('19:45'), findsOneWidget);
    expect(find.text(currentLocale.value == 'ru' ? '1 ч 15 мин' : '1 h 15 min'), findsOneWidget);
    await tester.tap(find.text('18:30'));
    await tester.tap(find.text('19:45'));
    expect(startTapped, isTrue);
    expect(endTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating and closing use provided host actions', (tester) async {
    var created = false;
    var cancelled = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EditorV45Actions(
      primaryLabel: 'Create record',
      onPrimary: () => created = true,
      onCancel: () => cancelled = true,
    ))));
    await tester.tap(find.text('Create record'));
    await tester.tap(find.text(t(currentLocale.value, 'cancel')));
    expect(created, isTrue);
    expect(cancelled, isTrue);
  });

  testWidgets('approved v45 pill is capped at 440 and stays centered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EditorV45Actions(
      primaryLabel: 'Close', onPrimary: () {}, onDelete: () {},
    ))));
    final pill = tester.getRect(find.byKey(const ValueKey('v45-action-pill')));
    expect(pill.width, 440);
    expect(pill.center.dx, closeTo(500, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only title pencil follows short title rather than screen edge', (tester) async {
    final controller = TextEditingController(text: 'Meeting');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EditorV45Title(
      controller: controller, onChanged: (_) {}, onClose: () {},
      creating: false, writing: false,
    ))));
    final text = tester.getRect(find.text('Meeting'));
    final pencil = tester.getRect(find.byIcon(Icons.edit_outlined));
    expect(pencil.left - text.right, lessThan(24));
    expect(tester.takeException(), isNull);
  });

  // Opt-in screenshot evidence: actual production widgets, offline fixture
  // data, bundled Onest and application themes. Never contacts real accounts.
  testWidgets('capture v45 mobile and desktop editor review screenshots', (tester) async {
    final output = Platform.environment['V45_CAPTURE_DIR'];
    if (output == null) return;
    // The widget-test engine has no native audio plugin. Stub only the
    // platform transport; production NoteEditorPage and its UI stay real.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const globalAudio = MethodChannel('xyz.luan/audioplayers.global');
    const globalAudioEvents = MethodChannel('xyz.luan/audioplayers.global/events');
    const playerAudio = MethodChannel('xyz.luan/audioplayers');
    final playerEvents = <MethodChannel>[];
    messenger.setMockMethodCallHandler(globalAudio, (_) async => null);
    messenger.setMockMethodCallHandler(globalAudioEvents, (_) async => null);
    messenger.setMockMethodCallHandler(playerAudio, (call) async {
      if (call.method == 'create') {
        final id = (call.arguments as Map)['playerId'];
        final events = MethodChannel('xyz.luan/audioplayers/events/$id');
        playerEvents.add(events);
        messenger.setMockMethodCallHandler(events, (_) async => null);
      }
      return null;
    });
    addTearDown(() {
      for (final channel in [globalAudio, globalAudioEvents, playerAudio, ...playerEvents]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
    await tester.runAsync(() async {
      final font = FontLoader('Onest')
        ..addFont(rootBundle.load('assets/fonts/Onest-Variable.ttf'));
      await font.load();
    });
    final previousLocale = currentLocale.value;
    currentLocale.value = 'ru';
    addTearDown(() => currentLocale.value = previousLocale);
    final db = DatabaseService.instance;
    db.debugActivateRecordBrainTestHarness(userId: 'v45visualfixture',
      categories: [CategoryRule(id: 1, name: 'Тренировки')]);
    addTearDown(db.debugResetRecordBrainTestHarness);
    CategoryTreeSource.categoryExists = (id) => db.getCategoryRuleById(id) != null;
    CategoryTreeSource.getCategoryPath = (_) => 'Спорт / Тренировки';
    addTearDown(() {
      CategoryTreeSource.categoryExists = null;
      CategoryTreeSource.getCategoryPath = null;
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const doc = NoteDocument(blocks: [
      NoteBlock(id: 'a', type: NoteBlockType.heading, level: 1, text: 'Подготовка'),
      NoteBlock(id: 'b', type: NoteBlockType.paragraph, text: 'В первую очередь нужно купить билеты и забронировать жильё. Это будет наша первая поездка в этом году.'),
      NoteBlock(id: 'c', type: NoteBlockType.paragraph, text: 'Проверить срок действия паспорта, распечатать билеты и сохранить всё в телефоне. Подробнее на сайте РЖД.'),
      NoteBlock(id: 'd', type: NoteBlockType.heading, level: 2, text: 'Что взять с собой'),
      NoteBlock(id: 'e', type: NoteBlockType.bulletedList, text: 'Удобную обувь для прогулок'),
      NoteBlock(id: 'f', type: NoteBlockType.bulletedList, text: 'Тёплую одежду и зонт на случай дождя'),
      NoteBlock(id: 'g', type: NoteBlockType.bulletedList, text: 'Зарядку и пауэрбанк'),
      NoteBlock(id: 'h', type: NoteBlockType.heading, level: 3, text: 'Документы'),
      NoteBlock(id: 'i', type: NoteBlockType.numberedList, text: 'Паспорт'),
      NoteBlock(id: 'j', type: NoteBlockType.numberedList, text: 'Билеты туда и обратно'),
    ]);
    final task = PlanningTask(id: 1, title: 'Тренировка в зале', categoryId: 1,
      dateKey: '2026-11-27', startTime: DateTime(2026, 11, 27, 18, 30),
      endDateTime: DateTime(2026, 11, 27, 19, 45), notesDeltaJson: doc.encode());
    final record = TimelineRecord(id: 'v45record000001', title: 'Тренировка в зале',
      categoryId: 1, startTime: DateTime.utc(2026, 11, 27, 18, 34),
      endTime: DateTime.utc(2026, 11, 27, 19, 42), notesDeltaJson: doc.encode());
    final note = PlanningTask(id: 2, title: 'Поездка в Петербург', categoryId: 1,
      dateKey: '', notesDeltaJson: doc.encode());
    for (final size in [const Size(390, 844), const Size(760, 850)]) {
      tester.view.physicalSize = size;
      for (final dark in [false, true]) {
        for (final kind in ['plan', 'record', 'note']) {
          final scroll = ScrollController();
          final boundary = GlobalKey();
          final Widget screen = switch (kind) {
            'plan' => PlanningTaskEditSheet(task: task, dateKey: task.dateKey,
              scrollController: scroll),
            'record' => TimelineRecordSheetContent(record: record,
              scrollController: scroll, onSaved: (_) {}, onDelete: () {}, onStop: () {}),
            _ => NoteEditorPage(task: note, initialDocument: doc, onDocumentChanged: (_) {}),
          };
          await tester.pumpWidget(MaterialApp(
            theme: dark ? appDarkTheme : appLightTheme,
            home: RepaintBoundary(key: boundary, child: Scaffold(body: screen)),
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final filename = '${kind}-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png';
          await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            final file = File('$output/$filename');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          });
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          scroll.dispose();
        }
      }
    }
  });
}
