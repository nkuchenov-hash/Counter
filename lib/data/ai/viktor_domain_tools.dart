
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/paths/path_repository.dart';
import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'viktor_action_contract.dart';

/// Change a single numbered nonempty line, preserving all other note blocks,
/// existing media, metadata and unchanged formatting.
class ViktorNoteLinePatch {
  static NoteDocument apply(NoteDocument document, {
    required int lineNumber,
    required String expectedText,
    required String replacement,
  }) {
    var seen = 0;
    for (var blockIndex = 0; blockIndex < document.blocks.length; blockIndex++) {
      final block = document.blocks[blockIndex];
      if (!block.type.isTextual) continue;
      final source = block.effectiveText;
      var offset = 0;
      for (final line in source.split('\n')) {
        if (line.trim().isNotEmpty) {
          seen++;
          if (seen == lineNumber) {
            if (line != expectedText) {
              throw StateError('Строка изменилась после прочтения. '
                  'Повторно откройте заметку.');
            }
            if (block.runs.length > 1) {
              throw StateError('Внутри строки сложное форматирование. '
                  'Автоматическая замена без потерь недоступна.');
            }
            final revised = source.replaceRange(
                offset, offset + line.length, replacement);
            final updatedBlock = block.copyWith(
              text: revised,
              runs: block.runs.length == 1
                  ? [block.runs.single.copyWith(text: revised)]
                  : const <NoteTextRun>[],
            );
            final blocks = [...document.blocks];
            blocks[blockIndex] = updatedBlock;
            return document.copyWith(blocks: blocks);
          }
        }
        offset += line.length + 1;
      }
    }
    throw StateError('Указанная строка не найдена в заметке.');
  }
}

/// Brain-backed, owner-scoped app tools. No direct PocketBase writes or
/// arbitrary code evaluation by the model.
class ViktorDomainTools {
  ViktorDomainTools(this.db);
  final DatabaseService db;
  late final PathRepository _paths = PathRepository(database: db);

  static const names = <String>{
    'list_categories', 'create_category',
    'list_tags', 'create_tag', 'rename_tag',
    'list_backlog_items', 'set_list_item_done', 'rename_list_item',
    'list_notes', 'search_notes', 'read_note', 'create_note', 'edit_note', 'edit_note_line',
    'list_paths', 'create_path', 'get_settings', 'change_setting',
  };
  static const reads = <String>{
    'list_categories', 'list_tags', 'list_backlog_items',
    'list_notes', 'search_notes', 'read_note', 'list_paths', 'get_settings',
  };

  CategoryRule? _category(String? rowId) {
    if (rowId == null || rowId.isEmpty) {
      final id = db.defaultCategoryId;
      return id == null ? null : db.getCategoryRuleById(id);
    }
    final c = db.getCategoryRuleByBackendRowId(rowId);
    return c?.isArchived == true ? null : c;
  }

  Future<List<Tag>> _tags(String domain) =>
      db.fetchTagsForCurrentUser(
        scope: domain == 'list' ? TagCatalogScope.list : TagCatalogScope.plan,
      );

  Future<List<PlanningTask>> _searchableNotes() async {
    // The same Brain-owned collection and owner filter as the Notes library.
    // Hydrate system creation timestamps; never infer dates from title text.
    await db.ensureNoteTimestampsHydrated();
    final rows = await db.fetchBacklogPlans(
        categoryId: null, includeCompleted: true);
    return rows.where((p) => p.pocketRecordId != null &&
        p.startTime == null && p.hasNotes).toList();
  }

  Future<String> _searchNotes(Map<String, Object?> args) async {
    final search = (args['query'] as String? ?? '').toLowerCase().trim();
    final year = args['year'] as int?;
    final month = args['month'] as int?;
    final limit = args['limit'] as int? ?? 20;
    final notes = await _searchableNotes();
    final found = notes.where((p) {
      final created = p.createdAt?.toLocal();
      if (year != null && (created == null || created.year != year)) {
        return false;
      }
      if (month != null && created?.month != month) return false;
      if (search.isEmpty) return true;
      return p.title.toLowerCase().contains(search) ||
          (p.notesPlain ?? '').toLowerCase().contains(search);
    }).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
    if (found.isEmpty) {
      return 'Совпадений среди доступных заметок нет. '
          'Дата определяется по дате создания, а не по заголовку. '
          'Если документ находится в записи или другом разделе, '
          'потребуется поиск по тому разделу.';
    }
    final result = found.take(limit).map((p) {
      final created = p.createdAt?.toLocal().toIso8601String().substring(0, 10)
          ?? 'неизвестно';
      final summary = (p.notesPlain ?? '')
          .replaceAll(RegExp(r'\s+'), ' ').trim();
      final snippet = summary.length > 170
          ? '${summary.substring(0, 170)}…' : summary;
      return 'id=${p.pocketRecordId}; создано=$created; '
          'название=${p.title}; отрывок=$snippet';
    }).join('\n');
    final more = found.length > limit
        ? '\nПоказаны первые $limit из ${found.length}; '
          'уточните период или поисковую фразу.' : '';
    return 'Найдено заметок: ${found.length}.\n$result$more';
  }

  Future<String> _readNote(String id) async {
    final found = (await _searchableNotes())
        .where((p) => p.pocketRecordId == id).toList();
    if (found.length != 1) {
      return 'Заметка не найдена или недоступна в текущем аккаунте.';
    }
    final note = found.single;
    final blocks = db.parseNoteDocument(note).blocks;
    final lines = <String>[];
    var textLine = 0;
    for (final block in blocks) {
      if (!block.type.isTextual) {
        lines.add('[Вложение ${block.type.name}, не текст]');
        continue;
      }
      for (final rawLine in block.effectiveText.split('\n')) {
        if (rawLine.trim().isNotEmpty) {
          textLine++;
          lines.add('Строка $textLine: $rawLine');
        }
      }
    }
    final content = lines.join('\n');
    final shown = content.length > 7500 ? content.substring(0, 7500) : content;
    return 'Заметка «${note.title}», id=$id, '
        'создана=${note.createdAt?.toLocal().toIso8601String() ?? 'неизвестно'}.'
        '\nНумерация только непустых текстовых строк:\n$shown'
        '${shown.length < content.length ? '\n[Текст обрезан; нельзя '
           'уверенно отвечать о скрытых строках.]' : ''}';
  }

  Future<PlanningTask> _note(String rowId, String expectedTitle) async {
    final rows = await db.fetchBacklogPlans(categoryId: null,
        includeCompleted: true);
    final found = rows.where((p) =>
      p.pocketRecordId == rowId &&
      p.startTime == null &&
      (p.notesDeltaJson ?? '').isNotEmpty &&
      p.title.trim() == expectedTitle.trim()).toList();
    if (found.length != 1) {
      throw StateError('Заметка изменилась. Перечитайте её перед изменением.');
    }
    return found.single;
  }

  /// The same backlog collection serves Notes. Never mutate note documents,
  /// scheduled plans or virtual recurrence through a list-item tool.
  Future<PlanningTask> _listItem(String id, String expectedTitle,
      {bool? expectedDone}) async {
    final rows = await db.fetchBacklogPlans(
        categoryId: null, includeCompleted: true);
    final matching = rows.where((p) =>
      p.pocketRecordId == id &&
      p.startTime == null &&
      (p.notesDeltaJson?.trim().isEmpty ?? true) &&
      (p.rrule?.trim().isEmpty ?? true) &&
      (p.recurrenceInstanceDateKey?.trim().isEmpty ?? true) &&
      p.title.trim() == expectedTitle.trim() &&
      (expectedDone == null || p.isDone == expectedDone)).toList();
    if (matching.length != 1) {
      throw StateError('Элемент списка изменился или недоступен. '
          'Обновите список перед повтором.');
    }
    return matching.single;
  }

  Future<List<PlanningTask>> _listItems() async {
    final rows = await db.fetchBacklogPlans(
        categoryId: null, includeCompleted: true);
    return rows.where((p) => p.pocketRecordId != null &&
        p.startTime == null &&
        (p.notesDeltaJson?.trim().isEmpty ?? true) &&
        (p.rrule?.trim().isEmpty ?? true) &&
        (p.recurrenceInstanceDateKey?.trim().isEmpty ?? true)).toList();
  }

  static String _safeSetting(String field, String value) {
    if (field == 'preferred_timezone') {
      final match = catalogEntryForStoredTimezone(value);
      if (match == null) throw StateError('Неизвестный часовой пояс.');
      return match.profileValue;
    }
    if (field == 'primary_language' &&
        !const {'ru', 'en', 'de'}.contains(value)) {
      throw StateError('Язык должен быть ru, en или de.');
    }
    return value;
  }

  Future<String> preview(ViktorAction tool) async {
    final a = tool.arguments;
    switch (tool.name) {
      case 'list_categories':
        await db.refreshCategoryRulesFromServer();
        final parts = <String>[];
        void walk(CategoryRule c, int depth) {
          if (!c.isArchived) {
            parts.add(('  ' * depth) + c.name +
                ' [id=' + (c.backendRowId ?? '') + ']');
          }
          for (final child in c.children ?? <CategoryRule>[]) {
            walk(child, depth + 1);
          }
        }
        for (final c in db.rules) { walk(c, 0); }
        return parts.isEmpty ? 'Категорий нет.' :
            'Категории:\n' + parts.take(60).join('\n');
      case 'list_tags':
        final found = await _tags(a['domain'] as String);
        return found.isEmpty ? 'Тегов нет.' :
            'Теги:\n' + found.take(60).map((t) =>
              t.name + ' [id=' + (t.pbRecordId ?? '') + ']')
                .join('\n');
      case 'list_backlog_items':
        final items = await _listItems();
        return items.isEmpty ? 'Список пуст.' :
            'Элементы списка:\n' + items.take(60).map((p) =>
              (p.isDone ? '[x] ' : '[ ] ') + p.title +
              ' [id=' + (p.pocketRecordId ?? '') + ']').join('\n');
      case 'set_list_item_done':
        final item = await _listItem(
          a['item_id'] as String, a['expected_title'] as String,
          expectedDone: a['expected_is_done'] as bool);
        return (a['is_done'] == true ? 'Завершить «' : 'Вернуть в работу «') +
            item.title + '».';
      case 'rename_list_item':
        final item = await _listItem(
          a['item_id'] as String, a['expected_title'] as String);
        return 'Переименовать «' + item.title + '» в «' +
            (a['title'] as String) + '».';
      case 'search_notes':
        return _searchNotes(a);
      case 'read_note':
        return _readNote(a['note_id'] as String);
      case 'list_notes':
        final rows = await db.fetchBacklogPlans(
          categoryId: null, includeCompleted: true);
        final found = rows.where((p) =>
          p.startTime == null && (p.notesDeltaJson ?? '').isNotEmpty);
        return found.isEmpty ? 'Заметок нет.' :
            'Заметки:\n' + found.take(45).map((p) =>
              p.title + ' [id=' + (p.pocketRecordId ?? '') + ']')
                .join('\n');
      case 'list_paths':
        final found = await _paths.loadActivePaths();
        return found.paths.isEmpty ? 'Путей нет.' :
            'Пути:\n' + found.paths.take(30).map((p) =>
              p.name + ' [id=' + p.pathId + '] этапов: ' +
              p.stages.length.toString()).join('\n');
      case 'get_settings':
        final s = db.settings;
        return 'Настройки: тема=' + s.themeMode +
          '; часовой пояс=' + s.preferredTimeZone +
          '; язык=' + s.primaryLanguage +
          '; списки=' + s.listCompletionBehavior +
          '; имя=' + (s.displayName ?? '');
      case 'create_tag':
        final tags = await _tags(a['domain'] as String);
        final name = a['name'] as String;
        if (tags.any((t) =>
            t.name.toLowerCase() == name.toLowerCase())) {
          throw StateError('Такой тег уже существует.');
        }
        return 'Создать тег «' + name + '» (' + (a['domain'] as String) + ').';
      case 'rename_tag':
        final tags = [...await _tags('plan'), ...await _tags('list')];
        final found = tags.where((t) =>
          t.pbRecordId == a['tag_id'] && t.name == a['expected_name']);
        if (found.length != 1) {
          throw StateError('Тег изменился после загрузки.');
        }
        return 'Переименовать тег «' + (a['expected_name'] as String) +
            '» в «' + (a['name'] as String) + '».';
      case 'create_category':
        final rowId = a['parent_category_id'] as String?;
        if (rowId != null && _category(rowId) == null) {
          throw StateError('Родительская категория не найдена.');
        }
        return 'Создать категорию «' + (a['name'] as String) + '».';
      case 'create_note':
        if (_category(a['category_id'] as String?) == null) {
          throw StateError('Выберите существующую категорию заметки.');
        }
        return 'Создать заметку «' + (a['title'] as String) +
            '» с текстом:\n' + (a['text'] as String);
      case 'edit_note_line':
        final note = await _note(
          a['note_id'] as String, a['expected_title'] as String);
        final edited = ViktorNoteLinePatch.apply(
          db.parseNoteDocument(note),
          lineNumber: a['line_number'] as int,
          expectedText: a['expected_text'] as String,
          replacement: a['text'] as String,
        );
        // The proposed preview carries a fingerprint of the WHOLE original
        // document. The executor re-evaluates it before applying the write.
        final originalVersion = (note.notesDeltaJson ?? '').hashCode
            .toUnsigned(32).toRadixString(16);
        return 'Заменить строку ${a['line_number']} в заметке «${note.title}» '
            '(версия $originalVersion): «${a['expected_text']}» → '
            '«${a['text']}». Остальной текст и вложения сохраняются. '
            'Блоков: ${edited.blocks.length}.';
      case 'edit_note':
        final note = await _note(
          a['note_id'] as String, a['expected_title'] as String);
        if (db.parseNoteDocument(note).blocks.any(
            (b) => !b.type.isTextual)) {
          throw StateError('Заметка содержит вложения: нельзя заменить '
              'её целиком без потерь.');
        }
        // Re-rendered just before execution by ViktorExecutor. Including
        // the server/cached document fingerprint in the *approved preview*
        // rejects edits made after user consent even when the title matches.
        final fingerprint = (note.notesDeltaJson ?? '').hashCode
            .toUnsigned(32).toRadixString(16);
        return 'Заменить текст заметки «' + note.title +
            '» (версия документа: ' + fingerprint +
            ') на:\n' + (a['text'] as String);
      case 'create_path':
        final category = _category(a['category_id'] as String);
        if (category == null || category.backendRowId == null) {
          throw StateError('Неизвестная категория Пути.');
        }
        final stages = a['stages'] as List;
        return 'Создать Путь «' + (a['name'] as String) +
          '», этапов ' + stages.length.toString() +
          '. Цель: ' + (a['goal'] as String) + '.';
      case 'change_setting':
        final field = a['field'] as String;
        final value = _safeSetting(field, a['value'] as String);
        return 'Изменить настройку ' + field + ' на «' + value + '».';
      default:
        throw StateError('Неподдерживаемый инструмент.');
    }
  }

  Future<String> execute(ViktorAction tool) async {
    final a = tool.arguments;
    if (reads.contains(tool.name)) return preview(tool);
    switch (tool.name) {
      case 'set_list_item_done':
        final item = await _listItem(
          a['item_id'] as String, a['expected_title'] as String,
          expectedDone: a['expected_is_done'] as bool);
        final changed = await db.updatePlanningTask(
          item.recordIdForBackend, planBusinessId: item.planRowId,
          isDone: a['is_done'] as bool, suppressAppSnack: true);
        if (!changed) throw StateError('Статус элемента не сохранился.');
        return a['is_done'] == true ? 'Задача завершена.' : 'Задача возобновлена.';
      case 'rename_list_item':
        final item = await _listItem(
          a['item_id'] as String, a['expected_title'] as String);
        final changed = await db.updatePlanningTask(
          item.recordIdForBackend, planBusinessId: item.planRowId,
          title: a['title'] as String, suppressAppSnack: true);
        if (!changed) throw StateError('Название элемента не сохранилось.');
        return 'Элемент списка переименован.';
      case 'create_tag':
        final name = a['name'] as String;
        final domain = a['domain'] as String;
        if ((await _tags(domain)).any((t) =>
            t.name.toLowerCase() == name.toLowerCase())) {
          throw StateError('Тег уже существует.');
        }
        final tag = await db.createTagForCurrentUser(
          name: name, colorHex: '#FFB71C1C', iconKey: '', domain: domain);
        if (tag == null) throw StateError('Не удалось сохранить тег.');
        return 'Создан тег «' + name + '».';
      case 'rename_tag':
        final tags = [...await _tags('plan'), ...await _tags('list')];
        final found = tags.where((t) =>
          t.pbRecordId == a['tag_id'] && t.name == a['expected_name']);
        if (found.length != 1) throw StateError('Тег изменился.');
        final t = found.single;
        final ok = await db.patchTagForCurrentUser(
          pocketRecordId: t.pbRecordId!, name: a['name'] as String,
          colorHex: t.color ?? '#FFB71C1C', iconKey: t.icon ?? '');
        if (!ok) throw StateError('Не удалось переименовать тег.');
        return 'Тег переименован.';
      case 'create_category':
        final parent = a['parent_category_id'] as String?;
        final category = parent == null ? null : _category(parent);
        if (parent != null && category == null) {
          throw StateError('Родительская категория исчезла.');
        }
        final ok = await db.addNestedCategory(category?.id,
          CategoryRule(id: 0, name: a['name'] as String));
        if (ok == null) throw StateError('Не удалось создать категорию.');
        return 'Категория создана.';
      case 'create_note':
        final category = _category(a['category_id'] as String?);
        if (category == null) throw StateError('Категория отсутствует.');
        final text = a['text'] as String;
        final doc = NoteDocument(blocks: [
          for (final line in text.split('\n'))
            NoteBlock(id: generateNoteBlockId(),
              type: NoteBlockType.paragraph, text: line),
        ]);
        final ok = await db.addPlanningTask(PlanningTask(
          id: 0, title: a['title'] as String,
          categoryId: category.id, dateKey: '',
          order: await db.nextBacklogPlanningOrder(),
          notesPlain: text, notesDeltaJson: doc.encode()));
        if (!ok) throw StateError('Заметка не сохранена.');
        return 'Заметка создана.';
      case 'edit_note_line':
        final note = await _note(a['note_id'] as String,
            a['expected_title'] as String);
        final edited = ViktorNoteLinePatch.apply(db.parseNoteDocument(note),
          lineNumber: a['line_number'] as int,
          expectedText: a['expected_text'] as String,
          replacement: a['text'] as String);
        final ok = await db.updatePlanningTask(note.recordIdForBackend,
          planBusinessId: note.planRowId,
          notesPlain: edited.toPlainText(),
          notesDeltaJson: edited.encode(),
          suppressAppSnack: true);
        if (!ok) throw StateError('Правка строки не сохранилась.');
        return 'Строка ${a['line_number']} обновлена; остальные блоки '
            'и вложения сохранены.';
      case 'edit_note':
        final note = await _note(a['note_id'] as String,
            a['expected_title'] as String);
        final existingDoc = db.parseNoteDocument(note);
        if (existingDoc.blocks.any((b) => !b.type.isTextual)) {
          throw StateError('Заметка содержит вложения.');
        }
        final text = a['text'] as String;
        final doc = NoteDocument(meta: existingDoc.meta, blocks: [
          for (final line in text.split('\n'))
            NoteBlock(id: generateNoteBlockId(),
              type: NoteBlockType.paragraph, text: line),
        ]);
        final ok = await db.updatePlanningTask(note.recordIdForBackend,
          planBusinessId: note.planRowId,
          notesPlain: text, notesDeltaJson: doc.encode(),
          suppressAppSnack: true);
        if (!ok) throw StateError('Заметка не обновлена.');
        return 'Текст заметки обновлён.';
      case 'create_path':
        final category = _category(a['category_id'] as String);
        if (category == null || category.backendRowId == null) {
          throw StateError('Категория Пути недоступна.');
        }
        final stages = <PathStageSnapshot>[];
        var n = 0;
        for (final raw in a['stages'] as List) {
          final stage = Map<String, Object?>.from(raw as Map);
          final actions = <PathActionSnapshot>[];
          var m = 0;
          for (final rawAction in stage['actions'] as List) {
            final task = Map<String, Object?>.from(rawAction as Map);
            actions.add(PathActionSnapshot(
              id: 'viktor-action-' + n.toString() + '-' + m.toString(),
              text: task['text'] as String,
              expectedResult: task['result'] as String,
              minutes: task['minutes'] as int,
              track: 'execution', isDone: false));
            m++;
          }
          stages.add(PathStageSnapshot(
            id: 'viktor-stage-' + n.toString(),
            title: stage['title'] as String,
            completionCriteria: stage['criteria'] as String,
            isDone: false, actions: actions));
          n++;
        }
        final created = await _paths.createPath(
          category: category, goal: a['goal'] as String,
          stages: stages, name: a['name'] as String, source: 'ai');
        if (created == null) throw StateError('Не удалось создать Путь.');
        return 'Создан Путь «' + created.name + '».';
      case 'change_setting':
        final s = db.settings;
        final field = a['field'] as String;
        final value = _safeSetting(field, a['value'] as String);
        final updated = switch (field) {
          'theme_mode' => s.copyWith(themeMode: value),
          'preferred_timezone' => s.copyWith(preferredTimeZone: value),
          'primary_language' => s.copyWith(
            primaryLanguage: value, language: value),
          'list_completion_behavior' => s.copyWith(
            listCompletionBehavior: value),
          'display_name' => s.copyWith(displayName: value),
          _ => throw StateError('Настройка запрещена.'),
        };
        if (!await db.saveSettings(updated)) {
          throw StateError('Настройка не сохранилась.');
        }
        return 'Настройка обновлена.';
      default:
        throw StateError('Инструмент не поддерживается.');
    }
  }
}
