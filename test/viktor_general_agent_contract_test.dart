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
