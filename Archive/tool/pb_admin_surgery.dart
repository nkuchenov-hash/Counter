// ignore_for_file: avoid_print
//
// Emergency PocketBase admin repair:
// 1) PATCH API rules on records, categories, plans, tags.
// 2) PATCH records schema: category_link.options.cascadeDelete = true (always re-applied).
// 3) "Dumb" ownership: NO comparison — every row gets PATCH body ONLY {"user_id": "<target>"}.
//
// Uses raw HTTP + admin Bearer token for list/PATCH so emails / relation shapes cannot be "missed".
//
// Env: PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD
// Optional: PB_BASE_URL, ALIGN_TARGET_USER_ID (default xhjy54inue73piz), ALIGN_LIST_BATCH (default 500)
//
//   dart run tool/pb_admin_surgery.dart

import 'dart:convert';
import 'dart:io';

import 'package:counter/data/pb_config.dart';
import 'package:http/http.dart' as http;

const String kPbOwnerRule = r'user_id = @request.auth.id';

String _env(String k, String d) {
  final v = Platform.environment[k];
  if (v == null) return d;
  final t = v.trim();
  return t.isEmpty ? d : t;
}

Map<String, String> _hdr(String token) => {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

Future<String> _adminAuthHttp(Uri base, String email, String password) async {
  final paths = <String>[
    '/api/collections/_superusers/auth-with-password',
    '/api/admins/auth-with-password',
  ];
  for (final p in paths) {
    final res = await http.post(
      base.replace(path: p),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(<String, String>{
        'identity': email,
        'password': password,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final t = m['token']?.toString() ?? '';
      if (t.isNotEmpty) return t;
    } else {
      stderr.writeln('$p → ${res.statusCode} ${res.body}');
    }
  }
  stderr.writeln('Admin auth failed.');
  exit(1);
}

Future<List<Map<String, dynamic>>> _listCollections(
  Uri base,
  String token,
) async {
  final res = await http.get(
    base.replace(path: '/api/collections'),
    headers: _hdr(token),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    stderr.writeln('GET /api/collections ${res.statusCode}: ${res.body}');
    exit(1);
  }
  final items =
      (jsonDecode(res.body) as Map<String, dynamic>)['items'] as List? ?? [];
  return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

String? _metaIdByName(List<Map<String, dynamic>> items, String name) {
  for (final e in items) {
    if (e['name'] == name) return e['id']?.toString();
  }
  return null;
}

Future<void> _patchCollectionRules(
  Uri base,
  String token,
  String metaId,
  String label,
) async {
  final res = await http.patch(
    base.replace(path: '/api/collections/$metaId'),
    headers: _hdr(token),
    body: jsonEncode(<String, String>{
      'listRule': kPbOwnerRule,
      'viewRule': kPbOwnerRule,
      'createRule': kPbOwnerRule,
      'updateRule': kPbOwnerRule,
      'deleteRule': kPbOwnerRule,
    }),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    stderr.writeln('PATCH rules $label ${res.statusCode}: ${res.body}');
    exit(1);
  }
  print('  rules unlocked: $label');
}

/// Always set cascadeDelete true on [category_link] and PATCH (idempotent).
Future<void> _forceRecordsCategoryLinkCascade(
  Uri base,
  String token,
  String recordsMetaId,
) async {
  final resGet = await http.get(
    base.replace(path: '/api/collections/$recordsMetaId'),
    headers: _hdr(token),
  );
  if (resGet.statusCode < 200 || resGet.statusCode >= 300) {
    stderr.writeln('GET records collection ${resGet.statusCode}: ${resGet.body}');
    exit(1);
  }
  final coll = jsonDecode(resGet.body) as Map<String, dynamic>;
  final schema = List<dynamic>.from(coll['schema'] as List? ?? []);
  var found = false;
  for (var i = 0; i < schema.length; i++) {
    final raw = schema[i];
    if (raw is! Map) continue;
    final f = Map<String, dynamic>.from(raw);
    if (f['name']?.toString() != kPbRecordCategoryExpand) continue;
    if (f['type']?.toString() != 'relation') continue;
    found = true;
    final opts = Map<String, dynamic>.from(
      (f['options'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
    opts['cascadeDelete'] = true;
    f['options'] = opts;
    schema[i] = f;
  }
  if (!found) {
    stderr.writeln(
      'Field $kPbRecordCategoryExpand not found on records — check collection name.',
    );
    exit(1);
  }
  final res = await http.patch(
    base.replace(path: '/api/collections/$recordsMetaId'),
    headers: _hdr(token),
    body: jsonEncode(<String, dynamic>{'schema': schema}),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    stderr.writeln(
      'PATCH records schema (cascade) ${res.statusCode}: ${res.body}',
    );
    exit(1);
  }
  print('  records.$kPbRecordCategoryExpand: cascadeDelete=true (forced)');
}

/// Dumb sweep: PATCH every record id; body is ONLY user_id (no read/compare).
Future<void> _brutePatchUserIdEveryRow(
  Uri base,
  String token,
  String collectionName,
  String targetUserId,
  int batch,
) async {
  var page = 1;
  var patched = 0;
  var failed = 0;
  for (;;) {
    final listUri = base.replace(
      path: '/api/collections/$collectionName/records',
      queryParameters: <String, String>{
        'page': '$page',
        'perPage': '$batch',
      },
    );
    final listRes = await http.get(listUri, headers: _hdr(token));
    if (listRes.statusCode < 200 || listRes.statusCode >= 300) {
      stderr.writeln(
        'GET list $collectionName page=$page ${listRes.statusCode}: ${listRes.body}',
      );
      break;
    }
    final decoded = jsonDecode(listRes.body) as Map<String, dynamic>;
    final items = decoded['items'] as List? ?? [];
    for (final raw in items) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final patchUri = base.replace(
        path: '/api/collections/$collectionName/records/$id',
      );
      final patchRes = await http.patch(
        patchUri,
        headers: _hdr(token),
        body: jsonEncode(<String, String>{'user_id': targetUserId}),
      );
      if (patchRes.statusCode >= 200 && patchRes.statusCode < 300) {
        patched++;
      } else {
        failed++;
        stderr.writeln(
          'FAIL PATCH $collectionName/$id ${patchRes.statusCode}: ${patchRes.body}',
        );
      }
    }
    if (items.length < batch) break;
    page++;
  }
  print('$collectionName: brute PATCH ok=$patched failed=$failed');
}

Future<void> main() async {
  final baseStr =
      _env('PB_BASE_URL', kPocketBaseUrl).replaceAll(RegExp(r'/$'), '');
  final email = _env('PB_ADMIN_EMAIL', '');
  final password = _env('PB_ADMIN_PASSWORD', '');
  final target = _env('ALIGN_TARGET_USER_ID', 'xhjy54inue73piz');
  final batch = int.tryParse(_env('ALIGN_LIST_BATCH', '500')) ?? 500;

  if (email.isEmpty || password.isEmpty) {
    stderr.writeln(
      'Set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD (never commit them).',
    );
    exit(1);
  }
  if (target.isEmpty) {
    stderr.writeln('ALIGN_TARGET_USER_ID is empty.');
    exit(1);
  }
  if (batch < 1) {
    stderr.writeln('ALIGN_LIST_BATCH must be >= 1.');
    exit(1);
  }

  final base = Uri.parse(baseStr);
  print('pb_admin_surgery (dumb PATCH) @ $baseStr');
  print('Target user_id: $target\n');

  final token = await _adminAuthHttp(base, email, password);
  print('Admin HTTP token OK.\n');

  final items = await _listCollections(base, token);
  final names = <String>[
    PbCollections.records,
    PbCollections.categories,
    PbCollections.plans,
    PbCollections.tags,
  ];

  print('1) Force-unlock API rules…');
  for (final n in names) {
    final id = _metaIdByName(items, n);
    if (id == null || id.isEmpty) {
      stderr.writeln('Missing collection: $n');
      exit(1);
    }
    await _patchCollectionRules(base, token, id, n);
  }

  print('\n2) records.$kPbRecordCategoryExpand cascade (forced)…');
  final recordsMeta = _metaIdByName(items, PbCollections.records);
  if (recordsMeta == null || recordsMeta.isEmpty) exit(1);
  await _forceRecordsCategoryLinkCascade(base, token, recordsMeta);

  print('\n3) Brute user_id PATCH (every row, body ONLY user_id)…');
  for (final name in names) {
    await _brutePatchUserIdEveryRow(base, token, name, target, batch);
  }

  print('\npb_admin_surgery: done.');
}
