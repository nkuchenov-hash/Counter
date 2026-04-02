// ignore_for_file: avoid_print
//
// One-off NocoDB CSV → PocketBase ETL (profiles → categories → tags →
// records → plans). Reads CSVs from ./migration_data (or paths from env / CLI).
//
// Auth: Prefer pb.admins.authWithPassword (SDK 0.21 aliases this to
//       _superusers). On PocketBase before v0.23 that route 404s; then we POST
//       /api/admins/auth-with-password (same as bootstrap_pb_schema.dart).
//
// Run from repo root:
//   dart pub get
//   set PB_ADMIN_EMAIL=admin@example.com
//   set PB_ADMIN_PASSWORD=your_admin_secret
//   set MIGRATION_DEFAULT_PASSWORD=TempUserPwd123!
//   dart run tool/migrate_data.dart
//
// Optional:
//   set PB_BASE_URL=http://127.0.0.1:8090
//   set MIGRATION_DATA_DIR=migration_data
//   dart run tool/migrate_data.dart profiles.csv categories.csv records.csv [tags.csv plans.csv]
//
// ID mapping:
//   - Maintains oldUserUuid → profilesRecord.id (PB 15-char) for relation fields.
//   - Maintains oldCategoryBusinessKey (Noco category_id string) → categoriesRecord.id.
//   - Maintains oldRecordUuid (record_id) → recordsRecord.id for parent_id patches.
//
// Optional compatibility (plain-text columns as in older app code):
//   MIGRATION_LEGACY_USER_UUID=1  → categories/records user_id = Noco UUID string
//   MIGRATION_LEGACY_TEXT_CATEGORY_ID=1 → records category_id = business slug; category_link = PB id

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:counter/data/pb_config.dart';

final _uuidRe = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

Future<void> main(List<String> args) async {
  final baseUrl = _env('PB_BASE_URL', kPocketBaseUrl).replaceAll(RegExp(r'/$'), '');
  final adminEmail = _env('PB_ADMIN_EMAIL', '');
  final adminPassword = _env('PB_ADMIN_PASSWORD', '');
  final defaultUserPassword = _env('MIGRATION_DEFAULT_PASSWORD', '');
  final legacyUserUuid = Platform.environment['MIGRATION_LEGACY_USER_UUID'] == '1';
  final legacyTextCategoryId = Platform.environment['MIGRATION_LEGACY_TEXT_CATEGORY_ID'] == '1';

  if (adminEmail.isEmpty || adminPassword.isEmpty) {
    stderr.writeln('Set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD.');
    exit(1);
  }
  if (defaultUserPassword.length < 8) {
    stderr.writeln(
      'Set MIGRATION_DEFAULT_PASSWORD (min 8 chars) for imported auth users.',
    );
    exit(1);
  }

  final root = Directory.current.path;
  final migrationDir = _env('MIGRATION_DATA_DIR', 'migration_data');
  final sep = Platform.pathSeparator;
  String pProfiles;
  String pCategories;
  String pRecords;
  String pTags;
  String pPlans;
  if (args.length >= 5) {
    pProfiles = _abs(args[0], root);
    pCategories = _abs(args[1], root);
    pRecords = _abs(args[2], root);
    pTags = _abs(args[3], root);
    pPlans = _abs(args[4], root);
  } else if (args.length >= 3) {
    pProfiles = _abs(args[0], root);
    pCategories = _abs(args[1], root);
    pRecords = _abs(args[2], root);
    pTags = '$root$sep$migrationDir${sep}tags.csv';
    pPlans = '$root$sep$migrationDir${sep}plans.csv';
  } else {
    pProfiles = '$root$sep$migrationDir${sep}profiles.csv';
    pCategories = '$root$sep$migrationDir${sep}categories.csv';
    pRecords = '$root$sep$migrationDir${sep}records.csv';
    pTags = '$root$sep$migrationDir${sep}tags.csv';
    pPlans = '$root$sep$migrationDir${sep}plans.csv';
  }

  for (final p in [pProfiles, pCategories, pRecords]) {
    if (!File(p).existsSync()) {
      stderr.writeln('Missing CSV: $p');
      stderr.writeln(
        'Provide profiles, categories, records paths (and optionally tags, plans), '
        'or place CSVs in $migrationDir',
      );
      exit(1);
    }
  }
  final hasTagsCsv = File(pTags).existsSync();
  final hasPlansCsv = File(pPlans).existsSync();
  if (!hasTagsCsv) {
    print('Note: no tags CSV at $pTags — skipping tags import.');
  }
  if (!hasPlansCsv) {
    print('Note: no plans CSV at $pPlans — skipping plans import.');
  }

  final pb = PocketBase(baseUrl);
  print('Authenticating admin at $baseUrl …');
  await _adminAuthForMigrate(pb, adminEmail, adminPassword);
  print('Admin OK (token length ${pb.authStore.token.length}).');

  final oldUserUuidToProfilePbId = <String, String>{};
  final oldCategoryBizToPbId = <String, String>{};
  final nocoCategoryPkToBiz = <String, String>{};
  final nocoRecordPkToUuid = <String, String>{};
  final oldRecordUuidToPbId = <String, String>{};
  final nocoTagPkToPbId = <String, String>{};
  final tagUserBizToPbId = <String, String>{};
  final tagUserNameToPbId = <String, String>{};

  await _importProfiles(
    pb: pb,
    file: File(pProfiles),
    defaultPassword: defaultUserPassword,
    oldUserUuidToProfilePbId: oldUserUuidToProfilePbId,
  );

  await _importCategories(
    pb: pb,
    file: File(pCategories),
    oldUserUuidToProfilePbId: oldUserUuidToProfilePbId,
    oldCategoryBizToPbId: oldCategoryBizToPbId,
    nocoCategoryPkToBiz: nocoCategoryPkToBiz,
    legacyUserUuid: legacyUserUuid,
  );

  if (hasTagsCsv) {
    await _importTags(
      pb: pb,
      file: File(pTags),
      oldUserUuidToProfilePbId: oldUserUuidToProfilePbId,
      nocoTagPkToPbId: nocoTagPkToPbId,
      tagUserBizToPbId: tagUserBizToPbId,
      tagUserNameToPbId: tagUserNameToPbId,
      legacyUserUuid: legacyUserUuid,
    );
  }

  await _importRecordsPhase1(
    pb: pb,
    file: File(pRecords),
    oldUserUuidToProfilePbId: oldUserUuidToProfilePbId,
    oldCategoryBizToPbId: oldCategoryBizToPbId,
    nocoRecordPkToUuid: nocoRecordPkToUuid,
    oldRecordUuidToPbId: oldRecordUuidToPbId,
    legacyUserUuid: legacyUserUuid,
    legacyTextCategoryId: legacyTextCategoryId,
    nocoTagPkToPbId: nocoTagPkToPbId,
    tagUserBizToPbId: tagUserBizToPbId,
    tagUserNameToPbId: tagUserNameToPbId,
  );

  await _importRecordsPhase2Parents(
    pb: pb,
    file: File(pRecords),
    nocoRecordPkToUuid: nocoRecordPkToUuid,
    oldRecordUuidToPbId: oldRecordUuidToPbId,
  );

  if (hasPlansCsv) {
    await _importPlans(
      pb: pb,
      file: File(pPlans),
      oldUserUuidToProfilePbId: oldUserUuidToProfilePbId,
      oldCategoryBizToPbId: oldCategoryBizToPbId,
      nocoCategoryPkToBiz: nocoCategoryPkToBiz,
      nocoTagPkToPbId: nocoTagPkToPbId,
      tagUserBizToPbId: tagUserBizToPbId,
      tagUserNameToPbId: tagUserNameToPbId,
      legacyUserUuid: legacyUserUuid,
    );
  }

  print('');
  print('=== Migration finished ===');
  print('Profiles (UUID → PB id): ${oldUserUuidToProfilePbId.length}');
  print('Categories (business key → PB id): ${oldCategoryBizToPbId.length}');
  print('Tags (Noco tag Id → PB id): ${nocoTagPkToPbId.length}');
  print('Records (record_id UUID → PB id): ${oldRecordUuidToPbId.length}');
  if (legacyUserUuid) {
    print('Note: user_id on categories/records was Noco UUID (MIGRATION_LEGACY_USER_UUID).');
  }
  if (legacyTextCategoryId) {
    print('Note: records.category_id text + category_link relation '
        '(MIGRATION_LEGACY_TEXT_CATEGORY_ID).');
  }
}

String _env(String key, String d) {
  final v = Platform.environment[key];
  if (v == null) return d;
  final t = v.trim();
  return t.isEmpty ? d : t;
}

/// [pb.admins] in pocketbase 0.21.0 is `collection('_superusers')` (same URL).
/// Pre-v0.23 servers only expose `/api/admins/auth-with-password`.
Future<void> _adminAuthForMigrate(
  PocketBase pb,
  String adminEmail,
  String adminPassword,
) async {
  try {
    // ignore: deprecated_member_use — requested API name; 0.21 aliases to _superusers
    await pb.admins.authWithPassword(adminEmail, adminPassword);
  } on ClientException catch (e) {
    if (e.statusCode != 404) rethrow;
    final data = await pb.send<Map<String, dynamic>>(
      '/api/admins/auth-with-password',
      method: 'POST',
      body: <String, String>{
        'identity': adminEmail,
        'password': adminPassword,
      },
    );
    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw StateError('Admin auth (/api/admins/): empty token');
    }
    final rawRecord = data['record'] ?? data['admin'];
    RecordModel? model;
    if (rawRecord is Map<String, dynamic>) {
      model = RecordModel.fromJson(rawRecord);
    }
    pb.authStore.save(token, model);
  }
}

String _abs(String path, String root) {
  if (path.contains(':') && Platform.isWindows) {
    if (path.length >= 2 && path[1] == ':') return path;
  }
  if (path.startsWith('/')) return path;
  return '$root${Platform.pathSeparator}${path.replaceAll('/', Platform.pathSeparator)}';
}

/// Lowercase header → value (first non-empty among alias keys).
Map<String, String> _rowNorm(List<String> headers, List<dynamic> raw) {
  final m = <String, String>{};
  for (var i = 0; i < headers.length; i++) {
    final k = headers[i].toString().trim().toLowerCase();
    if (k.isEmpty) continue;
    final v = i < raw.length ? raw[i] : '';
    m[k] = v?.toString() ?? '';
  }
  return m;
}

String? _pick(Map<String, String> row, List<String> keys) {
  for (final k in keys) {
    final v = row[k.trim().toLowerCase()];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

List<Map<String, String>> _loadCsv(File f) {
  final text = f.readAsStringSync().replaceAll('\uFEFF', '');
  final table = const CsvToListConverter(
    shouldParseNumbers: false,
  ).convert(text);
  if (table.isEmpty) return [];
  final headers = table.first.map((e) => e.toString()).toList();
  final out = <Map<String, String>>[];
  for (var i = 1; i < table.length; i++) {
    out.add(_rowNorm(headers, table[i]));
  }
  return out;
}

dynamic _decodeJsonField(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;
  try {
    return jsonDecode(t);
  } catch (_) {
    return null;
  }
}

List<dynamic> _checklistValue(String? raw) {
  final d = _decodeJsonField(raw);
  if (d is List) return d;
  if (d is Map) return [d];
  return <dynamic>[];
}

int? _csvInt(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  return int.tryParse(s.trim());
}

num? _csvNum(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  return num.tryParse(s.trim());
}

bool _csvBool(String? s) {
  final t = (s ?? '').trim().toLowerCase();
  return t == 'true' || t == '1' || t == 'yes';
}

String _deriveEmail(Map<String, String> row, String userUuid) {
  final e = _pick(row, ['email', 'Email', 'e-mail']);
  if (e != null && e.contains('@')) return e;
  final local = userUuid.split('-').first;
  return 'user_$local@imported.invalid';
}

bool _looksLikePasswordHash(String? p) {
  if (p == null) return true;
  final t = p.trim();
  if (t.isEmpty) return true;
  if (t.startsWith(r'$2')) return true;
  if (t.length == 64 && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(t)) return true;
  return false;
}

Future<void> _importProfiles({
  required PocketBase pb,
  required File file,
  required String defaultPassword,
  required Map<String, String> oldUserUuidToProfilePbId,
}) async {
  final rows = _loadCsv(file);
  print('\n--- Profiles (${rows.length} rows) ---');
  for (final r in rows) {
    final userUuid = _pick(r, ['user_id', 'userid']);
    if (userUuid == null || !_uuidRe.hasMatch(userUuid)) {
      stderr.writeln('SKIP profile row: missing user_id UUID');
      continue;
    }
    final email = _deriveEmail(r, userUuid);
    final csvPass = _pick(r, ['password', 'pass']);
    final usePass =
        (csvPass != null && !_looksLikePasswordHash(csvPass)) ? csvPass : defaultPassword;

    final body = <String, dynamic>{
      'email': email,
      'emailVisibility': false,
      'password': usePass,
      'passwordConfirm': usePass,
      'user_id': userUuid,
      'display_name': _pick(r, ['display_name', 'display name']) ?? 'User',
      'primary_language': _pick(r, ['primary_language', 'primary language']) ?? 'en',
      'theme_mode': _pick(r, ['theme_mode', 'theme']) ?? 'system',
      'preferred_timezone':
          _pick(r, ['preferred_timezone', 'preferred timezone']) ?? 'UTC (UTC+0)',
      'timezone_offset': _csvNum(_pick(r, ['timezone_offset', 'timezone offset']))?.toInt() ?? 0,
      'biometric_enabled': _csvBool(_pick(r, ['biometric_enabled', 'biometric enabled'])),
    };

    final dc = _pick(r, ['default_category_id', 'default category id']);
    if (dc != null && dc.isNotEmpty) {
      body['default_category_id'] = dc;
    }
    final al = _decodeJsonField(_pick(r, ['active_languages', 'active languages']));
    if (al != null) body['active_languages'] = al;
    final dr = _pick(r, ['data_region', 'data region']);
    if (dr != null && dr.isNotEmpty) body['data_region'] = dr;
    final hs = _pick(r, ['has_seeded', 'has seeded']);
    if (hs != null) body['has_seeded'] = _csvBool(hs);

    try {
      final rec = await pb.collection(PbCollections.profiles).create(body: body);
      oldUserUuidToProfilePbId[userUuid] = rec.id;
      print('Profile $userUuid → PB id ${rec.id} ($email)');
    } on ClientException catch (e) {
      if (e.statusCode == 400 &&
          e.response.toString().toLowerCase().contains('email')) {
        try {
          final existing = await pb.collection(PbCollections.profiles).getList(
                filter: 'email = ${jsonEncode(email)}',
                perPage: 1,
              );
          if (existing.items.isNotEmpty) {
            final id = existing.items.first.id;
            oldUserUuidToProfilePbId[userUuid] = id;
            print('Profile $userUuid → existing PB id $id ($email)');
            continue;
          }
        } catch (_) {}
      }
      stderr.writeln('Profile import failed $userUuid: ${e.statusCode} ${e.response}');
    }
  }
}

String? _resolveCategoryParentPbId(
  String? parentRaw,
  Map<String, String> oldCategoryBizToPbId,
  Map<String, String> nocoCategoryPkToBiz,
) {
  if (parentRaw == null) return null;
  final p = parentRaw.trim();
  if (p.isEmpty || p == '0') return null;

  final byBiz = oldCategoryBizToPbId[p];
  if (byBiz != null) return byBiz;

  final biz = nocoCategoryPkToBiz[p];
  if (biz != null) {
    return oldCategoryBizToPbId[biz];
  }
  return null;
}

Future<void> _importCategories({
  required PocketBase pb,
  required File file,
  required Map<String, String> oldUserUuidToProfilePbId,
  required Map<String, String> oldCategoryBizToPbId,
  required Map<String, String> nocoCategoryPkToBiz,
  required bool legacyUserUuid,
}) async {
  final rows = _loadCsv(file);
  print('\n--- Categories (${rows.length} rows) ---');

  for (final r in rows) {
    final pk = _pick(r, ['id', 'Id', 'ID']);
    final biz = _pick(r, ['category_id', 'category id']);
    if (pk != null && biz != null && biz.isNotEmpty) {
      nocoCategoryPkToBiz[pk] = biz;
    }
  }

  var remaining = rows.toList();
  while (remaining.isNotEmpty) {
    final nextRound = <Map<String, String>>[];
    var createdThisPass = 0;
    for (final r in remaining) {
      final biz = _pick(r, ['category_id', 'category id']);
      if (biz == null || biz.isEmpty) {
        stderr.writeln('SKIP category row: missing category_id');
        continue;
      }
      if (oldCategoryBizToPbId.containsKey(biz)) {
        continue;
      }

      final oldUser = _pick(r, ['user_id', 'userid']);
      if (oldUser == null) {
        stderr.writeln('SKIP category $biz: missing user_id');
        continue;
      }
      final profilePbId = oldUserUuidToProfilePbId[oldUser];
      if (profilePbId == null) {
        stderr.writeln('SKIP category $biz: unknown user_id $oldUser (import profiles first)');
        continue;
      }

      final parentRaw = _pick(r, ['parent_id', 'parent id']);
      final parentPb = _resolveCategoryParentPbId(
        parentRaw,
        oldCategoryBizToPbId,
        nocoCategoryPkToBiz,
      );
      if (parentRaw != null && parentRaw.trim().isNotEmpty && parentPb == null) {
        nextRound.add(r);
        continue;
      }

      final name = _pick(r, ['name', 'title']) ?? biz;
      final norm = _pick(r, ['normalized_id', 'normalized id', 'normalizedid']) ?? biz;

      final body = <String, dynamic>{
        'user_id': legacyUserUuid ? oldUser : profilePbId,
        'category_id': biz,
        'name': name,
        'normalized_id': norm,
        'order': _csvInt(_pick(r, ['order', 'Order'])) ?? 0,
      };
      if (parentPb != null) body['parent_id'] = parentPb;

      final kw = _decodeJsonField(_pick(r, ['keywords']));
      if (kw != null) body['keywords'] = kw;
      final loc = _decodeJsonField(_pick(r, ['localized_names', 'localized names']));
      if (loc != null) body['localized_names'] = loc;

      final cv = _csvInt(_pick(r, ['color_value', 'color value']));
      if (cv != null) body['color_value'] = cv;
      final icp = _csvInt(_pick(r, ['icon_code_point', 'icon code point']));
      if (icp != null) body['icon_code_point'] = icp;
      final col = _pick(r, ['color', 'Color']);
      if (col != null && col.isNotEmpty) body['color'] = col;
      final icon = _pick(r, ['icon', 'Icon']);
      if (icon != null && icon.isNotEmpty) body['icon'] = icon;

      try {
        final rec = await pb.collection(PbCollections.categories).create(body: body);
        oldCategoryBizToPbId[biz] = rec.id;
        print('Category $biz → PB ${rec.id}');
        createdThisPass++;
      } on ClientException catch (e) {
        stderr.writeln('Category create failed $biz: ${e.statusCode} ${e.response}');
      }
    }
    if (createdThisPass == 0 && nextRound.isNotEmpty) {
      stderr.writeln('ERROR: category dependency cycle or unresolved parent_id. '
          '${nextRound.length} row(s) left.');
      for (final r in nextRound) {
        stderr.writeln('  stuck: ${_pick(r, ['category_id', 'category id'])} '
            'parent=${_pick(r, ['parent_id', 'parent id'])}');
      }
      break;
    }
    remaining = nextRound;
  }
}

List<String> _tagCellToPbIds(
  String? raw,
  String userUuid,
  Map<String, String> nocoTagPkToPbId,
  Map<String, String> tagUserBizToPbId,
  Map<String, String> tagUserNameToPbId,
) {
  if (raw == null || raw.trim().isEmpty) return [];
  final parts = raw.split(RegExp(r'[,;]'));
  final out = <String>[];
  final seen = <String>{};
  for (final p in parts) {
    final t = p.trim();
    if (t.isEmpty) continue;
    String? pb = nocoTagPkToPbId[t];
    pb ??= tagUserBizToPbId['$userUuid|$t'];
    pb ??= tagUserNameToPbId['$userUuid|${t.toLowerCase()}'];
    if (pb != null && seen.add(pb)) out.add(pb);
  }
  return out;
}

String? _resolveCategoryPbIdForMigration(
  String? catRaw,
  Map<String, String> oldCategoryBizToPbId,
  Map<String, String> nocoCategoryPkToBiz,
) {
  if (catRaw == null) return null;
  final c = catRaw.trim();
  if (c.isEmpty) return null;
  final byBiz = oldCategoryBizToPbId[c];
  if (byBiz != null) return byBiz;
  final biz = nocoCategoryPkToBiz[c];
  if (biz != null) return oldCategoryBizToPbId[biz];
  return null;
}

Future<void> _importTags({
  required PocketBase pb,
  required File file,
  required Map<String, String> oldUserUuidToProfilePbId,
  required Map<String, String> nocoTagPkToPbId,
  required Map<String, String> tagUserBizToPbId,
  required Map<String, String> tagUserNameToPbId,
  required bool legacyUserUuid,
}) async {
  final rows = _loadCsv(file);
  print('\n--- Tags (${rows.length} rows) ---');
  for (final r in rows) {
    final name = _pick(r, ['name', 'Name']);
    if (name == null || name.trim().isEmpty) {
      continue;
    }
    final oldUser = _pick(r, ['user_id', 'userid']);
    if (oldUser == null || oldUser.trim().isEmpty) {
      stderr.writeln('SKIP tag "$name": missing user_id');
      continue;
    }
    final profilePbId = oldUserUuidToProfilePbId[oldUser];
    if (profilePbId == null) {
      stderr.writeln('SKIP tag "$name": unknown user $oldUser');
      continue;
    }
    final nocoPk = _pick(r, ['id', 'Id', 'ID']);
    var tid = _csvInt(_pick(r, ['tag_id', 'tag id']));
    tid ??= int.tryParse(nocoPk ?? '');
    if (tid == null) {
      stderr.writeln('SKIP tag "$name": no tag_id / Id');
      continue;
    }
    final body = <String, dynamic>{
      'user_id': legacyUserUuid ? oldUser : profilePbId,
      'tag_id': tid,
      'name': name.trim(),
    };
    final col = _pick(r, ['color', 'Color']);
    if (col != null && col.isNotEmpty) body['color'] = col;
    final icon = _pick(r, ['icon', 'Icon']);
    if (icon != null && icon.isNotEmpty) body['icon'] = icon;

    try {
      final rec = await pb.collection(PbCollections.tags).create(body: body);
      if (nocoPk != null && nocoPk.isNotEmpty) {
        nocoTagPkToPbId[nocoPk] = rec.id;
      }
      tagUserBizToPbId['$oldUser|$tid'] = rec.id;
      tagUserNameToPbId['$oldUser|${name.trim().toLowerCase()}'] = rec.id;
      print('Tag "$name" (Noco Id=$nocoPk, tag_id=$tid) → PB ${rec.id}');
    } on ClientException catch (e) {
      stderr.writeln('Tag create failed "$name": ${e.statusCode} ${e.response}');
    }
  }
}

Future<void> _importPlans({
  required PocketBase pb,
  required File file,
  required Map<String, String> oldUserUuidToProfilePbId,
  required Map<String, String> oldCategoryBizToPbId,
  required Map<String, String> nocoCategoryPkToBiz,
  required Map<String, String> nocoTagPkToPbId,
  required Map<String, String> tagUserBizToPbId,
  required Map<String, String> tagUserNameToPbId,
  required bool legacyUserUuid,
}) async {
  final rows = _loadCsv(file);
  print('\n--- Plans (${rows.length} rows) ---');
  final nocoPlanPkToPbId = <String, String>{};
  final planBizToPbId = <String, String>{};
  var created = 0;

  for (final r in rows) {
    final nocoPk = _pick(r, ['id', 'Id', 'ID']);
    final bizPlan = _pick(r, ['plan_id', 'plan id'])?.trim();
    final stablePlanId = (bizPlan != null && bizPlan.isNotEmpty)
        ? bizPlan
        : 'import_plan_${nocoPk ?? 'na'}';

    final oldUser = _pick(r, ['user_id', 'userid']);
    if (oldUser == null || oldUser.trim().isEmpty) {
      stderr.writeln('SKIP plan $stablePlanId: missing user_id');
      continue;
    }
    final profilePbId = oldUserUuidToProfilePbId[oldUser];
    if (profilePbId == null) {
      stderr.writeln('SKIP plan $stablePlanId: unknown user $oldUser');
      continue;
    }

    final catRaw = _pick(r, ['category_id', 'category id']);
    final catPb = _resolveCategoryPbIdForMigration(
      catRaw,
      oldCategoryBizToPbId,
      nocoCategoryPkToBiz,
    );
    if (catPb == null) {
      stderr.writeln('SKIP plan $stablePlanId: unresolved category_id "$catRaw"');
      continue;
    }

    final title = _pick(r, ['title', 'Title']) ?? '(no title)';
    final body = <String, dynamic>{
      'plan_id': stablePlanId,
      'user_id': legacyUserUuid ? oldUser : profilePbId,
      'category_id': catPb,
      'title': title,
      'is_done': _csvBool(_pick(r, ['is_done', 'is done', 'done'])),
      'checklist': _checklistValue(_pick(r, ['checklist', 'Checklist'])),
      'order': _csvInt(_pick(r, ['order', 'Order'])) ?? 0,
    };
    final st = _pick(r, ['start_time', 'start time']);
    if (st != null && st.isNotEmpty) body['start_time'] = st;
    final et = _pick(r, ['end_time', 'end time']);
    if (et != null && et.isNotEmpty) body['end_time'] = et;
    final note = _pick(r, ['note', 'notes', 'Note']);
    if (note != null && note.isNotEmpty) body['note'] = note;

    try {
      var rec = await pb.collection(PbCollections.plans).create(body: body);
      created++;
      if (nocoPk != null && nocoPk.isNotEmpty) {
        nocoPlanPkToPbId[nocoPk] = rec.id;
      }
      planBizToPbId[stablePlanId] = rec.id;

      final tagPbIds = _tagCellToPbIds(
        _pick(r, ['tags', 'Tags']),
        oldUser,
        nocoTagPkToPbId,
        tagUserBizToPbId,
        tagUserNameToPbId,
      );
      if (tagPbIds.isNotEmpty) {
        rec = await pb.collection(PbCollections.plans).update(
              rec.id,
              body: <String, dynamic>{kPbPlanTagsExpand: tagPbIds},
            );
        print('Plan $stablePlanId → PB ${rec.id} (tags_link: ${tagPbIds.length})');
      } else {
        print('Plan $stablePlanId → PB ${rec.id}');
      }
    } on ClientException catch (e) {
      stderr.writeln('Plan create failed $stablePlanId: ${e.statusCode} ${e.response}');
    }
  }

  print('\n--- Plans phase 2 (parent_plan_id) ---');
  for (final r in rows) {
    final nocoPk = _pick(r, ['id', 'Id', 'ID']);
    final selfPb = (nocoPk != null && nocoPk.isNotEmpty) ? nocoPlanPkToPbId[nocoPk] : null;
    if (selfPb == null) continue;

    final parentRaw = _pick(r, ['parent_plan_id', 'parent plan id', 'parent_plan']);
    if (parentRaw == null || parentRaw.trim().isEmpty) continue;
    final pr = parentRaw.trim();

    String? parentPb = nocoPlanPkToPbId[pr];
    if (parentPb == null && _uuidRe.hasMatch(pr)) {
      parentPb = planBizToPbId[pr];
    }

    if (parentPb == null) {
      stderr.writeln('Plan noco Id=$nocoPk: could not resolve parent_plan_id=$pr');
      continue;
    }

    try {
      await pb.collection(PbCollections.plans).update(
            selfPb,
            body: <String, dynamic>{'parent_plan_id': parentPb},
          );
      print('Plan noco Id=$nocoPk parent_plan_id → $parentPb');
    } on ClientException catch (e) {
      stderr.writeln('Plan parent patch noco Id=$nocoPk: ${e.statusCode} ${e.response}');
    }
  }

  print('Plans created: $created');
}

Future<void> _importRecordsPhase1({
  required PocketBase pb,
  required File file,
  required Map<String, String> oldUserUuidToProfilePbId,
  required Map<String, String> oldCategoryBizToPbId,
  required Map<String, String> nocoRecordPkToUuid,
  required Map<String, String> oldRecordUuidToPbId,
  required bool legacyUserUuid,
  required bool legacyTextCategoryId,
  required Map<String, String> nocoTagPkToPbId,
  required Map<String, String> tagUserBizToPbId,
  required Map<String, String> tagUserNameToPbId,
}) async {
  final rows = _loadCsv(file);
  print('\n--- Records phase 1 (${rows.length} rows) ---');

  for (final r in rows) {
    final nocoPk = _pick(r, ['id', 'Id', 'ID']);
    final recUuid = _pick(r, ['record_id', 'record id']);
    if (nocoPk != null && recUuid != null && recUuid.isNotEmpty) {
      nocoRecordPkToUuid[nocoPk] = recUuid;
    }
  }

  for (final r in rows) {
    final recUuid = _pick(r, ['record_id', 'record id']);
    if (recUuid == null || recUuid.isEmpty) {
      stderr.writeln('SKIP record: missing record_id');
      continue;
    }
    if (oldRecordUuidToPbId.containsKey(recUuid)) continue;

    final oldUser = _pick(r, ['user_id', 'userid']);
    if (oldUser == null) {
      stderr.writeln('SKIP record $recUuid: missing user_id');
      continue;
    }
    final profilePbId = oldUserUuidToProfilePbId[oldUser];
    if (profilePbId == null) {
      stderr.writeln('SKIP record $recUuid: unknown user $oldUser');
      continue;
    }

    final catBiz = _pick(r, ['category_id', 'category id']);
    if (catBiz == null || catBiz.isEmpty) {
      stderr.writeln('SKIP record $recUuid: missing category_id');
      continue;
    }
    final catPbId = oldCategoryBizToPbId[catBiz];
    if (catPbId == null) {
      stderr.writeln('SKIP record $recUuid: unknown category business id $catBiz');
      continue;
    }

    final title = _pick(r, ['title', 'Title']) ?? '';
    final start = _pick(r, ['start_time', 'start time']);
    if (start == null || start.isEmpty) {
      stderr.writeln('SKIP record $recUuid: missing start_time');
      continue;
    }

    final body = <String, dynamic>{
      'user_id': legacyUserUuid ? oldUser : profilePbId,
      'record_id': recUuid,
      'title': title,
      'start_time': start,
      'status': _pick(r, ['status', 'Status']) ?? 'completed',
      'type': _pick(r, ['type', 'Type']) ?? 'record',
      'checklist': _checklistValue(_pick(r, ['checklist', 'Checklist'])),
    };
    if (legacyTextCategoryId) {
      body['category_id'] = catBiz;
      body[kPbRecordCategoryExpand] = catPbId;
    } else {
      body['category_id'] = catPbId;
      body[kPbRecordCategoryExpand] = catPbId;
    }

    final end = _pick(r, ['end_time', 'end time']);
    if (end != null && end.isNotEmpty) body['end_time'] = end;

    final note = _pick(r, ['note', 'notes', 'Note']);
    if (note != null && note.isNotEmpty) body['note'] = note;

    final tags = _pick(r, ['tags', 'Tags']);
    if (tags != null && tags.isNotEmpty) body['tags'] = tags;

    final tagLinks = _tagCellToPbIds(
      tags,
      oldUser,
      nocoTagPkToPbId,
      tagUserBizToPbId,
      tagUserNameToPbId,
    );
    if (tagLinks.isNotEmpty) {
      body[kPbRecordTagsExpand] = tagLinks;
    }

    try {
      final rec = await pb.collection(PbCollections.records).create(body: body);
      oldRecordUuidToPbId[recUuid] = rec.id;
      print('Record $recUuid → PB ${rec.id}');
    } on ClientException catch (e) {
      stderr.writeln('Record create failed $recUuid: ${e.statusCode} ${e.response}');
    }
  }
}

Future<void> _importRecordsPhase2Parents({
  required PocketBase pb,
  required File file,
  required Map<String, String> nocoRecordPkToUuid,
  required Map<String, String> oldRecordUuidToPbId,
}) async {
  final rows = _loadCsv(file);
  print('\n--- Records phase 2 (parent_id) ---');

  for (final r in rows) {
    final recUuid = _pick(r, ['record_id', 'record id']);
    if (recUuid == null) continue;
    final selfPb = oldRecordUuidToPbId[recUuid];
    if (selfPb == null) continue;

    final parentRaw = _pick(r, ['parent_id', 'parent id']);
    if (parentRaw == null || parentRaw.trim().isEmpty) continue;

    String? parentPb;
    final pr = parentRaw.trim();
    if (_uuidRe.hasMatch(pr)) {
      parentPb = oldRecordUuidToPbId[pr];
    } else {
      final pUuid = nocoRecordPkToUuid[pr];
      if (pUuid != null) parentPb = oldRecordUuidToPbId[pUuid];
    }
    if (parentPb == null) {
      stderr.writeln('Record $recUuid: could not resolve parent_id=$parentRaw');
      continue;
    }

    try {
      await pb.collection(PbCollections.records).update(
            selfPb,
            body: <String, dynamic>{'parent_id': parentPb},
          );
      print('Record $recUuid parent_id → $parentPb');
    } on ClientException catch (e) {
      stderr.writeln('Record parent patch $recUuid: ${e.statusCode} ${e.response}');
    }
  }
}
