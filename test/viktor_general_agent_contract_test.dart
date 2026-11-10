import 'dart:io';
import 'package:counter/data/ai/viktor_executor.dart';
import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_agent_capabilities.dart';
import 'package:counter/data/ai/viktor_domain_tools.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> action(String name, Map<String, Object?> args) =>
    {'name': name, 'arguments': args};
Map<String, dynamic> batch(List<Map<String, dynamic>> actions) =>
    {'version': 1, 'request_id': 'request_20261021_abcdef', 'actions': actions};

void main() {
  test('PocketBase plan projection carries revision for atomic Viktor writes',
      () async {
    // A real production error resulted from dropping the top-level
    // RecordModel.updated field before preparing 30 schedule updates.
    final mapper = await File('lib/data/plan_service.dart').readAsString();
    expect(mapper, contains("'updated': r.updated"));
    expect(mapper, contains("'created': r.created"));
    expect(mapper, contains(
        "'recurrence_instance_date_key': d['recurrence_instance_date_key']"));
    final gateway = await File('lib/data/ai/viktor_atomic_bulk_gateway.dart')
        .readAsString();
    expect(gateway, contains('current.updated.replaceFirst'));
    expect(gateway, contains("current.data['tags_link']"));
    expect(gateway, contains("current.data['is_done']"));
    final planned = PlanningTask.fromJson({
      'title': 'Duration repair',
      'id': 0,
      'dateKey': '2026-11-09',
      'updated': '2026-11-09 17:40:10.321Z',
      'created': '2026-11-08 10:00:00.000Z',
    });
    expect(planned.updatedAt?.toUtc(),
        DateTime.utc(2026, 11, 9, 17, 40, 10, 321));
  });


  test('rejected proposals return to dialogue, not automatic commits', () async {
    final chat = await File('lib/features/viktor/viktor_chat_page.dart')
        .readAsString();
    final gateway = await File('lib/data/ai/viktor_gateway.dart')
        .readAsString();
    final recovery = await File('lib/features/viktor/viktor_recovery.dart')
        .readAsString();
    expect(recovery, contains('_retryRejectedProposal('));
    expect(recovery, contains('readStep < 2'));
    expect(recovery, contains('batch.hasMutations'));
    expect(recovery, contains('executor.describe(batch, day)'));
    expect(recovery, contains('toolObservations: observations'));
    expect(chat, contains('recoveredProposal = true'));
    expect(chat, contains('!recoveredProposal'));
    expect(chat, contains('_offerRecovery('));
    expect(chat, contains('writeStarted = true'));
    expect(gateway, contains("'advice_only': true"));
    expect(gateway, contains('if (adviceOnly) {'));
    expect(gateway, contains('actions: null'));
  });

  test('Viktor honours all three explicitly requested days', () async {
    const requested = 'Исправь длительность всех текущих планов вчера, '
        'сегодня и завтра по настройкам длительности по тегам.';
    expect(ViktorTagDurationRepair.matches(requested), isTrue);
    expect(ViktorTagDurationRepair.includesYesterday(requested), isTrue);
    expect(ViktorTagDurationRepair.includesYesterday(
      'Исправь вчера, сегодня и завтра, но без вчера'), isFalse);
    expect(ViktorTagDurationRepair.includesYesterday(
      'Планы сегодня и завтра'), isFalse);
    expect(ViktorTagDurationRepair.targetDays(DateTime(2026, 11, 10),
      includeYesterday: true), [
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 11),
      ]);
    expect(ViktorTagDurationRepair.targetDays(DateTime(2026, 12, 31),
      includeYesterday: true), [
        DateTime(2026, 12, 30),
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 1),
      ]);
    final code = await File('lib/features/viktor/viktor_chat_page.dart')
        .readAsString();
    expect(code, contains('ViktorTagDurationRepair.includesYesterday(input)'));
    expect(RegExp(r'includeYesterday: includeYesterday')
        .allMatches(code).length, 3,
        reason: 'Initial proposal, partial preview, and commit must '
                'operate over the same user-selected day scope');
  });

  test('Two-day tag default duration repair is explicit and safe', () {
    expect(ViktorTagDurationRepair.matches(
      'Исправь длительность всех текущих планов сегодня и завтра '
      'учитывая их базовую длительность из настроек длительности по тегам'
    ), isTrue);
    expect(ViktorTagDurationRepair.matches(
      'Какая длительность у планов сегодня и завтра по тегам?'
    ), isFalse);
    expect(ViktorTagDurationRepair.matches(
      'Не меняй длительность планов сегодня и завтра по тегам'
    ), isFalse);
    expect(ViktorTagDurationRepair.matches(
      'Исправь длительность планов сегодня по тегам'
    ), isFalse);

    const a = Tag(tagId: 1, name: 'Работа', pbRecordId: 'aaaaabbbbbccccc');
    const b = Tag(tagId: 2, name: 'Здоровье', pbRecordId: 'dddddeeeeefffff');
    const configuredA = Tag(tagId: 1, name: 'Работа',
        pbRecordId: 'aaaaabbbbbccccc', defaultPlanDurationMinutes: 30);
    const configuredB = Tag(tagId: 2, name: 'Здоровье',
        pbRecordId: 'dddddeeeeefffff', defaultPlanDurationMinutes: 60);
    expect(ViktorTagDurationRepair.defaultMinutes(
      [a], [configuredA, configuredB]), 30);
    expect(ViktorTagDurationRepair.defaultMinutes(
      [a, b], [configuredA, configuredB]), isNull,
      reason: 'Conflicting defaults may never be guessed');
    expect(ViktorTagDurationRepair.defaultMinutes(
      [a], [configuredB]), isNull,
      reason: 'No tag-name fallback after a missing PocketBase relation id');
    expect(ViktorTagDurationRepair.defaultMinutes([], [configuredA]), isNull);
  });

  test('Historical notes search and exact read are safe read-only tools', () {
    expect(ViktorActionBatch.fromJson(batch([
      action('search_record_notes', {'year': 2023, 'month': 1}),
      action('read_record_note', {'record_id': 'aaaaabbbbbccccc'}),
    ])).hasMutations, false);
    expect(() => ViktorActionBatch.fromJson(batch([
      action('search_record_notes', {'month': 1}),
    ])), throwsFormatException);
    for (final actionData in [
      action('search_notes', {'year': 2023, 'month': 1}),
      action('search_notes', {'query': 'стихотворение', 'limit': 15}),
      action('read_note', {'note_id': 'aaaaabbbbbccccc'}),
    ]) {
      final batchValue = ViktorActionBatch.fromJson(batch([actionData]));
      expect(batchValue.hasMutations, false);
    }
    for (final invalid in [
      {'month': 1}, {'year': 2023, 'month': 13},
      {'query': ''}, {'year': 2023, 'limit': 500},
    ]) {
      expect(() => ViktorActionBatch.fromJson(batch([
        action('search_notes', invalid),
      ])), throwsFormatException);
    }
    expect(() => ViktorActionBatch.fromJson(batch([
      action('read_note', {'note_id': 'not-real'}),
    ])), throwsFormatException);
  });

  test('Exact poem line edit preserves note blocks and rich metadata', () {
    final original = NoteDocument(blocks: [
      const NoteBlock(id: 'line1', type: NoteBlockType.paragraph,
          text: 'Первая строка'),
      const NoteBlock(id: 'image1', type: NoteBlockType.image,
          imageData: 'data:fake-media', caption: 'Иллюстрация'),
      const NoteBlock(id: 'line3', type: NoteBlockType.quote,
          text: 'Третья строка',
          runs: [NoteTextRun(text: 'Третья строка',
              marks: NoteInlineMarks(italic: true))]),
    ]);
    final revised = ViktorNoteLinePatch.apply(original,
        lineNumber: 2, expectedText: 'Третья строка',
        replacement: 'Новая третья строка');
    expect(original.blocks[2].effectiveText, 'Третья строка');
    expect(revised.blocks[2].effectiveText, 'Новая третья строка');
    expect(revised.blocks[2].runs.single.marks.italic, isTrue);
    expect(revised.blocks[1].imageData, 'data:fake-media');
    expect(revised.blocks[1].caption, 'Иллюстрация');
    expect(revised.blocks[0].effectiveText, 'Первая строка');
    expect(() => ViktorNoteLinePatch.apply(original,
        lineNumber: 2, expectedText: 'Уже другая строка',
        replacement: 'Новая версия'), throwsStateError);
    expect(ViktorActionBatch.fromJson(batch([
      action('edit_note_line', {
        'note_id': 'aaaaabbbbbccccc', 'expected_title': 'Стих',
        'line_number': 2, 'expected_text': 'Третья строка',
        'text': 'Новая третья строка',
      })
    ])).requiresPreview, isTrue);
  });

  test('All declared tools have unique names and explicit risk', () {
    expect(ViktorAgentCapabilities.tools.length,
        ViktorAgentCapabilities.names.length);
    expect(ViktorAgentCapabilities.names, containsAll({
      'create_note', 'edit_note', 'create_tag', 'create_category',
      'list_paths', 'create_path', 'change_setting',
    }));
    expect(ViktorAgentCapabilities.byName['get_settings']!.requiresApproval,
        false);
    expect(ViktorAgentCapabilities.byName['create_path']!.requiresApproval,
        true);
  });

  test('Multi-domain agent request has one consent preview', () {
    final parsed = ViktorActionBatch.fromJson(batch([
      action('create_tag', {'name': 'Редизайн', 'domain': 'plan'}),
      action('create_note', {
        'title': 'ТЗ для сайта',
        'text': 'Заголовок\nПодробное описание\nЕщё одна строка',
      }),
      action('change_setting', {
        'field': 'theme_mode', 'value': 'dark',
      }),
    ]));
    expect(parsed.actions.length, 3);
    expect(parsed.requiresPreview, true);
    expect(parsed.hasMutations, true);
  });

  test('Path creation validates stages, action minutes and category id', () {
    final path = action('create_path', {
      'name': 'Редизайн сайта',
      'category_id': 'aaaaabbbbbccccc',
      'goal': 'Обновить сайт за неделю',
      'stages': [
        {'title': 'Главная', 'criteria': 'Одобрены макеты', 'actions': [
          {'text': 'Обновить hero', 'result': 'Готовый hero',
           'minutes': 60},
        ]},
      ],
    });
    expect(ViktorActionBatch.fromJson(batch([path])).hasMutations, true);
    final invalid = Map<String, dynamic>.from(path);
    invalid['arguments'] = {
      ...Map<String, Object?>.from(path['arguments'] as Map),
      'stages': [
        {'title': 'Пустой этап', 'criteria': 'Результат',
         'actions': [
          {'text': 'Слишком мало', 'result': 'Проверка', 'minutes': 1},
        ]},
      ],
    };
    expect(() => ViktorActionBatch.fromJson(batch([invalid])),
        throwsFormatException);
  });

  test('Unknown setting and unexpected fields are rejected', () {
    for (final args in [
      {'field': 'is_admin', 'value': 'true'},
      {'field': 'theme_mode', 'value': 'rainbow'},
      {'field': 'theme_mode', 'value': 'dark', 'sql': 'DROP TABLE profiles'},
    ]) {
      expect(() => ViktorActionBatch.fromJson(
          batch([action('change_setting', args)])), throwsFormatException);
    }
  });

  test('Agent registry never exposes destructive server or development tools', () {
    for (final forbidden in [
      'run_sql', 'execute_code', 'edit_source', 'delete_account',
      'set_admin', 'write_pocketbase', 'raw_http', 'delete_all',
    ]) {
      expect(ViktorAgentCapabilities.names.contains(forbidden), isFalse);
      expect(() => ViktorActionBatch.fromJson(batch([
        action(forbidden, {}),
      ])), throwsFormatException);
    }
  });

  test('A tag and Path cannot smuggle provider keys or arbitrary fields', () {
    expect(() => ViktorActionBatch.fromJson(batch([
      action('create_tag', {
        'name': 'Редизайн',
        'domain': 'plan',
        'api_key': 'should-never-be-persisted',
      }),
    ])), throwsFormatException);
    expect(() => ViktorActionBatch.fromJson(batch([
      action('create_path', {
        'name': 'Сайт',
        'category_id': 'aaaaabbbbbccccc',
        'goal': 'Обновить главную',
        'stages': [
          {'title': 'Этап', 'criteria': 'Готово', 'actions': [
            {'text': 'Работа', 'result': 'Готово', 'minutes': 60,
             'script': 'rm -rf'},
          ]},
        ],
      }),
    ])), throwsFormatException);
  });

  test('Backlog list tools validate freshness and forbid arbitrary data', () {
    final complete = action('set_list_item_done', {
      'item_id': 'aaaaabbbbbccccc',
      'expected_title': 'Проверить макет',
      'expected_is_done': false,
      'is_done': true,
    });
    expect(ViktorActionBatch.fromJson(batch([complete])).hasMutations, true);
    expect(() => ViktorActionBatch.fromJson(batch([
      action('set_list_item_done', {
        ...Map<String, Object?>.from(complete['arguments'] as Map),
        'expected_is_done': true,
      }),
    ])), throwsFormatException);
    expect(() => ViktorActionBatch.fromJson(batch([
      action('set_list_item_done', {
        ...Map<String, Object?>.from(complete['arguments'] as Map),
        'user_id': 'forbidden',
      }),
    ])), throwsFormatException);
    expect(() => ViktorActionBatch.fromJson(batch([
      action('rename_list_item', {
        'item_id': 'aaaaabbbbbccccc',
        'expected_title': 'Старое',
        'title': 'Новое',
      }),
    ])), returnsNormally);
  });

  test('Only one reversible write qualifies for auto-apply', () {
    final single = ViktorActionBatch.fromJson(batch([
      action('create_tag', {'name': 'UI', 'domain': 'list'}),
    ]));
    expect(single.isSingleReversibleWrite, true);
    final done = ViktorActionBatch.fromJson(batch([
      action('set_list_item_done', {
        'item_id': 'aaaaabbbbbccccc',
        'expected_title': 'Проверить макет',
        'expected_is_done': false, 'is_done': true,
      }),
    ]));
    expect(done.isSingleReversibleWrite, true);
    final rename = ViktorActionBatch.fromJson(batch([
      action('rename_list_item', {
        'item_id': 'aaaaabbbbbccccc',
        'expected_title': 'Старое', 'title': 'Новое',
      }),
    ]));
    expect(rename.isSingleReversibleWrite, false);
    final multi = ViktorActionBatch.fromJson(batch([
      action('create_tag', {'name': 'UI', 'domain': 'list'}),
      action('create_tag', {'name': 'UX', 'domain': 'list'}),
    ]));
    expect(multi.isSingleReversibleWrite, false);
  });

  test('Read-only queries never require mutation consent', () {
    final parsed = ViktorActionBatch.fromJson(batch([
      action('list_categories', {}),
      action('list_tags', {'domain': 'plan'}),
      action('list_backlog_items', {}),
      action('list_notes', {}),
      action('list_paths', {}),
      action('get_settings', {}),
    ]));
    expect(parsed.hasMutations, false);
    expect(parsed.requiresPreview, false);
  });
}
