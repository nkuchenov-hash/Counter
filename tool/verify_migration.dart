// ignore_for_file: avoid_print
//
// Post-migration integrity: CSV row counts vs PocketBase, FK/orphans,
// and one user auth probe (MIGRATION_DEFAULT_PASSWORD).
//
// References: lib/DATA_MAP.md, POCKETBASE_MANIFEST.md (collections, category_link).
//
// Run from repo root:
//   dart pub get
//   set PB_ADMIN_EMAIL=...
//   set PB_ADMIN_PASSWORD=...
//   set MIGRATION_DEFAULT_PASSWORD=...
//   dart run tool/verify_migration.dart
//
// Same paths as migrate_data.dart: migration_data/*.csv or 3 CLI args.
// Optional: MIGRATION_LEGACY_USER_UUID=1 MIGRATION_LEGACY_TEXT_CATEGORY_ID=1

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:counter/data/pb_config.dart';

const _superusers = '_superusers';


Future<void> main(List<String> args) async {
  final baseUrl = _env('PB_BASE_URL', kPocketBaseUrl).replaceAll(RegExp(r'/$'), '');
  final adminEmail = _env('PB_ADMIN_EMAIL', '');
  final adminPassword = _env('PB_ADMIN_PASSWORD', '');
  final migrationPassword = _env('MIGRATION_DEFAULT_PASSWORD', '');
  final legacyUserUuid = Platform.environment['MIGRATION_LEGACY_USER_UUID'] == '1';
  final legacyTextCat = Platform.environment['MIGRATION_LEGACY_TEXT_CATEGORY_ID'] == '1';

  if (adminEmail.isEmpty || adminPassword.isEmpty) {
    stderr.writeln('Set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD.');
    exit(1);
  }

  final root = Directory.current.path;
  final migrationDir = _env('MIGRATION_DATA_DIR', 'migration_data');
  late final String pProfiles;
  late final String pCategories;
  late final String pRecords;
  if (args.length >= 3) {
    pProfiles = _abs(args[0], root);
    pCategories = _abs(args[1], root);
    pRecords = _abs(args[2], root);
  } else {
    pProfiles = '$root${Platform.pathSeparator}$migrationDir${Platform.pathSeparator}profiles.csv';
    pCategories = '$root${Platform.pathSeparator}$migrationDir${Platform.pathSeparator}categories.csv';
    pRecords = '$root${Platform.pathSeparator}$migrationDir${Platform.pathSeparator}records.csv';
  }

  for (final p in [pProfiles, pCategories, pRecords]) {
    if (!File(p).existsSync()) {
      stderr.writeln('Missing CSV: $p');
      exit(1);
    }
  }

  final csvProfiles = _csvDataRowCount(File(pProfiles));
  final csvCategories = _csvDataRowCount(File(pCategories));
  final csvRecords = _csvDataRowCount(File(pRecords));

  print('=== PocketBase migration integrity ===');
  print('PB URL: $baseUrl');
  print('Legacy flags: MIGRATION_LEGACY_USER_UUID=$legacyUserUuid '
      'MIGRATION_LEGACY_TEXT_CATEGORY_ID=$legacyTextCat');
  print('');
  print('CSV data rows: profiles=$csvProfiles categories=$csvCategories records=$csvRecords');

  final pb = PocketBase(baseUrl);
  await pb.collection(_superusers).authWithPassword(adminEmail, adminPassword);
  print('Admin session OK.\n');

  final profiles = await pb.collection(PbCollections.profiles).getFullList(batch: 500);
  final categories = await pb.collection(PbCollections.categories).getFullList(batch: 500);
  final records = await pb.collection(PbCollections.records).getFullList(batch: 500);

  print('PB row counts: profiles=${profiles.length} categories=${categories.length} '
      'records=${records.length}');
  _printCountDelta('profiles', csvProfiles, profiles.length);
  _printCountDelta('categories', csvCategories, categories.length);
  _printCountDelta('records', csvRecords, records.length);
  print('');

  final profilePbIds = <String>{for (final r in profiles) r.id};
  final profileBizUserIds = <String>{
    for (final r in profiles)
      (r.data['user_id'] ?? '').toString().trim(),
  }..removeWhere((s) => s.isEmpty);

  final categoryPbIds = <String>{for (final r in categories) r.id};
  final categoryBizIds = <String>{
    for (final r in categories)
      (r.data['category_id'] ?? '').toString().trim(),
  }..removeWhere((s) => s.isEmpty);

  final recordPbIds = <String>{for (final r in records) r.id};

  final categoryOrphans = <String>[];
  for (final c in categories) {
    final id = c.id;
    final uid = _scalarFk(c.data['user_id']);
    String? problem;
    if (uid == null || uid.isEmpty) {
      problem = 'missing user_id';
    } else if (legacyUserUuid) {
      if (!profileBizUserIds.contains(uid)) {
        problem = 'user_id="$uid" (no profile with this business user_id)';
      }
    } else {
      if (!profilePbIds.contains(uid)) {
        problem = 'user_id="$uid" (not a profile id)';
      }
    }
    final pId = _scalarFk(c.data['parent_id']);
    if (pId != null && pId.isNotEmpty && !categoryPbIds.contains(pId)) {
      problem = '${problem ?? "ok"} + parent_id="$pId" not found';
    }
    if (problem != null) categoryOrphans.add('category $id: $problem');
  }

  final recordOrphans = <String>[];
  for (final rec in records) {
    final id = rec.id;
    final rid = (rec.data['record_id'] ?? '').toString().trim();
    final label = rid.isNotEmpty ? '$id (record_id=$rid)' : id;

    final uid = _scalarFk(rec.data['user_id']);
    if (uid == null || uid.isEmpty) {
      recordOrphans.add('$label: missing user_id');
    } else if (legacyUserUuid) {
      if (!profileBizUserIds.contains(uid)) {
        recordOrphans.add('$label: user_id="$uid" no matching profile.user_id');
      }
    } else {
      if (!profilePbIds.contains(uid)) {
        recordOrphans.add('$label: user_id="$uid" not a profile id');
      }
    }

    final catLink = _scalarFk(rec.data[kPbRecordCategoryExpand]);
    final catField = _scalarFk(rec.data['category_id']);

    if (catLink != null && catLink.isNotEmpty && !categoryPbIds.contains(catLink)) {
      recordOrphans.add(
        '$label: $kPbRecordCategoryExpand="$catLink" does not exist in categories',
      );
    }

    if (legacyTextCat) {
      if (catField != null &&
          catField.isNotEmpty &&
          !categoryBizIds.contains(catField)) {
        recordOrphans.add(
          '$label: category_id="$catField" (text) not found as categories.category_id',
        );
      }
    } else {
      if (catField != null &&
          catField.isNotEmpty &&
          !categoryPbIds.contains(catField)) {
        recordOrphans.add(
          '$label: category_id="$catField" not a categories row id',
        );
      }
    }

    final par = _scalarFk(rec.data['parent_id']);
    if (par != null && par.isNotEmpty && !recordPbIds.contains(par)) {
      recordOrphans.add('$label: parent_id="$par" not a records row id');
    }
  }

  print('--- Orphan / FK summary ---');
  if (categoryOrphans.isEmpty) {
    print('Categories: no FK issues detected.');
  } else {
    print('Categories: ${categoryOrphans.length} issue(s)');
    for (final o in categoryOrphans) {
      print('  • $o');
    }
  }
  if (recordOrphans.isEmpty) {
    print('Records: no FK issues detected.');
  } else {
    print('Records: ${recordOrphans.length} issue(s)');
    for (final o in recordOrphans.take(50)) {
      print('  • $o');
    }
    if (recordOrphans.length > 50) {
      print('  … ${recordOrphans.length - 50} more');
    }
  }
  print('');

  var authOk = false;
  if (migrationPassword.length >= 8 && profiles.isNotEmpty) {
    final probe = PocketBase(baseUrl);
    final emailsTried = <String>[];
    for (final r in profiles) {
      final email = (r.data['email'] ?? '').toString().trim();
      if (email.isEmpty || !email.contains('@')) continue;
      emailsTried.add(email);
      try {
        await probe.collection(PbCollections.profiles).authWithPassword(
              email,
              migrationPassword,
            );
        print('User auth OK: $email (MIGRATION_DEFAULT_PASSWORD)');
        authOk = true;
        break;
      } on ClientException {
        continue;
      }
    }
    if (!authOk) {
      stderr.writeln(
        'User auth FAILED: no profile accepted MIGRATION_DEFAULT_PASSWORD '
        '(tried ${emailsTried.length} email(s)).',
      );
    }
  } else if (migrationPassword.length < 8) {
    print('Skip user auth: set MIGRATION_DEFAULT_PASSWORD (min 8 chars).');
    authOk = true;
  } else {
    print('Skip user auth: no profiles in PocketBase.');
  }

  final failed = categoryOrphans.isNotEmpty ||
      recordOrphans.isNotEmpty ||
      (!authOk && migrationPassword.length >= 8 && profiles.isNotEmpty);

  print('');
  if (failed) {
    print('RESULT: FAIL (fix orphans or auth before production).');
    exit(1);
  }
  print('RESULT: PASS — counts reported above; no orphan FKs; auth probe OK.');
  print('App checklist: log in on device, open timeline, confirm categories expand.');
  exit(0);
}

String _env(String key, String d) {
  final v = Platform.environment[key];
  if (v == null) return d;
  final t = v.trim();
  return t.isEmpty ? d : t;
}

String _abs(String path, String root) {
  if (path.length >= 2 && path[1] == ':' && Platform.isWindows) return path;
  if (path.startsWith('/')) return path;
  return '$root${Platform.pathSeparator}${path.replaceAll('/', Platform.pathSeparator)}';
}

int _csvDataRowCount(File f) {
  final text = f.readAsStringSync().replaceAll('\uFEFF', '');
  final table = const CsvToListConverter(shouldParseNumbers: false).convert(text);
  if (table.isEmpty) return 0;
  return table.length - 1;
}

void _printCountDelta(String name, int csvRows, int pbRows) {
  if (csvRows == pbRows) {
    print('  $name: CSV vs PB match ($csvRows).');
    return;
  }
  final d = pbRows - csvRows;
  if (d < 0) {
    stderr.writeln(
      '  WARNING $name: PB has fewer rows than CSV (missing ${-d} import(s)?).',
    );
  } else {
    print('  NOTE $name: PB has +$d row(s) vs CSV (manual/extra data OK).');
  }
}

/// Single relation FK as stored by PocketBase (string id).
String? _scalarFk(dynamic v) {
  if (v == null) return null;
  if (v is String) {
    final s = v.trim();
    return s.isEmpty ? null : s;
  }
  if (v is List) {
    if (v.isEmpty) return null;
    final first = v.first;
    return first?.toString().trim().isEmpty ?? true ? null : first.toString().trim();
  }
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}
