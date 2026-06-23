// ignore_for_file: avoid_print
//
// Read-only PocketBase plans duplicate + dangling source_plan_id audit.
// Does NOT mutate PocketBase (auth POST only).
//
// Auth (one of):
//   PB_AUTH_JSON — full pb_auth localStorage JSON
//   AUDIT_USER_EMAIL + AUDIT_USER_PASSWORD — profiles auth
//
// Optional: PB_BASE_URL (default production), AUDIT_USER_ID

import 'dart:convert';
import 'dart:io';

import 'package:pocketbase/pocketbase.dart';

const _defaultPbUrl = 'https://217-114-0-201.sslip.io';
const _defaultUserEmail = 'Kuchenov@yandex.ru';

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

/// Semantic duplicate fingerprint — **excludes** business `plan_id`.
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

String _fingerprintSummary(String fp) {
  final parts = fp.split('|');
  final pick = parts.where((p) {
    return p.startsWith('title=') ||
        p.startsWith('cat=') ||
        p.startsWith('start=') ||
        p.startsWith('init=');
  });
  return pick.join('; ');
}

Map<String, dynamic> _planRowMap(RecordModel p) {
  final m = Map<String, dynamic>.from(p.data);
  m['id'] = p.id;
  m['created'] = p.created;
  m['updated'] = p.updated;
  return m;
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

  stderr.writeln(
    'Auth failed. Set PB_AUTH_JSON or AUDIT_USER_EMAIL + AUDIT_USER_PASSWORD.',
  );
  exit(1);
}

Future<List<RecordModel>> _fetchAll(
  PocketBase pb,
  String collection,
  String filter,
) async {
  return pb.collection(collection).getFullList(batch: 500, filter: filter);
}

String _recommendationForPlanIdGroup(int count, bool hasRecordRefs) {
  if (count >= 2 && hasRecordRefs) return 'manual review — records linked';
  if (count >= 2) return 'likely duplicate — manual review before delete';
  return 'keep all';
}

String _proposedSemanticAction(int count) {
  if (count < 2) return 'keep';
  return 'future: manual review — merge or delete duplicate PB rows after approval';
}

void _ensureDir(String path) {
  Directory(path).createSync(recursive: true);
}

Future<void> main() async {
  final baseUrl = _env('PB_BASE_URL', _defaultPbUrl).replaceAll(RegExp(r'/$'), '');
  final userEmail = _env('AUDIT_USER_EMAIL', _defaultUserEmail);
  final generatedAt = DateTime.now().toUtc().toIso8601String();
  final stamp = generatedAt.replaceAll(RegExp(r'[:.]'), '-');

  stderr.writeln('=== Plans dry-run audit (read-only) ===');
  stderr.writeln('PB: $baseUrl');
  stderr.writeln('User email: $userEmail');

  final pb = await _authenticatedPb(baseUrl);
  final uid = pb.authStore.record?.id?.trim() ?? '';
  if (uid.isEmpty) {
    stderr.writeln('Auth succeeded but no profile id in session.');
    exit(1);
  }
  stderr.writeln('Auth OK. profile id=$uid');

  final plans = await _fetchAll(pb, 'plans', 'user_id = "$uid"');
  final allRecords = await _fetchAll(pb, 'records', 'user_id = "$uid"');

  stderr.writeln('Fetched plans=${plans.length} records=${allRecords.length}');

  final planPbIds = {for (final p in plans) p.id};
  final planMaps = plans.map(_planRowMap).toList();

  // Record refs by plan system id.
  final recordsByPlanId = <String, List<Map<String, dynamic>>>{};
  for (final r in allRecords) {
    final sp = _scalarFk(r.data['source_plan_id']);
    if (sp == null || sp.isEmpty) continue;
    recordsByPlanId.putIfAbsent(sp, () => []).add({
      'pb_id': r.id,
      'record_id': (r.data['record_id'] ?? '').toString(),
      'start_time': _normIso(r.data['start_time']),
      'end_time': _normIso(r.data['end_time']),
      'title': (r.data['title'] ?? '').toString(),
    });
  }

  // A. samePlanIdGroups
  final byBiz = <String, List<RecordModel>>{};
  for (final p in plans) {
    final biz = (p.data['plan_id'] ?? '').toString().trim();
    if (biz.isEmpty) continue;
    byBiz.putIfAbsent(biz, () => []).add(p);
  }
  final samePlanIdGroups =
      byBiz.entries.where((e) => e.value.length >= 2).toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

  // B. semanticDuplicateGroups (no plan_id in fingerprint)
  final bySemantic = <String, List<RecordModel>>{};
  for (final p in plans) {
    final m = _planRowMap(p);
    final fp = semanticExactFingerprint(m);
    bySemantic.putIfAbsent(fp, () => []).add(p);
  }
  final semanticDuplicateGroups =
      bySemantic.entries.where((e) => e.value.length >= 2).toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

  var semanticCandidateRows = 0;
  for (final g in semanticDuplicateGroups) {
    semanticCandidateRows += g.value.length - 1;
  }
  var planIdCandidateRows = 0;
  for (final g in samePlanIdGroups) {
    planIdCandidateRows += g.value.length - 1;
  }
  final duplicateCandidatePbIds = <String>{};
  for (final g in semanticDuplicateGroups) {
    final sorted = List<RecordModel>.from(g.value)
      ..sort((a, b) => a.created.compareTo(b.created));
    for (final p in sorted.skip(1)) {
      duplicateCandidatePbIds.add(p.id);
    }
  }
  for (final g in samePlanIdGroups) {
    final sorted = List<RecordModel>.from(g.value)
      ..sort((a, b) => a.created.compareTo(b.created));
    for (final p in sorted.skip(1)) {
      duplicateCandidatePbIds.add(p.id);
    }
  }
  final candidateDuplicateRows = duplicateCandidatePbIds.length;

  final uniqueBizPlanIds = <String>{
    for (final p in plans)
      if ((p.data['plan_id'] ?? '').toString().trim().isNotEmpty)
        (p.data['plan_id'] ?? '').toString().trim(),
  };

  // Dangling source_plan_id
  final dangling = <Map<String, dynamic>>[];
  for (final r in allRecords) {
    final sp = _scalarFk(r.data['source_plan_id']);
    if (sp == null || sp.isEmpty) continue;
    if (!planPbIds.contains(sp)) {
      dangling.add({
        'recordPbId': r.id,
        'recordBusinessId': (r.data['record_id'] ?? '').toString(),
        'sourcePlanId': sp,
        'title': (r.data['title'] ?? '').toString(),
        'start_time': _normIso(r.data['start_time']),
        'end_time': _normIso(r.data['end_time']),
        'created': r.created,
        'updated': r.updated,
      });
    }
  }

  final missingPlanIds = dangling.map((d) => d['sourcePlanId'] as String).toSet().toList()
    ..sort();

  // Exports
  final exportsDir = 'tools/exports';
  final reportsDir = 'tools/reports';
  _ensureDir(exportsDir);
  _ensureDir(reportsDir);

  final plansBackupPath = '$exportsDir/plans_backup_$stamp.json';
  final recordsRefsPath = '$exportsDir/records_source_plan_refs_$stamp.json';
  final mdReportPath = '$reportsDir/plans_duplicate_audit_$stamp.md';
  final jsonPlanPath = '$reportsDir/plans_duplicate_cleanup_plan_$stamp.json';

  final recordsWithSourcePlan = allRecords
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
          'title': (r.data['title'] ?? '').toString(),
          'record_id': (r.data['record_id'] ?? '').toString(),
        },
      )
      .toList();

  List<Map<String, dynamic>> groupPlanEntries(List<RecordModel> group) {
    group.sort((a, b) => a.created.compareTo(b.created));
    return [
      for (final p in group)
        {
          'pbId': p.id,
          'planId': (p.data['plan_id'] ?? '').toString(),
          'title': (p.data['title'] ?? '').toString(),
          'category_id': _scalarFk(p.data['category_id']),
          'start_time': _normIso(p.data['start_time']),
          'end_time': _normIso(p.data['end_time']),
          'initial_date_key': (p.data['initial_date_key'] ?? '').toString(),
          'created': p.created,
          'updated': p.updated,
          'recordRefs': recordsByPlanId[p.id] ?? [],
        },
    ];
  }

  final samePlanIdJson = <Map<String, dynamic>>[];
  for (final g in samePlanIdGroups) {
    final entries = groupPlanEntries(g.value);
    final refIds = <String>{
      for (final e in entries)
        for (final ref in (e['recordRefs'] as List)) ref['pb_id'] as String,
    };
    samePlanIdJson.add({
      'businessPlanId': g.key,
      'count': g.value.length,
      'pbIds': [for (final p in g.value) p.id],
      'entries': entries,
      'hasRecordReferences': refIds.isNotEmpty,
      'recommendation': _recommendationForPlanIdGroup(g.value.length, refIds.isNotEmpty),
    });
  }

  final semanticJson = <Map<String, dynamic>>[];
  for (final g in semanticDuplicateGroups) {
    final entries = groupPlanEntries(g.value);
    final canonical = entries.first;
    final dupIds = entries.skip(1).map((e) => e['pbId']).toList();
    final refIds = <Map<String, dynamic>>[];
    for (final e in entries) {
      refIds.addAll((e['recordRefs'] as List).cast<Map<String, dynamic>>());
    }
    semanticJson.add({
      'fingerprintSummary': _fingerprintSummary(g.key),
      'canonicalCandidatePbId': canonical['pbId'],
      'duplicateCandidatePbIds': dupIds,
      'title': canonical['title'],
      'category_id': canonical['category_id'],
      'start_time': canonical['start_time'],
      'end_time': canonical['end_time'],
      'initial_date_key': canonical['initial_date_key'],
      'created': canonical['created'],
      'updated': canonical['updated'],
      'recordReferences': refIds,
      'proposedFutureAction': _proposedSemanticAction(g.value.length),
      'entries': entries,
    });
  }

  final estimatedRemainingIfDupesRemoved =
      plans.length - candidateDuplicateRows;

  final cleanupPlan = <String, dynamic>{
    'dryRun': true,
    'mutationsPerformed': false,
    'userEmail': userEmail,
    'userId': uid,
    'generatedAt': generatedAt,
    'summary': {
      'totalPlans': plans.length,
      'uniqueSystemIds': planPbIds.length,
      'uniqueBusinessPlanIds': uniqueBizPlanIds.length,
      'samePlanIdGroups': samePlanIdGroups.length,
      'semanticDuplicateGroups': semanticDuplicateGroups.length,
      'semanticCandidateRows': semanticCandidateRows,
      'planIdCandidateRows': planIdCandidateRows,
      'candidateDuplicateRows': candidateDuplicateRows,
      'danglingSourcePlanIdCount': dangling.length,
      'affectedRecordCount': dangling.length,
      'estimatedRemainingPlansIfDuplicatesRemoved': estimatedRemainingIfDupesRemoved,
    },
    'samePlanIdGroups': samePlanIdJson,
    'semanticDuplicateGroups': semanticJson,
    'danglingRecordReferences': dangling,
  };

  File(jsonPlanPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(cleanupPlan),
  );

  final md = StringBuffer()
    ..writeln('# Plans duplicate dry-run audit')
    ..writeln()
    ..writeln('Generated: $generatedAt (UTC)')
    ..writeln('User: $userEmail (`$uid`)')
    ..writeln('PocketBase: $baseUrl')
    ..writeln('**Read-only — no mutations performed.**')
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..writeln('| Metric | Value |')
    ..writeln('|--------|------:|')
    ..writeln('| Total plans fetched | ${plans.length} |')
    ..writeln('| Unique PocketBase system `id` | ${planPbIds.length} |')
    ..writeln('| Unique business `plan_id` | ${uniqueBizPlanIds.length} |')
    ..writeln('| samePlanIdGroups | ${samePlanIdGroups.length} |')
    ..writeln('| semanticDuplicateGroups | ${semanticDuplicateGroups.length} |')
    ..writeln('| Candidate duplicate rows (combined signals) | $candidateDuplicateRows |')
    ..writeln('| Dangling `source_plan_id` | ${dangling.length} |')
    ..writeln('| Affected records | ${dangling.length} |')
    ..writeln('| Groups requiring manual review | ${samePlanIdGroups.length + semanticDuplicateGroups.length} |')
    ..writeln('| Est. remaining plans if dupes removed | $estimatedRemainingIfDupesRemoved |')
    ..writeln()
    ..writeln('## samePlanIdGroups')
    ..writeln();
  if (samePlanIdGroups.isEmpty) {
    md.writeln('_None._');
  } else {
    for (final g in samePlanIdJson) {
      md.writeln('### business `plan_id`: `${g['businessPlanId']}` (${g['count']} rows)');
      md.writeln('- PocketBase ids: ${(g['pbIds'] as List).join(', ')}');
      md.writeln('- Recommendation: **${g['recommendation']}**');
      for (final e in g['entries'] as List) {
        md.writeln(
          '  - `${e['pbId']}` — "${e['title']}" '
          'start=${e['start_time']} end=${e['end_time']} '
          'created=${e['created']} updated=${e['updated']} '
          'recordRefs=${(e['recordRefs'] as List).length}',
        );
      }
      md.writeln();
    }
  }
  md
    ..writeln('## semanticDuplicateGroups')
    ..writeln();
  if (semanticDuplicateGroups.isEmpty) {
    md.writeln('_None._');
  } else {
    for (final g in semanticJson) {
      md.writeln('### ${g['fingerprintSummary']}');
      md.writeln('- Canonical candidate: `${g['canonicalCandidatePbId']}`');
      md.writeln('- Duplicates: ${(g['duplicateCandidatePbIds'] as List).join(', ')}');
      md.writeln('- Title: "${g['title']}"');
      md.writeln('- category_id: ${g['category_id']}');
      md.writeln('- start/end: ${g['start_time']} / ${g['end_time']}');
      md.writeln('- initial_date_key: ${g['initial_date_key']}');
      md.writeln('- Record refs: ${(g['recordReferences'] as List).length}');
      md.writeln('- Proposed (not executed): ${g['proposedFutureAction']}');
      md.writeln();
    }
  }
  md
    ..writeln('## Dangling `records.source_plan_id`')
    ..writeln()
    ..writeln('Missing plan system ids (${missingPlanIds.length}): ${missingPlanIds.join(', ')}')
    ..writeln();
  if (dangling.isEmpty) {
    md.writeln('_None._');
  } else {
    md.writeln('| record pb id | source_plan_id | start | end |');
    md.writeln('|--------------|----------------|-------|-----|');
    for (final d in dangling) {
      md.writeln(
        '| `${d['recordPbId']}` | `${d['sourcePlanId']}` | ${d['start_time']} | ${d['end_time']} |',
      );
    }
  }
  md
    ..writeln()
    ..writeln('## Local exports')
    ..writeln('- `$plansBackupPath`')
    ..writeln('- `$recordsRefsPath`')
    ..writeln('- `$jsonPlanPath`');

  File(mdReportPath).writeAsStringSync(md.toString());

  File(plansBackupPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'exportedAt': generatedAt,
      'userId': uid,
      'userEmail': userEmail,
      'dryRun': true,
      'plans': planMaps,
    }),
  );

  File(recordsRefsPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'exportedAt': generatedAt,
      'userId': uid,
      'dryRun': true,
      'records': recordsWithSourcePlan,
    }),
  );

  final summary = cleanupPlan['summary'] as Map<String, dynamic>;
  print(jsonEncode({
    'auth': 'ok',
    'mutationsPerformed': false,
    'plansCount': summary['totalPlans'],
    'uniqueSystemIds': summary['uniqueSystemIds'],
    'uniqueBusinessPlanIds': summary['uniqueBusinessPlanIds'],
    'samePlanIdGroups': summary['samePlanIdGroups'],
    'semanticDuplicateGroups': summary['semanticDuplicateGroups'],
    'candidateDuplicateRows': summary['candidateDuplicateRows'],
    'danglingSourcePlanIdCount': summary['danglingSourcePlanIdCount'],
    'affectedRecordCount': summary['affectedRecordCount'],
    'plansBackupPath': plansBackupPath,
    'recordsRefsPath': recordsRefsPath,
    'markdownReportPath': mdReportPath,
    'jsonCleanupPlanPath': jsonPlanPath,
  }));
}
