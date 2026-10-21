import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_agent_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> action(String name, Map<String, Object?> args) =>
    {'name': name, 'arguments': args};
Map<String, dynamic> batch(List<Map<String, dynamic>> actions) =>
    {'version': 1, 'request_id': 'request_20261021_abcdef', 'actions': actions};

void main() {
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

  test('Read-only queries never require mutation consent', () {
    final parsed = ViktorActionBatch.fromJson(batch([
      action('list_categories', {}),
      action('list_tags', {'domain': 'plan'}),
      action('list_notes', {}),
      action('list_paths', {}),
      action('get_settings', {}),
    ]));
    expect(parsed.hasMutations, false);
    expect(parsed.requiresPreview, false);
  });
}
