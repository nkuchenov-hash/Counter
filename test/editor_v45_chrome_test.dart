import 'package:counter/core/theme.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_editor_document_controller.dart';
import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:counter/features/shared/edit_sheet/editor_v45_chrome.dart';
import 'package:counter/features/shared/timeline_record_edit_sheet.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:flutter/services.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers.global/events', 'xyz.luan/audioplayers']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });
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
    await tester.pumpAndSettle();
    expect(cancelled, isFalse);
    await tester.tap(find.text(currentLocale.value == 'ru' ? 'Продолжить' : 'Keep editing'));
    await tester.pumpAndSettle();
    expect(cancelled, isFalse);
    await tester.tap(find.text(t(currentLocale.value, 'cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog),
      matching: find.text(currentLocale.value == 'ru' ? 'Отменить создание' : 'Discard')));
    await tester.pumpAndSettle();
    expect(created, isTrue);
    expect(cancelled, isTrue);
  });

  test('embedded empty document starts with body text; standalone heading stays unchanged', () {
    final embedded = NotesEditorDocumentController(const NoteDocument(blocks: []),
        initialBlockType: NoteBlockType.paragraph);
    final standalone = NotesEditorDocumentController(const NoteDocument(blocks: []));
    expect(embedded.visibleBlocks.single.type, NoteBlockType.paragraph);
    expect(standalone.visibleBlocks.single.type, NoteBlockType.heading);
  });

  testWidgets('rename uses the same mounted field and the pencil is adjacent', (tester) async {
    tester.view.physicalSize = const Size(1050, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: 'Work');
    addTearDown(controller.dispose);
    String? changed;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EditorV45Title(
      controller: controller, onChanged: (v) => changed = v, onClose: () {},
      creating: false, writing: false,
    ))));
    final field = find.byType(TextField);
    final original = tester.state<EditableTextState>(find.byType(EditableText));
    final pencil = find.byIcon(Icons.edit_outlined);
    expect(tester.widget<TextField>(field).readOnly, isTrue);
    expect(tester.getRect(pencil).left - tester.getRect(field).right, inInclusiveRange(0, 32));
    expect(tester.getRect(pencil).right, lessThan(350));
    await tester.tap(pencil);
    await tester.pump();
    expect(tester.widget<TextField>(field).readOnly, isFalse);
    await tester.enterText(field, 'Work updated');
    await tester.pump();
    expect(changed, 'Work updated');
    expect(tester.state<EditableTextState>(find.byType(EditableText)), same(original));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).readOnly, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1050.0]) {
    testWidgets('entity glass capsule is bounded and destructive action requires confirmation at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var deletes = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: EditorV45ActionOverlay(
        content: const SizedBox.expand(), visible: true,
        actions: EditorV45Actions(primaryLabel: 'Close', onPrimary: () {},
          onDelete: () => deletes++, onStop: () {}),
      ))));
      final pill = find.byKey(const ValueKey('editor-v45-action-pill'));
      final rect = tester.getRect(pill);
      expect(rect.width, closeTo(width == 390 ? 342 : 440, 0.5));
      expect(rect.center.dx, closeTo(width / 2, 0.5));
      expect(rect.bottom, closeTo(830, 0.5));
      expect(rect.height, closeTo(54, 1));
      await tester.tap(find.text(t(currentLocale.value, 'delete')));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      await tester.tap(find.descendant(of: find.byType(AlertDialog),
        matching: find.text(t(currentLocale.value, 'cancel'))));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      await tester.tap(find.text(t(currentLocale.value, 'delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog),
        matching: find.text(t(currentLocale.value, 'delete'))));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(390, 844), const Size(760, 850)]) {
    testWidgets('real running record visual state and new record endpoints at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = DatabaseService.instance;
      db.debugActivateRecordBrainTestHarness(userId: 'v45editorqa0001',
        categories: [CategoryRule(id: 1, name: 'Work')]);
      addTearDown(db.debugResetRecordBrainTestHarness);
      CategoryTreeSource.categoryExists = (id) => db.getCategoryRuleById(id) != null;
      CategoryTreeSource.getCategoryPath = (_) => 'Work > Price Reporter > DTC GLOBAL SERVICES';
      addTearDown(() { CategoryTreeSource.categoryExists = null; CategoryTreeSource.getCategoryPath = null; });
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final oldLocale = currentLocale.value;
      currentLocale.value = 'ru';
      addTearDown(() => currentLocale.value = oldLocale);
      const capture = bool.fromEnvironment('LIFEOS_CAPTURE_V45');
      if (capture) {
        await tester.runAsync(() async {
          final loader = FontLoader('Onest')..addFont(rootBundle.load('assets/fonts/Onest-Variable.ttf'));
          await loader.load();
        });
      }
      Widget screen(TimelineRecord record) => MaterialApp(
        theme: appLightTheme.copyWith(platform: size.width >= 760 ? TargetPlatform.windows : TargetPlatform.android),
        home: Scaffold(body: RepaintBoundary(key: const ValueKey('v45-capture'), child:
          KeyedSubtree(key: ValueKey(record.id), child: TimelineRecordSheetContent(record: record,
            scrollController: scroll, onSaved: (_) {}, onDelete: () {}, onStop: () {})))),
      );
      final notes = NoteDocument(blocks: const [
        NoteBlock(id: 'h', type: NoteBlockType.heading, level: 1, text: 'Итоги работы'),
        NoteBlock(id: 'p', type: NoteBlockType.paragraph, text: 'Подготовить пакет документов.'),
        NoteBlock(id: 'c', type: NoteBlockType.checklist, text: 'Проверить описание услуг'),
      ]);
      await tester.pumpWidget(screen(TimelineRecord(id: 'recpbrow0000001',
        title: 'DTC ADD Mod Plan', status: 'running', categoryId: 1,
        startTime: DateTime.utc(2026, 11, 27, 12, 51), notesDeltaJson: notes.encode())));
      await tester.pump();
      final card = tester.widget<EditorV45TimeCard>(find.byType(EditorV45TimeCard));
      expect(card.running, isTrue);
      expect(card.onEnd, isNull);
      final pill = find.byKey(const ValueKey('editor-v45-action-pill'));
      expect(pill, findsOneWidget);
      expect(tester.getSize(pill).width, closeTo(size.width >= 760 ? 440 : 342, .5));
      expect(find.byTooltip('More'), findsNothing);
      final body = find.byType(NotesEditorBody);
      expect(tester.widget<NotesEditorBody>(body).showToolbar, isFalse);
      final list = find.byKey(const ValueKey('notes-editor-content'));
      final listWidget = tester.widget(list);
      final padding = listWidget is ReorderableListView ? listWidget.padding : (listWidget as ListView).padding;
      expect(padding!.resolve(TextDirection.ltr).top, 18);
      expect(tester.takeException(), isNull);
      if (capture) {
        await expectLater(find.byKey(const ValueKey('v45-capture')),
          matchesGoldenFile('../build/editor-v45-captures/record-${size.width.toInt()}.png'));
      }
      await tester.pumpWidget(screen(TimelineRecord(id: '', title: '', status: 'completed', categoryId: 1)));
      await tester.pump();
      final newCard = tester.widget<EditorV45TimeCard>(find.byType(EditorV45TimeCard));
      expect(newCard.running, isFalse);
      expect(newCard.onEnd, isNotNull);
      expect(tester.widget<EditorV45Actions>(find.byType(EditorV45Actions)).onStop, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
