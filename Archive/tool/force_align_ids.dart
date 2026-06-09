// ignore_for_file: avoid_print
//
// Aggressive cleanup: force PocketBase `user_id` on every row in categories,
// records, plans, tags to the auth record id (default xhjy54inue73piz).
// Admin session lists all rows (no collection API rules).
//
// Run:
//   set PB_ADMIN_EMAIL=...
//   set PB_ADMIN_PASSWORD=...
//   set PB_BASE_URL=http://127.0.0.1:8090   (optional)
//   set FORCE_ALIGN_USER_ID=xhjy54inue73piz (optional; default below)
//   set FORCE_ALIGN_BATCH=500              (optional)
//   dart run tool/force_align_ids.dart

import 'dart:io';

import 'package:counter/data/pb_config.dart';
import 'package:pocketbase/pocketbase.dart';

const _forcedDefaultUserId = 'xhjy54inue73piz';

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
  final target = (Platform.environment['FORCE_ALIGN_USER_ID'] ??
          _forcedDefaultUserId)
      .trim();
  final batch = int.tryParse(
        (Platform.environment['FORCE_ALIGN_BATCH'] ?? '500').trim(),
      ) ??
      500;

  if (batch < 1) {
    stderr.writeln('FORCE_ALIGN_BATCH must be >= 1.');
    exit(1);
  }
  if (email.isEmpty || password.isEmpty) {
    stderr.writeln('Set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD.');
    exit(1);
  }
  if (target.isEmpty) {
    stderr.writeln('FORCE_ALIGN_USER_ID is empty.');
    exit(1);
  }

  final pb = PocketBase(baseStr);
  print('force_align_ids: admin auth at $baseStr …');
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

  print('Target user_id: $target');
  print('perPage: $batch\n');

  for (final name in [
    PbCollections.categories,
    PbCollections.records,
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
  print('\nforce_align_ids: done.');
}
