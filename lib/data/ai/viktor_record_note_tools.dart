import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/pb_config.dart';

/// Historic record notes are distinct from the Notes library. Read directly
/// through the current user's PocketBase rules; the model never receives
/// credentials, unrestricted queries, or a way to write records.
class ViktorRecordNoteTools {
  const ViktorRecordNoteTools(this.db);
  final DatabaseService db;

  String _owner() {
    final id = db.pocketBase.authStore.record?.id ?? '';
    if (id.isEmpty || db.pocketBase.authStore.token.isEmpty) {
      throw StateError('Необходим вход в LIFE OS.');
    }
    return id;
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _noteDelta(Object? value) {
    if (value == null) return '';
    return value is String ? value : jsonEncode(value);
  }

  static NoteDocument _document(Map<String, dynamic> row) =>
      NoteDocument.tryParse(
        notesDeltaJson: _noteDelta(row['notes_delta']),
        notesPlain: row['note']?.toString(),
      );

  /// By creation date, not task start time. A record's start_time is not proof
  /// of when a poem was written; return both timestamps when available.
  Future<String> search({
    String query = '',
    int? year,
    int? month,
    int limit = 20,
  }) async {
    await db.ensurePocketBaseReady();
    final owner = _owner();
    var filter = 'user_id = "$owner"';
    if (year != null) {
      final from = DateTime.utc(year, month ?? 1);
      final until = DateTime.utc(year, month == null ? 13 : month + 1);
      filter += ' && created >= "${_date(from)} 00:00:00.000Z"'
          ' && created < "${_date(until)} 00:00:00.000Z"';
    }
    final rows = await db.pocketBase.collection(PbCollections.records)
        .getFullList(filter: filter, batch: 200);
    final needle = query.toLowerCase().trim();
    final hits = <String>[];
    for (final record in rows) {
      if (record.data['user_id']?.toString() != owner) continue;
      final doc = _document(record.data);
      final content = doc.toPlainText();
      final title = record.data['title']?.toString() ?? '';
      if (content.trim().isEmpty) continue;
      if (needle.isNotEmpty &&
          !content.toLowerCase().contains(needle) &&
          !title.toLowerCase().contains(needle)) continue;
      final created = DateTime.tryParse(record.created)?.toLocal();
      final date = created == null ? 'неизвестно' : _date(created);
      final begin = record.data['start_time']?.toString() ?? '';
      final snippet = content.replaceAll(RegExp(r'\s+'), ' ').trim();
      hits.add('id=${record.id}; тип=запись; создано=$date; '
          'название=$title; дата записи=$begin; '
          'отрывок=${snippet.length > 180 ? snippet.substring(0, 180) : snippet}');
      if (hits.length >= limit) break;
    }
    if (hits.isEmpty) return 'Совпадений в содержимом исторических '
        'записей за указанный период нет.';
    return 'Совпадения в исторических записях:\n${hits.join('\n')}\n'
        'Откройте read_record_note по точному ID для цитирования.';
  }

  Future<String> read(String id) async {
    await db.ensurePocketBaseReady();
    final owner = _owner();
    final record = await db.pocketBase.collection(PbCollections.records)
        .getOne(id);
    if (record.data['user_id']?.toString() != owner) {
      throw StateError('Запись другого пользователя недоступна.');
    }
    final doc = _document(record.data);
    final lines = <String>[];
    var lineNumber = 0;
    for (final block in doc.blocks) {
      if (!block.type.isTextual) {
        lines.add('[Вложение ${block.type.name} — не текст]');
        continue;
      }
      for (final line in block.effectiveText.split('\n')) {
        if (line.trim().isEmpty) continue;
        lineNumber++;
        lines.add('Строка $lineNumber: $line');
      }
    }
    final all = lines.join('\n');
    final preview = all.length > 7500 ? all.substring(0, 7500) : all;
    return 'Запись «${record.data['title']}», id=$id, '
        'создана=${record.created}.\n'
        'Нумерация непустых текстовых строк:\n$preview'
        '${preview.length < all.length ? '\n[Текст обрезан]' : ''}';
  }
}
