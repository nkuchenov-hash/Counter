// ignore_for_file: avoid_print
//
// Apply approved single-group plan duplicate cleanup (DELETE plans only).
//
// Usage:
//   dart run scripts/manual/plans_duplicate_cleanup_apply.dart \
//     --confirm-price-reporter-129 \
//     --plan tools/reports/plans_duplicate_cleanup_plan_2026-06-23T15-28-20-100091Z.json
//
// Auth: AUDIT_USER_EMAIL + AUDIT_USER_PASSWORD (or PB_AUTH_JSON)
// Optional: PB_BASE_URL

import 'dart:convert';
import 'dart:io';

import 'package:pocketbase/pocketbase.dart';

const _defaultPbUrl = 'https://217-114-0-201.sslip.io';
const _defaultUserEmail = 'Kuchenov@yandex.ru';
const _approvedTitle = 'Price Reporter Email check';
const _defaultPlanPath =
    'tools/reports/plans_duplicate_cleanup_plan_2026-06-23T15-28-20-100091Z.json';

/// User-approved flood group; delete count comes from JSON [duplicateCandidatePbIds].
const _confirmFlag = '--confirm-price-reporter-129';

String _env(String key, String fallback) {
  final v = Platform.environment[key]?.trim();
  return (v == null || v.isEmpty) ? fallback : v;
}

String? _scalarFk(dynamic v) {
  if (v == null) return null;
  if (v is String) {
    final s = v.trim();
    return s.isEmpty ? null : s;
  }
  if (v is List) {
    if (v.isEmpty) return null;
    final ids = <String>[];
    for (final item in v) {
      final s = item?.toString().trim() ?? '';
      if (s.isNotEmpty) ids.add(s);
    }
    if (ids.isEmpty) return null;
    ids.sort();
    return ids.join(',');
  }
  if (v is Map) {
    final id = v['id']?.toString().trim();
    if (id != null && id.isNotEmpty) return id;
  }
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String _normTitle(String? t) {
  final collapsed = (t ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  return collapsed.toLowerCase();
}

String _normIso(dynamic v) => (v ?? '').toString().trim();

String _canonicalJson(dynamic v) {
  if (v == null) return '[]';
  dynamic parsed = v;
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return '[]';
    try {
      parsed = jsonDecode(s);
    } catch (_) {
      return jsonEncode(s);
    }
  }
  return jsonEncode(_sortJsonDeep(parsed));
}

dynamic _sortJsonDeep(dynamic v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _sortJsonDeep(v[k])};
  }
  if (v is List) {
    final normalized = v.map(_sortJsonDeep).toList();
    try {
      final encoded = normalized.map(jsonEncode).toList()..sort();
      return encoded.map((e) => jsonDecode(e)).toList();
    } catch (_) {
      return normalized;
    }
  }
  return v;
}

String _normTags(dynamic v) {
  final raw = (v ?? '').toString().trim();
  if (raw.isEmpty) return '';
  final parts = raw
      .split(RegExp(r'[,;]'))
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toList()
    ..sort();
  return parts.join(',');
}

String _normTagsLink(dynamic v) {
  if (v == null) return '';
  if (v is List) {
    final ids = <String>[];
    for (final item in v) {
      if (item is Map) {
        final id = item['id']?.toString().trim();
        if (id != null && id.isNotEmpty) ids.add(id);
      } else {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty) ids.add(s);
      }
    }
    ids.sort();
    return ids.join(',');
  }
  return _scalarFk(v) ?? '';
}

String _normRrule(dynamic v) {
  var s = (v ?? '').toString().trim().toUpperCase();
  if (s.startsWith('RRULE:')) s = s.substring(6).trim();
  return s;
}

String _normExceptionDates(dynamic v) {
  if (v == null) return '[]';
  List<dynamic> list;
  if (v is String) {
    try {
      list = jsonDecode(v) as List<dynamic>? ?? [];
    } catch (_) {
      return '[]';
    }
  } else if (v is List) {
    list = v;
  } else {
    return '[]';
  }
  final dates = list.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList()
    ..sort();
  return jsonEncode(dates);
}

String semanticExactFingerprint(Map<String, dynamic> row) {
  final uid = _scalarFk(row['user_id']) ?? '';
  final title = _normTitle(row['title']?.toString());
  final cat = _scalarFk(row['category_id']) ?? '';
  final start = _normIso(row['start_time']);
  final end = _normIso(row['end_time']);
  final done = row['is_done'] == true ? '1' : '0';
  final init = (row['initial_date_key'] ?? '').toString().trim();
  final parent = _scalarFk(row['parent_plan_id']) ?? '';
  final checklist = _canonicalJson(row['checklist']);
  final notesPlain = (row['notes_plain'] ?? '').toString().trim();
  final notesDelta = _canonicalJson(row['notes_delta']);
  final tags = _normTags(row['tags']);
  final tagsLink = _normTagsLink(row['tags_link']);
  final rrule = _normRrule(row['rrule']);
  final exceptions = _normExceptionDates(row['exception_dates']);
  final reminder = row['reminder_offset']?.toString().trim() ?? '';
  final postponed = row['is_postponed'] == true ? '1' : '0';
  return [
    'uid=$uid',
    'title=$title',
    'cat=$cat',
    'start=$start',
    'end=$end',
    'done=$done',
    'init=$init',
    'parent=$parent',
    'checklist=$checklist',
    'notes_plain=$notesPlain',
    'notes_delta=$notesDelta',
    'tags=$tags',
    'tags_link=$tagsLink',
    'rrule=$rrule',
    'exceptions=$exceptions',
    'reminder=$reminder',
    'postponed=$postponed',
  ].join('|');
}

Future<PocketBase> _authenticatedPb(String baseUrl) async {
  final pb = PocketBase(baseUrl);
  final authJson = _env('PB_AUTH_JSON', '');
  if (authJson.isNotEmpty) {
    try {
      final parsed = jsonDecode(authJson);
      if (parsed is Map<String, dynamic>) {
        final token = parsed['token']?.toString() ?? '';
        final recordRaw = parsed['record'];
        RecordModel? record;
        if (recordRaw is Map<String, dynamic>) {
          record = RecordModel.fromJson(recordRaw);
        }
        if (token.isNotEmpty) {
          pb.authStore.save(token, record);
          if (pb.authStore.isValid) return pb;
        }
      }
    } catch (_) {}
  }
  final userEmail = _env('AUDIT_USER_EMAIL', _defaultUserEmail);
  final userPassword = _env('AUDIT_USER_PASSWORD', '');
  if (userPassword.length >= 8) {
    await pb.collection('profiles').authWithPassword(userEmail, userPassword);
    return pb;
  }
  stderr.writeln('Auth failed. Set AUDIT_USER_EMAIL + AUDIT_USER_PASSWORD.');
  exit(1);
}

Future<List<RecordModel>> _fetchAll(
  PocketBase pb,
  String collection,
  String filter,
) async {
  return pb.collection(collection).getFullList(batch: 500, filter: filter);
}

void _die(String msg) {
  stderr.writeln('HARD STOP: $msg');
  exit(1);
}

void _ensureDir(String path) => Directory(path).createSync(recursive: true);

Map<String, dynamic> _planExportMap(RecordModel p) {
  final m = Map<String, dynamic>.from(p.data);
  m['id'] = p.id;
  m['created'] = p.created;
  m['updated'] = p.updated;
  return m;
}

Future<void> main(List<String> args) async {
  if (!args.contains(_confirmFlag)) {
    _die('Missing required flag $_confirmFlag');
  }

  var planPath = _defaultPlanPath;
  final planIdx = args.indexOf('--plan');
  if (planIdx >= 0 && planIdx + 1 < args.length) {
    planPath = args[planIdx + 1];
  }

  final planFile = File(planPath);
  if (!planFile.existsSync()) {
    _die('Cleanup plan not found: $planPath');
  }

  final plan = jsonDecode(planFile.readAsStringSync()) as Map<String, dynamic>;
  final semanticGroups =
      (plan['semanticDuplicateGroups'] as List?)?.cast<Map<String, dynamic>>() ??
          [];

  Map<String, dynamic>? approvedGroup;
  for (final g in semanticGroups) {
    if ((g['title'] ?? '').toString() == _approvedTitle) {
      approvedGroup = g;
      break;
    }
  }
  if (approvedGroup == null) {
    _die('Approved group "$_approvedTitle" not found in cleanup plan.');
  }
  final group = approvedGroup!;

  final canonicalId =
      (group['canonicalCandidatePbId'] ?? '').toString().trim();
  final deleteIds = (group['duplicateCandidatePbIds'] as List?)
          ?.map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList() ??
      [];
  final forbiddenIds = <String>{};
  for (final g in semanticGroups) {
    final title = (g['title'] ?? '').toString();
    if (title == _approvedTitle) continue;
    forbiddenIds.add((g['canonicalCandidatePbId'] ?? '').toString());
    for (final id in (g['duplicateCandidatePbIds'] as List?) ?? []) {
      forbiddenIds.add(id.toString());
    }
    for (final e in (g['entries'] as List?) ?? []) {
      if (e is Map) forbiddenIds.add((e['pbId'] ?? '').toString());
    }
  }
  forbiddenIds.removeWhere((s) => s.isEmpty);

  for (final id in deleteIds) {
    if (forbiddenIds.contains(id)) {
      _die('Delete id $id belongs to a non-approved group.');
    }
    if (id == canonicalId) {
      _die('Canonical id $canonicalId appears in delete list.');
    }
  }

  final recordRefs = (group['recordReferences'] as List?) ?? [];
  if (recordRefs.isNotEmpty) {
    _die('Approved group has recordReferences — cannot auto-delete.');
  }

  final expectedDeleteCount = deleteIds.length;
  if (expectedDeleteCount == 0) {
    _die('No duplicate candidate ids in approved group.');
  }

  final baseUrl = _env('PB_BASE_URL', _defaultPbUrl).replaceAll(RegExp(r'/$'), '');
  final generatedAt = DateTime.now().toUtc().toIso8601String();
  final stamp = generatedAt.replaceAll(RegExp(r'[:.]'), '-');

  stderr.writeln('=== Price Reporter cleanup apply ===');
  stderr.writeln('Plan: $planPath');
  stderr.writeln('Approved title: $_approvedTitle');
  stderr.writeln('Expected deletes from JSON: $expectedDeleteCount');

  final pb = await _authenticatedPb(baseUrl);
  final uid = pb.authStore.record?.id.trim() ?? '';
  if (uid.isEmpty) _die('Auth ok but no profile id.');

  stderr.writeln('Auth OK. user=$uid');

  final plans = await _fetchAll(pb, 'plans', 'user_id = "$uid"');
  final records = await _fetchAll(pb, 'records', 'user_id = "$uid"');

  final prePlansCount = plans.length;
  final plansById = {for (final p in plans) p.id: p};

  final recordsByPlanId = <String, List<String>>{};
  for (final r in records) {
    final sp = _scalarFk(r.data['source_plan_id']);
    if (sp == null || sp.isEmpty) continue;
    recordsByPlanId.putIfAbsent(sp, () => []).add(r.id);
  }

  // Verify every delete id exists and matches approved group.
  final referenceFingerprintRow = plansById[canonicalId];
  if (referenceFingerprintRow == null) {
    _die('Canonical id $canonicalId not found on server.');
  }
  final refFp = semanticExactFingerprint({
    ...referenceFingerprintRow!.data,
    'id': referenceFingerprintRow.id,
    'user_id': referenceFingerprintRow.data['user_id'],
  });

  for (final id in deleteIds) {
    final row = plansById[id];
    if (row == null) {
      _die(
        'Delete candidate $id missing on server. '
        'Run a fresh dry-run audit.',
      );
    }
    final planRow = row!;
    final title = (planRow.data['title'] ?? '').toString();
    if (title != _approvedTitle) {
      _die('Delete candidate $id title mismatch: "$title"');
    }
    final fp = semanticExactFingerprint({
      ...planRow.data,
      'id': planRow.id,
    });
    if (fp != refFp) {
      _die('Delete candidate $id fingerprint mismatch vs canonical.');
    }
    final refs = recordsByPlanId[id] ?? [];
    if (refs.isNotEmpty) {
      _die('Delete candidate $id has ${refs.length} record source_plan_id ref(s).');
    }
  }

  final canonicalRefs = recordsByPlanId[canonicalId] ?? [];
  final candidateRefs = <String>[];
  for (final id in deleteIds) {
    candidateRefs.addAll(recordsByPlanId[id] ?? []);
  }

  // Touch-check forbidden groups still on server.
  final sonCount = plans
      .where((p) => (p.data['title'] ?? '').toString() == 'Сон')
      .length;
  final scwCount = plans
      .where((p) => (p.data['title'] ?? '').toString() == 'SCW ADD Mod check status')
      .length;

  stderr.writeln('');
  stderr.writeln('--- PREFLIGHT ---');
  stderr.writeln('pre_apply_plans_count=$prePlansCount');
  stderr.writeln('approved_group_title=$_approvedTitle');
  stderr.writeln('canonical_pb_id=$canonicalId');
  stderr.writeln('delete_candidate_count=$expectedDeleteCount');
  stderr.writeln('first_10_delete_ids=${deleteIds.take(10).join(', ')}');
  stderr.writeln('canonical_record_refs=${canonicalRefs.length}');
  stderr.writeln('candidate_record_refs=${candidateRefs.length}');
  stderr.writeln('son_plans_on_server=$sonCount (selected_delete=0)');
  stderr.writeln('scw_plans_on_server=$scwCount (selected_delete=0)');
  stderr.writeln('other_groups_selected_delete=0');
  stderr.writeln('approved_fingerprint_summary=${_fingerprintSummary(refFp)}');

  if (candidateRefs.isNotEmpty) {
    _die('Candidate delete ids have record refs.');
  }

  // Backup
  _ensureDir('tools/exports');
  _ensureDir('tools/reports');
  final plansBackupPath =
      'tools/exports/plans_backup_pre_price_reporter_cleanup_$stamp.json';
  final recordsBackupPath =
      'tools/exports/records_source_plan_refs_pre_price_reporter_cleanup_$stamp.json';
  final postReportPath =
      'tools/reports/plans_price_reporter_cleanup_apply_$stamp.md';

  final recordsWithSource = records
      .where((r) {
        final sp = _scalarFk(r.data['source_plan_id']);
        return sp != null && sp.isNotEmpty;
      })
      .map(
        (r) => {
          'id': r.id,
          'user_id': _scalarFk(r.data['user_id']),
          'source_plan_id': _scalarFk(r.data['source_plan_id']),
          'start_time': _normIso(r.data['start_time']),
          'end_time': _normIso(r.data['end_time']),
          'created': r.created,
          'updated': r.updated,
        },
      )
      .toList();

  try {
    File(plansBackupPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'exportedAt': generatedAt,
        'userId': uid,
        'dryRun': false,
        'phase': 'pre_apply_backup',
        'plans': null,
      }).replaceFirst('"plans": null', '"plans": []'),
    );
    File(plansBackupPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'exportedAt': generatedAt,
        'userId': uid,
        'phase': 'pre_apply_backup',
        'plans': plans.map(_planExportMap).toList(),
      }),
    );
    File(recordsBackupPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'exportedAt': generatedAt,
        'userId': uid,
        'phase': 'pre_apply_backup',
        'records': recordsWithSource,
      }),
    );
  } catch (e) {
    _die('Backup creation failed: $e');
  }
  stderr.writeln('Backup OK: $plansBackupPath');

  // DELETE
  final deleteLog = <Map<String, dynamic>>[];
  var succeeded = 0;
  var failed = 0;

  for (final id in deleteIds) {
    try {
      await pb.collection('plans').delete(id);
      succeeded++;
      deleteLog.add({
        'groupTitle': _approvedTitle,
        'pbId': id,
        'success': true,
      });
      stderr.writeln('DELETE ok: $id');
    } catch (e) {
      failed++;
      deleteLog.add({
        'groupTitle': _approvedTitle,
        'pbId': id,
        'success': false,
        'error': e.toString(),
      });
      stderr.writeln('DELETE FAILED: $id — $e');
      break;
    }
  }

  if (failed > 0) {
    stderr.writeln('Stopped after first DELETE failure.');
  }

  // Post-verify
  final plansAfter = await _fetchAll(pb, 'plans', 'user_id = "$uid"');
  final recordsAfter = await _fetchAll(pb, 'records', 'user_id = "$uid"');
  final postPlansCount = plansAfter.length;
  final actualDecrease = prePlansCount - postPlansCount;

  final prRemaining = plansAfter
      .where((p) => (p.data['title'] ?? '').toString() == _approvedTitle)
      .length;
  final sonAfter = plansAfter
      .where((p) => (p.data['title'] ?? '').toString() == 'Сон')
      .length;
  final scwAfter = plansAfter
      .where((p) => (p.data['title'] ?? '').toString() == 'SCW ADD Mod check status')
      .length;

  final planPbIdsAfter = {for (final p in plansAfter) p.id};
  var dangling = 0;
  for (final r in recordsAfter) {
    final sp = _scalarFk(r.data['source_plan_id']);
    if (sp == null || sp.isEmpty) continue;
    if (!planPbIdsAfter.contains(sp)) dangling++;
  }

  final report = StringBuffer()
    ..writeln('# Price Reporter cleanup apply report')
    ..writeln()
    ..writeln('Generated: $generatedAt')
    ..writeln('Approved group: $_approvedTitle')
    ..writeln()
    ..writeln('## Results')
    ..writeln('| Metric | Value |')
    ..writeln('|--------|------:|')
    ..writeln('| Pre-apply plans | $prePlansCount |')
    ..writeln('| Delete attempted | ${succeeded + failed} |')
    ..writeln('| Delete succeeded | $succeeded |')
    ..writeln('| Delete failed | $failed |')
    ..writeln('| Post-apply plans | $postPlansCount |')
    ..writeln('| Expected decrease | $expectedDeleteCount |')
    ..writeln('| Actual decrease | $actualDecrease |')
    ..writeln('| Remaining "$_approvedTitle" | $prRemaining |')
    ..writeln('| Canonical kept | `$canonicalId` |')
    ..writeln('| Dangling source_plan_id | $dangling |')
    ..writeln('| Сон before/after | $sonCount / $sonAfter |')
    ..writeln('| SCW before/after | $scwCount / $scwAfter |')
    ..writeln('| Records PATCHed | 0 |')
    ..writeln()
    ..writeln('## Backups')
    ..writeln('- `$plansBackupPath`')
    ..writeln('- `$recordsBackupPath`')
    ..writeln()
    ..writeln('## Delete log (last 20)')
    ..writeln();
  for (final entry in deleteLog.take(20)) {
    report.writeln('- `${entry['pbId']}` success=${entry['success']}');
  }
  if (deleteLog.length > 20) {
    report.writeln('- ... ${deleteLog.length - 20} more in stdout');
  }

  File(postReportPath).writeAsStringSync(report.toString());

  print(jsonEncode({
    'auth': 'ok',
    'preApplyPlansCount': prePlansCount,
    'approvedGroupTitle': _approvedTitle,
    'canonicalIdKept': canonicalId,
    'deleteAttempted': succeeded + failed,
    'deleteSucceeded': succeeded,
    'deleteFailed': failed,
    'postApplyPlansCount': postPlansCount,
    'expectedDecrease': expectedDeleteCount,
    'actualDecrease': actualDecrease,
    'remainingPriceReporter': prRemaining,
    'danglingSourcePlanId': dangling,
    'sonUntouched': sonAfter == sonCount,
    'scwUntouched': scwAfter == scwCount,
    'recordsPatched': false,
    'plansBackupPath': plansBackupPath,
    'recordsBackupPath': recordsBackupPath,
    'postReportPath': postReportPath,
  }));

  if (failed > 0) exit(1);
}

String _fingerprintSummary(String fp) {
  final parts = fp.split('|');
  return parts
      .where(
        (p) =>
            p.startsWith('title=') ||
            p.startsWith('cat=') ||
            p.startsWith('start='),
      )
      .join('; ');
}
