// ignore_for_file: avoid_print
//
// Creates PocketBase collections (profiles auth, categories, records, tags,
// plans) per DATA_MAP.md + POCKETBASE_MANIFEST.md when the instance is empty.
//
// Run:
//   dart run tool/bootstrap_pb_schema.dart
// Env: PB_BASE_URL, PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD
//
// Uses Admin HTTP API (collections CRUD). Relation fields are patched in a
// second step where self-references require the collection meta id.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:counter/data/pb_config.dart';

/// PocketBase List/View/Delete API rules: row owner must match signed-in auth record id.
const String kPbOwnerListViewRule = r'user_id = @request.auth.id';

Future<void> main() async {
  final baseStr =
      _env('PB_BASE_URL', kPocketBaseUrl).replaceAll(RegExp(r'/$'), '');
  final email = _env('PB_ADMIN_EMAIL', '');
  final password = _env('PB_ADMIN_PASSWORD', '');
  if (email.isEmpty || password.isEmpty) {
    stderr.writeln('Set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD.');
    exit(1);
  }

  final base = Uri.parse(baseStr);
  print('Bootstrap PB schema at $baseStr');
  final token = await _adminAuth(base, email, password);
  print('Admin token acquired.\n');

  var existing = await _listCollections(base, token);
  var names = existing.map((e) => e['name']?.toString() ?? '').toSet();

  String? profilesMetaId = _metaIdByName(existing, PbCollections.profiles);
  if (!names.contains(PbCollections.profiles)) {
    print('Creating auth collection "${PbCollections.profiles}"…');
    final body = _profilesAuthBody();
    profilesMetaId = await _createCollectionReturnId(base, token, body);
    print('  meta id: $profilesMetaId');
  } else {
    print('Collection exists: ${PbCollections.profiles} ($profilesMetaId)');
  }
  if (profilesMetaId == null || profilesMetaId.isEmpty) {
    stderr.writeln('Could not resolve profiles collection meta id.');
    exit(1);
  }

  existing = await _listCollections(base, token);
  names = existing.map((e) => e['name']?.toString() ?? '').toSet();

  String? categoriesMetaId = _metaIdByName(existing, PbCollections.categories);
  if (!names.contains(PbCollections.categories)) {
    print('Creating "${PbCollections.categories}" (no parent_id yet)…');
    final body = _categoriesBodyInitial(profilesCollectionId: profilesMetaId);
    categoriesMetaId = await _createCollectionReturnId(base, token, body);
    print('  meta id: $categoriesMetaId');
  } else {
    print('Collection exists: ${PbCollections.categories} ($categoriesMetaId)');
  }
  if (categoriesMetaId == null || categoriesMetaId.isEmpty) {
    stderr.writeln('Could not resolve categories collection meta id.');
    exit(1);
  }

  existing = await _listCollections(base, token);
  if (!_schemaHasField(existing, PbCollections.categories, 'parent_id')) {
    print('Patching "${PbCollections.categories}" → parent_id (self relation)…');
    await _patchCollectionAddParentCategory(
      base,
      token,
      categoriesMetaId,
      categoriesMetaId,
    );
  } else {
    print(' categories.parent_id already present.');
  }

  existing = await _listCollections(base, token);
  names = existing.map((e) => e['name']?.toString() ?? '').toSet();

  String? recordsMetaId = _metaIdByName(existing, PbCollections.records);
  if (!names.contains(PbCollections.records)) {
    print('Creating "${PbCollections.records}" (no parent_id yet)…');
    final body = _recordsBodyInitial(
      profilesCollectionId: profilesMetaId,
      categoriesCollectionId: categoriesMetaId,
    );
    recordsMetaId = await _createCollectionReturnId(base, token, body);
    print('  meta id: $recordsMetaId');
  } else {
    print('Collection exists: ${PbCollections.records} ($recordsMetaId)');
  }
  if (recordsMetaId == null || recordsMetaId.isEmpty) {
    stderr.writeln('Could not resolve records collection meta id.');
    exit(1);
  }

  existing = await _listCollections(base, token);
  if (!_schemaHasField(existing, PbCollections.records, 'parent_id')) {
    print('Patching "${PbCollections.records}" → parent_id (self relation)…');
    await _patchCollectionAddParentRecord(
      base,
      token,
      recordsMetaId,
      recordsMetaId,
    );
  } else {
    print(' records.parent_id already present.');
  }

  existing = await _listCollections(base, token);
  names = existing.map((e) => e['name']?.toString() ?? '').toSet();

  String? tagsMetaId = _metaIdByName(existing, PbCollections.tags);
  if (!names.contains(PbCollections.tags)) {
    print('Creating "${PbCollections.tags}"…');
    final body = _tagsBody(profilesCollectionId: profilesMetaId);
    tagsMetaId = await _createCollectionReturnId(base, token, body);
    print('  meta id: $tagsMetaId');
  } else {
    print('Collection exists: ${PbCollections.tags} ($tagsMetaId)');
  }
  if (tagsMetaId == null || tagsMetaId.isEmpty) {
    stderr.writeln('Could not resolve tags collection meta id.');
    exit(1);
  }

  existing = await _listCollections(base, token);
  names = existing.map((e) => e['name']?.toString() ?? '').toSet();

  String? plansMetaId = _metaIdByName(existing, PbCollections.plans);
  if (!names.contains(PbCollections.plans)) {
    print('Creating "${PbCollections.plans}" (no parent_plan_id / tags_link yet)…');
    final body = _plansBodyInitial(
      profilesCollectionId: profilesMetaId,
      categoriesCollectionId: categoriesMetaId,
    );
    plansMetaId = await _createCollectionReturnId(base, token, body);
    print('  meta id: $plansMetaId');
  } else {
    print('Collection exists: ${PbCollections.plans} ($plansMetaId)');
  }
  if (plansMetaId == null || plansMetaId.isEmpty) {
    stderr.writeln('Could not resolve plans collection meta id.');
    exit(1);
  }

  existing = await _listCollections(base, token);
  if (!_schemaHasField(existing, PbCollections.plans, 'parent_plan_id')) {
    print('Patching "${PbCollections.plans}" → parent_plan_id (self relation)…');
    await _patchCollectionAddParentPlan(
      base,
      token,
      plansMetaId,
      plansMetaId,
    );
  } else {
    print(' plans.parent_plan_id already present.');
  }

  existing = await _listCollections(base, token);
  if (!_schemaHasField(existing, PbCollections.plans, kPbPlanTagsExpand)) {
    print('Patching "${PbCollections.plans}" → $kPbPlanTagsExpand (→ tags)…');
    await _patchCollectionAddField(
      base,
      token,
      plansMetaId,
      _relationField(
        name: kPbPlanTagsExpand,
        fieldRequired: false,
        collectionId: tagsMetaId,
        maxSelect: 200,
      ),
    );
  } else {
    print(' plans.$kPbPlanTagsExpand already present.');
  }

  existing = await _listCollections(base, token);
  if (!_schemaHasField(existing, PbCollections.records, kPbRecordTagsExpand)) {
    print('Patching "${PbCollections.records}" → $kPbRecordTagsExpand (→ tags)…');
    await _patchCollectionAddField(
      base,
      token,
      recordsMetaId,
      _relationField(
        name: kPbRecordTagsExpand,
        fieldRequired: false,
        collectionId: tagsMetaId,
        maxSelect: 200,
      ),
    );
  } else {
    print(' records.$kPbRecordTagsExpand already present.');
  }

  existing = await _listCollections(base, token);
  print(
    'Ensuring records relations: category_link cascade delete; '
    'category_link / category_id / $kPbRecordTagsExpand optional…',
  );
  await _ensureRecordsRelationFieldsForCascadeAndOptional(
    base,
    token,
    recordsMetaId,
  );

  existing = await _listCollections(base, token);
  print('Ensuring List/View/Delete API rules ($kPbOwnerListViewRule)…');
  await _ensureOwnerListViewRules(
    base,
    token,
    existing,
    <String>{
      PbCollections.records,
      PbCollections.categories,
      PbCollections.plans,
      PbCollections.tags,
    },
  );

  print('\nBootstrap complete.');
  print('Collections: ${PbCollections.profiles}, ${PbCollections.categories}, '
      '${PbCollections.records}, ${PbCollections.tags}, ${PbCollections.plans}');
}

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

Future<String> _adminAuth(Uri base, String email, String password) async {
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
      stderr.writeln('$p → ${res.statusCode}');
    }
  }
  stderr.writeln('Admin auth failed for all known endpoints.');
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

bool _schemaHasField(
  List<Map<String, dynamic>> items,
  String collectionName,
  String fieldName,
) {
  for (final e in items) {
    if (e['name'] != collectionName) continue;
    final schema = e['schema'];
    if (schema is! List) return false;
    for (final f in schema) {
      if (f is Map && f['name'] == fieldName) return true;
    }
  }
  return false;
}

Future<String?> _createCollectionReturnId(
  Uri base,
  String token,
  Map<String, dynamic> body,
) async {
  final res = await http.post(
    base.replace(path: '/api/collections'),
    headers: _hdr(token),
    body: jsonEncode(body),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    stderr.writeln('POST /api/collections ${res.statusCode}: ${res.body}');
    exit(1);
  }
  final m = jsonDecode(res.body) as Map<String, dynamic>;
  return m['id']?.toString();
}

Future<void> _patchCollectionSchema(
  Uri base,
  String token,
  String collectionMetaId,
  List<dynamic> newSchema,
) async {
  final res = await http.patch(
    base.replace(path: '/api/collections/$collectionMetaId'),
    headers: _hdr(token),
    body: jsonEncode(<String, dynamic>{'schema': newSchema}),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    stderr.writeln('PATCH collection $collectionMetaId ${res.statusCode}: '
        '${res.body}');
    exit(1);
  }
}

Future<void> _ensureOwnerListViewRules(
  Uri base,
  String token,
  List<Map<String, dynamic>> items,
  Set<String> collectionNames,
) async {
  for (final e in items) {
    final n = e['name']?.toString() ?? '';
    if (!collectionNames.contains(n)) continue;
    final id = e['id']?.toString();
    if (id == null || id.isEmpty) continue;
    final curL = e['listRule']?.toString() ?? '';
    final curV = e['viewRule']?.toString() ?? '';
    final curD = e['deleteRule']?.toString() ?? '';
    if (curL == kPbOwnerListViewRule &&
        curV == kPbOwnerListViewRule &&
        curD == kPbOwnerListViewRule) {
      print('  rules OK: $n');
      continue;
    }
    final res = await http.patch(
      base.replace(path: '/api/collections/$id'),
      headers: _hdr(token),
      body: jsonEncode(<String, String>{
        'listRule': kPbOwnerListViewRule,
        'viewRule': kPbOwnerListViewRule,
        'deleteRule': kPbOwnerListViewRule,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      stderr.writeln('PATCH rules $n ${res.statusCode}: ${res.body}');
      exit(1);
    }
    print('  patched rules: $n');
  }
}

/// Records: deleting a [categories] row can 400 if children still point at it.
/// Turn on cascade on [kPbRecordCategoryExpand]; keep category_id/tags optional.
Future<void> _ensureRecordsRelationFieldsForCascadeAndOptional(
  Uri base,
  String token,
  String recordsMetaId,
) async {
  final items = await _listCollections(base, token);
  Map<String, dynamic>? coll;
  for (final e in items) {
    if (e['name'] == PbCollections.records) {
      coll = Map<String, dynamic>.from(e);
      break;
    }
  }
  if (coll == null) return;
  final schema = List<dynamic>.from(coll['schema'] as List? ?? []);
  var changed = false;
  for (var i = 0; i < schema.length; i++) {
    final raw = schema[i];
    if (raw is! Map) continue;
    final f = Map<String, dynamic>.from(raw);
    final fname = f['name']?.toString() ?? '';
    if (f['type']?.toString() != 'relation') continue;
    const relNames = <String>{
      kPbRecordCategoryExpand,
      kPbRecordTagsExpand,
      'category_id',
    };
    if (!relNames.contains(fname)) continue;
    if (f['required'] == true) {
      f['required'] = false;
      changed = true;
    }
    final opts = Map<String, dynamic>.from(
      (f['options'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
    if (fname == kPbRecordCategoryExpand) {
      if (opts['cascadeDelete'] != true) {
        opts['cascadeDelete'] = true;
        changed = true;
      }
    } else {
      if (opts['cascadeDelete'] == true) {
        opts['cascadeDelete'] = false;
        changed = true;
      }
    }
    f['options'] = opts;
    schema[i] = f;
  }
  if (changed) {
    await _patchCollectionSchema(base, token, recordsMetaId, schema);
    print('  records schema patched (category_link cascade, optional relations).');
  } else {
    print('  records relations already OK.');
  }
}

Future<void> _patchCollectionAddParentCategory(
  Uri base,
  String token,
  String categoriesMetaId,
  String selfId,
) async {
  final items = await _listCollections(base, token);
  Map<String, dynamic>? coll;
  for (final e in items) {
    if (e['name'] == PbCollections.categories) {
      coll = e;
      break;
    }
  }
  if (coll == null) exit(1);
  final schema = List<dynamic>.from(coll['schema'] as List? ?? []);
  schema.add(_relationField(
    name: 'parent_id',
    fieldRequired: false,
    collectionId: selfId,
  ));
  await _patchCollectionSchema(base, token, categoriesMetaId, schema);
}

Future<void> _patchCollectionAddParentRecord(
  Uri base,
  String token,
  String recordsMetaId,
  String selfId,
) async {
  final items = await _listCollections(base, token);
  Map<String, dynamic>? coll;
  for (final e in items) {
    if (e['name'] == PbCollections.records) coll = e;
  }
  if (coll == null) exit(1);
  final schema = List<dynamic>.from(coll['schema'] as List? ?? []);
  schema.add(_relationField(
    name: 'parent_id',
    fieldRequired: false,
    collectionId: selfId,
  ));
  await _patchCollectionSchema(base, token, recordsMetaId, schema);
}

Future<void> _patchCollectionAddParentPlan(
  Uri base,
  String token,
  String plansMetaId,
  String selfId,
) async {
  final items = await _listCollections(base, token);
  Map<String, dynamic>? coll;
  for (final e in items) {
    if (e['name'] == PbCollections.plans) coll = e;
  }
  if (coll == null) exit(1);
  final schema = List<dynamic>.from(coll['schema'] as List? ?? []);
  schema.add(_relationField(
    name: 'parent_plan_id',
    fieldRequired: false,
    collectionId: selfId,
  ));
  await _patchCollectionSchema(base, token, plansMetaId, schema);
}

Future<void> _patchCollectionAddField(
  Uri base,
  String token,
  String collectionMetaId,
  Map<String, dynamic> newField,
) async {
  final items = await _listCollections(base, token);
  Map<String, dynamic>? coll;
  for (final e in items) {
    if (e['id']?.toString() == collectionMetaId) coll = e;
  }
  if (coll == null) exit(1);
  final schema = List<dynamic>.from(coll['schema'] as List? ?? []);
  final fname = newField['name']?.toString();
  for (final f in schema) {
    if (f is Map && f['name'] == fname) {
      return;
    }
  }
  schema.add(newField);
  await _patchCollectionSchema(base, token, collectionMetaId, schema);
}

Map<String, dynamic> _relationField({
  required String name,
  required bool fieldRequired,
  required String collectionId,
  int maxSelect = 1,
  bool cascadeDelete = false,
}) =>
    <String, dynamic>{
      'name': name,
      'type': 'relation',
      'required': fieldRequired,
      'options': <String, dynamic>{
        'collectionId': collectionId,
        'cascadeDelete': cascadeDelete,
        'minSelect': null,
        'maxSelect': maxSelect,
        'displayFields': <String>[],
      },
    };

Map<String, dynamic> _jsonField(String name, {bool required = false}) =>
    <String, dynamic>{
      'name': name,
      'type': 'json',
      'required': required,
      'options': <String, dynamic>{'maxSize': 2000000},
    };

Map<String, dynamic> _textField(String name, {bool required = false}) =>
    <String, dynamic>{
      'name': name,
      'type': 'text',
      'required': required,
      'options': <String, dynamic>{},
    };

Map<String, dynamic> _numberField(String name, {bool required = false}) =>
    <String, dynamic>{
      'name': name,
      'type': 'number',
      'required': required,
      'options': <String, dynamic>{},
    };

Map<String, dynamic> _boolField(String name, {bool required = false}) =>
    <String, dynamic>{
      'name': name,
      'type': 'bool',
      'required': required,
      'options': <String, dynamic>{},
    };

Map<String, dynamic> _selectField(
  String name,
  List<String> values, {
  bool required = false,
}) =>
    <String, dynamic>{
      'name': name,
      'type': 'select',
      'required': required,
      'options': <String, dynamic>{
        'maxSelect': 1,
        'values': values,
      },
    };

Map<String, dynamic> _dateField(String name, {bool required = false}) =>
    <String, dynamic>{
      'name': name,
      'type': 'date',
      'required': required,
      'options': <String, dynamic>{},
    };

Map<String, dynamic> _profilesAuthBody() => <String, dynamic>{
      'name': PbCollections.profiles,
      'type': 'auth',
      'schema': <Map<String, dynamic>>[
        _textField('user_id', required: true),
        _textField('display_name', required: true),
        _textField('primary_language', required: false),
        _selectField('theme_mode', const ['light', 'dark', 'system'],
            required: false),
        _textField('preferred_timezone', required: false),
        _numberField('timezone_offset', required: false),
        _boolField('biometric_enabled', required: false),
        _textField('name', required: false),
        _textField('default_category_id', required: false),
        _jsonField('active_languages', required: false),
        _textField('data_region', required: false),
        _boolField('has_seeded', required: false),
      ],
      'listRule': kPbOwnerListViewRule,
      'viewRule': kPbOwnerListViewRule,
      'createRule': '',
      'updateRule': '',
      'deleteRule': '',
    };

Map<String, dynamic> _categoriesBodyInitial({
  required String profilesCollectionId,
}) =>
    <String, dynamic>{
      'name': PbCollections.categories,
      'type': 'base',
      'schema': <Map<String, dynamic>>[
        _relationField(
          name: 'user_id',
          fieldRequired: true,
          collectionId: profilesCollectionId,
        ),
        _textField('category_id', required: true),
        _textField('name', required: true),
        _textField('normalized_id', required: true),
        _jsonField('keywords', required: false),
        _jsonField('localized_names', required: false),
        _textField('color', required: false),
        _numberField('color_value', required: false),
        _textField('icon', required: false),
        _numberField('icon_code_point', required: false),
        _numberField('order', required: false),
      ],
      'listRule': kPbOwnerListViewRule,
      'viewRule': kPbOwnerListViewRule,
      'createRule': '',
      'updateRule': '',
      'deleteRule': kPbOwnerListViewRule,
    };

Map<String, dynamic> _recordsBodyInitial({
  required String profilesCollectionId,
  required String categoriesCollectionId,
}) =>
    <String, dynamic>{
      'name': PbCollections.records,
      'type': 'base',
      'schema': <Map<String, dynamic>>[
        _relationField(
          name: 'user_id',
          fieldRequired: true,
          collectionId: profilesCollectionId,
        ),
        _textField('record_id', required: true),
        _textField('title', required: true),
        _dateField('start_time', required: true),
        _dateField('end_time', required: false),
        _selectField('status', const ['running', 'stopped', 'completed'],
            required: true),
        _textField('type', required: true),
        _relationField(
          name: 'category_id',
          fieldRequired: false,
          collectionId: categoriesCollectionId,
        ),
        _relationField(
          name: kPbRecordCategoryExpand,
          fieldRequired: false,
          collectionId: categoriesCollectionId,
          cascadeDelete: true,
        ),
        _textField('tags', required: false),
        _jsonField('checklist', required: false),
        _textField('note', required: false),
      ],
      'listRule': kPbOwnerListViewRule,
      'viewRule': kPbOwnerListViewRule,
      'createRule': '',
      'updateRule': '',
      'deleteRule': kPbOwnerListViewRule,
    };

Map<String, dynamic> _tagsBody({
  required String profilesCollectionId,
}) =>
    <String, dynamic>{
      'name': PbCollections.tags,
      'type': 'base',
      'schema': <Map<String, dynamic>>[
        _relationField(
          name: 'user_id',
          fieldRequired: true,
          collectionId: profilesCollectionId,
        ),
        _numberField('tag_id', required: true),
        _textField('name', required: true),
        _textField('color', required: false),
        _textField('icon', required: false),
      ],
      'listRule': kPbOwnerListViewRule,
      'viewRule': kPbOwnerListViewRule,
      'createRule': '',
      'updateRule': '',
      'deleteRule': kPbOwnerListViewRule,
    };

Map<String, dynamic> _plansBodyInitial({
  required String profilesCollectionId,
  required String categoriesCollectionId,
}) =>
    <String, dynamic>{
      'name': PbCollections.plans,
      'type': 'base',
      'schema': <Map<String, dynamic>>[
        _textField('plan_id', required: true),
        _relationField(
          name: 'user_id',
          fieldRequired: true,
          collectionId: profilesCollectionId,
        ),
        _relationField(
          name: 'category_id',
          fieldRequired: true,
          collectionId: categoriesCollectionId,
        ),
        _textField('title', required: true),
        _boolField('is_done', required: true),
        _dateField('start_time', required: false),
        _dateField('end_time', required: false),
        _jsonField('checklist', required: false),
        _numberField('order', required: false),
        _textField('note', required: false),
      ],
      'listRule': kPbOwnerListViewRule,
      'viewRule': kPbOwnerListViewRule,
      'createRule': '',
      'updateRule': '',
      'deleteRule': kPbOwnerListViewRule,
    };
