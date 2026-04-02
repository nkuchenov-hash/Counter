// ignore_for_file: avoid_print
//
// One-shot Noco → PocketBase import for **tags** + **plans** (DATA_MAP field names).
//
// Run from repo root:
//   PB_ADMIN_EMAIL=… PB_ADMIN_PASSWORD=… MIGRATION_USER_ID=<profile_uuid> dart run tools/migrate_to_pb.dart [tags.csv] [plans.csv]
//
// Defaults: <this_script_dir>/sample_data/tags.csv and plans.csv (cwd-independent).
// Replace REPLACE_USER_UUID in sample CSVs with MIGRATION_USER_ID (or export does it here).

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:counter/data/pb_config.dart';

const _adminAuthPath = '/api/admins/auth-with-password';
const _collectionsPath = '/api/collections';
const _collectionRecords = '/api/collections';

Future<void> main(List<String> args) async {
  final adminEmail =
      Platform.environment['PB_ADMIN_EMAIL']?.trim().isNotEmpty == true
          ? Platform.environment['PB_ADMIN_EMAIL']!.trim()
          : 'admin@admin.local';
  final adminPass =
      Platform.environment['PB_ADMIN_PASSWORD']?.trim().isNotEmpty == true
          ? Platform.environment['PB_ADMIN_PASSWORD']!.trim()
          : 'secret';
  final migrationUserId =
      Platform.environment['MIGRATION_USER_ID']?.trim().isNotEmpty == true
          ? Platform.environment['MIGRATION_USER_ID']!.trim()
          : '';

  if (migrationUserId.isEmpty) {
    stderr.writeln(
      'Set MIGRATION_USER_ID to the app profile UUID (same as plans.user_id / tags.user_id).',
    );
    exit(1);
  }

  final sep = Platform.pathSeparator;
  final toolsDir = File(Platform.script.toFilePath()).parent.path;
  final sampleDir = '$toolsDir${sep}sample_data';
  final defaultTagsCsv = '$sampleDir${sep}tags.csv';
  final defaultPlansCsv = '$sampleDir${sep}plans.csv';
  final tagsPath = args.isNotEmpty ? args[0] : defaultTagsCsv;
  final plansPath = args.length > 1 ? args[1] : defaultPlansCsv;

  final tagFile = File(tagsPath);
  final planFile = File(plansPath);
  if (!tagFile.existsSync()) {
    stderr.writeln('Missing tags CSV: $tagsPath');
    exit(1);
  }
  if (!planFile.existsSync()) {
    stderr.writeln('Missing plans CSV: $plansPath');
    exit(1);
  }

  final token = await _adminAuth(
    Uri.parse(kPocketBaseUrl),
    adminEmail,
    adminPass,
  );
  await _ensureCollections(Uri.parse(kPocketBaseUrl), token);

  final oldTagBizToPbId = <int, String>{};
  await _importTags(
    base: Uri.parse(kPocketBaseUrl),
    token: token,
    csvPath: tagFile,
    userId: migrationUserId,
    oldTagBizToPbId: oldTagBizToPbId,
  );

  await _importPlans(
    base: Uri.parse(kPocketBaseUrl),
    token: token,
    csvPath: planFile,
    userId: migrationUserId,
    oldTagBizToPbId: oldTagBizToPbId,
  );

  print('Migration Complete');
}

Map<String, String> _authHeaders(String token) => <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

Future<String> _adminAuth(Uri base, String email, String password) async {
  final uri = base.replace(path: _adminAuthPath);
  final res = await http.post(
    uri,
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode(<String, String>{
      'identity': email,
      'password': password,
    }),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    stderr.writeln('Admin auth failed ${res.statusCode}: ${res.body}');
    exit(1);
  }
  final m = jsonDecode(res.body) as Map<String, dynamic>;
  final t = m['token']?.toString() ?? '';
  if (t.isEmpty) {
    stderr.writeln('Admin auth: no token');
    exit(1);
  }
  return t;
}

Future<void> _ensureCollections(Uri base, String token) async {
  final res = await http.get(
    base.replace(path: _collectionsPath),
    headers: _authHeaders(token),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    stderr.writeln('List collections failed: ${res.statusCode} ${res.body}');
    exit(1);
  }
  final list = (jsonDecode(res.body) as Map<String, dynamic>)['items'] as List?;
  final names = <String>{};
  if (list != null) {
    for (final e in list) {
      if (e is Map && e['name'] != null) {
        names.add(e['name'].toString());
      }
    }
  }
  if (!names.contains('tags')) {
    await _createCollection(base, token, _tagsSchemaBody());
    print('Created collection: tags');
  } else {
    print('Collection exists: tags');
  }
  // Refresh ids after possible create
  final tagsId = await _collectionIdByName(base, token, 'tags');
  if (tagsId == null) {
    stderr.writeln('Could not resolve tags collection id');
    exit(1);
  }
  if (!names.contains('plans')) {
    await _createCollection(base, token, _plansSchemaBody(tagsCollectionId: tagsId));
    print('Created collection: plans');
  } else {
    print('Collection exists: plans');
  }
}

Future<String?> _collectionIdByName(Uri base, String token, String name) async {
  final res = await http.get(
    base.replace(path: _collectionsPath),
    headers: _authHeaders(token),
  );
  final list = (jsonDecode(res.body) as Map<String, dynamic>)['items'] as List?;
  if (list == null) return null;
  for (final e in list) {
    if (e is Map && e['name'] == name) {
      return e['id']?.toString();
    }
  }
  return null;
}

Future<void> _createCollection(Uri base, String token, Map<String, dynamic> body) async {
  final res = await http.post(
    base.replace(path: _collectionsPath),
    headers: _authHeaders(token),
    body: jsonEncode(body),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    stderr.writeln('Create collection failed ${res.statusCode}: ${res.body}');
    exit(1);
  }
}

Map<String, dynamic> _tagsSchemaBody() => <String, dynamic>{
      'name': 'tags',
      'type': 'base',
      'schema': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'tag_id',
          'type': 'number',
          'required': true,
          'options': <String, dynamic>{},
        },
        <String, dynamic>{
          'name': 'user_id',
          'type': 'text',
          'required': true,
        },
        <String, dynamic>{
          'name': 'name',
          'type': 'text',
          'required': true,
        },
        <String, dynamic>{
          'name': 'color',
          'type': 'text',
          'required': false,
        },
        <String, dynamic>{
          'name': 'icon',
          'type': 'text',
          'required': false,
        },
      ],
      'listRule': "",
      'viewRule': "",
      'createRule': "",
      'updateRule': "",
      'deleteRule': "",
    };

Map<String, dynamic> _plansSchemaBody({required String tagsCollectionId}) =>
    <String, dynamic>{
      'name': 'plans',
      'type': 'base',
      'schema': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'plan_id', 'type': 'text', 'required': true},
        <String, dynamic>{'name': 'user_id', 'type': 'text', 'required': true},
        <String, dynamic>{'name': 'category_id', 'type': 'text', 'required': true},
        <String, dynamic>{'name': 'title', 'type': 'text', 'required': true},
        <String, dynamic>{'name': 'is_done', 'type': 'bool', 'required': false},
        <String, dynamic>{'name': 'is_priority', 'type': 'bool', 'required': false},
        <String, dynamic>{'name': 'start_time', 'type': 'text', 'required': false},
        <String, dynamic>{'name': 'end_time', 'type': 'text', 'required': false},
        <String, dynamic>{'name': 'parent_plan_id', 'type': 'text', 'required': false},
        <String, dynamic>{
          'name': 'checklist',
          'type': 'json',
          'required': false,
          // PocketBase v0.22+ requires maxSize on json fields (validation_required).
          'options': <String, dynamic>{'maxSize': 2000000},
        },
        <String, dynamic>{'name': 'order', 'type': 'number', 'required': false},
        <String, dynamic>{'name': 'note', 'type': 'text', 'required': false},
        <String, dynamic>{
          'name': 'tags_link',
          'type': 'relation',
          'required': false,
          'options': <String, dynamic>{
            'collectionId': tagsCollectionId,
            'maxSelect': 200,
            'cascadeDelete': false,
          },
        },
      ],
      'listRule': "",
      'viewRule': "",
      'createRule': "",
      'updateRule': "",
      'deleteRule': "",
    };

/// CSV boolean: only `"1"` or `"true"` (case-insensitive) → true; empty or anything else → false.
bool _csvBoolTrue(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  if (s.isEmpty) return false;
  return s == 'true' || s == '1';
}

List<Map<String, String>> _parseCsv(File f) {
  final lines =
      f.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return [];
  final header = _splitCsvLine(lines.first);
  final out = <Map<String, String>>[];
  for (var i = 1; i < lines.length; i++) {
    final vals = _splitCsvLine(lines[i]);
    final row = <String, String>{};
    for (var j = 0; j < header.length; j++) {
      row[header[j]] = j < vals.length ? vals[j] : '';
    }
    out.add(row);
  }
  return out;
}

List<String> _splitCsvLine(String line) {
  final out = <String>[];
  final sb = StringBuffer();
  var inQ = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQ = !inQ;
      continue;
    }
    if (!inQ && c == ',') {
      out.add(sb.toString());
      sb.clear();
    } else {
      sb.write(c);
    }
  }
  out.add(sb.toString());
  return out;
}

Future<void> _importTags({
  required Uri base,
  required String token,
  required File csvPath,
  required String userId,
  required Map<int, String> oldTagBizToPbId,
}) async {
  final rows = _parseCsv(csvPath);
  for (final r in rows) {
    var uid = (r['user_id'] ?? '').trim();
    if (uid == 'REPLACE_USER_UUID') uid = userId;
    final biz = int.tryParse(r['tag_id'] ?? '') ?? 0;
    final body = <String, dynamic>{
      'tag_id': biz,
      'user_id': uid,
      'name': r['name'] ?? '',
      'color': r['color'],
      'icon': r['icon'],
    };
    body.removeWhere((k, v) => v == null || (v is String && v.isEmpty && k != 'name'));
    final uri = base.replace(path: '$_collectionRecords/tags/records');
    final res = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      stderr.writeln('Tag import failed $biz: ${res.statusCode} ${res.body}');
      continue;
    }
    final id = (jsonDecode(res.body) as Map<String, dynamic>)['id']?.toString();
    if (id != null && biz > 0) {
      oldTagBizToPbId[biz] = id;
      print('Tag $biz -> PB id $id');
    }
  }
}

Future<void> _importPlans({
  required Uri base,
  required String token,
  required File csvPath,
  required String userId,
  required Map<int, String> oldTagBizToPbId,
}) async {
  final rows = _parseCsv(csvPath);
  for (final r in rows) {
    var uid = (r['user_id'] ?? '').trim();
    if (uid == 'REPLACE_USER_UUID') uid = userId;
    final oldTagSpec = (r['old_tag_ids'] ?? '').trim();
    final linkIds = <String>[];
    if (oldTagSpec.isNotEmpty) {
      for (final part in oldTagSpec.split('|')) {
        final n = int.tryParse(part.trim()) ?? 0;
        final pb = oldTagBizToPbId[n];
        if (pb != null) linkIds.add(pb);
      }
    }
    final body = <String, dynamic>{
      'plan_id': r['plan_id'] ?? '',
      'user_id': uid,
      'category_id': r['category_id'] ?? '',
      'title': r['title'] ?? '',
      'is_done': _csvBoolTrue(r['is_done']),
      'is_priority': _csvBoolTrue(r['is_priority']),
      'order': num.tryParse(r['order'] ?? '0')?.toInt() ?? 0,
      if ((r['start_time'] ?? '').trim().isNotEmpty) 'start_time': r['start_time'],
      if ((r['end_time'] ?? '').trim().isNotEmpty) 'end_time': r['end_time'],
      if ((r['parent_plan_id'] ?? '').trim().isNotEmpty)
        'parent_plan_id': r['parent_plan_id'],
      if ((r['note'] ?? '').trim().isNotEmpty) 'note': r['note'],
      'checklist': <dynamic>[],
    };
    if (linkIds.isNotEmpty) {
      body['tags_link'] = linkIds;
    }
    final uri = base.replace(path: '$_collectionRecords/plans/records');
    final res = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      stderr.writeln('Plan import failed: ${res.statusCode} ${res.body}');
      continue;
    }
    print('Imported plan ${r['plan_id']} tags=${linkIds.length}');
  }
}
