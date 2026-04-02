// ignore_for_file: avoid_print
//
// One-off: set PocketBase `user_id` on rows to the **auth profile record id**
// (matches @request.auth.id and Brain filters after _pidForPbFix).
//
// Aggressive mode: loads **every page** (perPage BATCH), normalizes relation-shaped
// `user_id`, and PATCHes whenever stored owner id ≠ target (including empty/null).
// Per-row failures are logged; the run continues.
//
// Run:
//   set PB_ADMIN_EMAIL=...
//   set PB_ADMIN_PASSWORD=...
//   set ALIGN_TARGET_USER_ID=xhjy54inue73piz   (optional; default below)
//   set ALIGN_LIST_BATCH=500                     (optional)
//   dart run tool/align_pb_user_id.dart
//
// Env: PB_BASE_URL, PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD

import 'dart:io';

import 'package:counter/data/pb_config.dart';
import 'package:pocketbase/pocketbase.dart';

const _defaultTargetId = 'xhjy54inue73piz';

/// PocketBase may return relation `user_id` as id string, empty, or wrapped.
String _normalizeRowUserId(RecordModel r) {
  final v = r.data['user_id'];
  if (v == null) return '';
  if (v is String) return v.trim();
  if (v is List) {
    if (v.isEmpty) return '';
    return v.first.toString().trim();
  }
  if (v is Map) {
    final id = v['id'] ?? v['recordId'];
    if (id != null) return id.toString().trim();
  }
  return v.toString().trim();
}

Future<List<RecordModel>> _listEveryRow(
  PocketBase pb,
  String collection, {
  required int batch,
}) async {
  final out = <RecordModel>[];
  var page = 1;
  while (true) {
    final pageResult = await pb.collection(collection).getList(
          page: page,
          perPage: batch,
        );
    out.addAll(pageResult.items);
    if (pageResult.items.length < batch) break;
    page++;
  }
  return out;
}

Future<void> main() async {
  final baseStr =
      (Platform.environment['PB_BASE_URL'] ?? kPocketBaseUrl)
          .replaceAll(RegExp(r'/$'), '');
  final email = (Platform.environment['PB_ADMIN_EMAIL'] ?? '').trim();
  final password = (Platform.environment['PB_ADMIN_PASSWORD'] ?? '').trim();
  final target = (Platform.environment['ALIGN_TARGET_USER_ID'] ?? _defaultTargetId)
      .trim();
  final batch = int.tryParse(
        (Platform.environment['ALIGN_LIST_BATCH'] ?? '500').trim(),
      ) ??
      500;
  if (batch < 1) {
    stderr.writeln('ALIGN_LIST_BATCH must be >= 1.');
    exit(1);
  }

  if (email.isEmpty || password.isEmpty) {
    stderr.writeln('Set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD.');
    exit(1);
  }
  if (target.isEmpty) {
    stderr.writeln('ALIGN_TARGET_USER_ID is empty.');
    exit(1);
  }

  final pb = PocketBase(baseStr);
  print('Admin auth at $baseStr …');
  try {
    // ignore: deprecated_member_use
    await pb.admins.authWithPassword(email, password);
  } on ClientException catch (e) {
    if (e.statusCode != 404) rethrow;
    final data = await pb.send<Map<String, dynamic>>(
      '/api/admins/auth-with-password',
      method: 'POST',
      body: <String, String>{'identity': email, 'password': password},
    );
    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) {
      stderr.writeln('Admin auth: empty token');
      exit(1);
    }
    final raw = data['record'] ?? data['admin'];
    RecordModel? model;
    if (raw is Map<String, dynamic>) {
      model = RecordModel.fromJson(raw);
    }
    pb.authStore.save(token, model);
  }

  print('Target user_id (profiles auth id): $target');
  print('List batch (perPage): $batch\n');

  for (final name in [
    PbCollections.records,
    PbCollections.categories,
    PbCollections.plans,
    PbCollections.tags,
  ]) {
    var updated = 0;
    var skipped = 0;
    var failed = 0;
    try {
      final list = await _listEveryRow(pb, name, batch: batch);
      for (final r in list) {
        final cur = _normalizeRowUserId(r);
        if (cur == target) {
          skipped++;
          continue;
        }
        try {
          await pb.collection(name).update(
                r.id,
                body: <String, dynamic>{'user_id': target},
              );
          updated++;
          print('  $name ${r.id}: "$cur" → $target');
        } on ClientException catch (e) {
          failed++;
          stderr.writeln(
            '  FAIL $name ${r.id}: ${e.statusCode} ${e.response} (was "$cur")',
          );
        } catch (e) {
          failed++;
          stderr.writeln('  FAIL $name ${r.id}: $e (was "$cur")');
        }
      }
    } on ClientException catch (e) {
      stderr.writeln('$name list: ${e.statusCode} ${e.response}');
      continue;
    } catch (e) {
      stderr.writeln('$name list: $e');
      continue;
    }
    print(
      '$name: updated=$updated unchanged=$skipped failed=$failed '
      'total=${updated + skipped + failed}',
    );
  }
  print('\nDone.');
}
