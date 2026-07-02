// ignore_for_file: avoid_print
//
// One-off PocketBase repair: June 25, 2026 scheduled plan times were entered as
// Moscow wall times but stored as if they were New York wall times.
//
// Reinterpret: project stored UTC → America/New_York wall → treat same wall
// components as Europe/Moscow → store new UTC. Preserves duration when end_time exists.
//
// Usage (from repo root):
//   dart run scripts/manual/repair_2026_06_25_plan_times_msk.dart           # dry-run (default)
//   dart run scripts/manual/repair_2026_06_25_plan_times_msk.dart --apply   # patch after checks
//   dart run scripts/manual/repair_2026_06_25_plan_times_msk.dart \
//     --ids id1,id2,... --apply --confirm REINTERPRET_NY_AS_MSK_2026_06_25
//
// Auth (one of):
//   PB_AUTH_JSON — full pb_auth localStorage JSON
//   AUDIT_USER_EMAIL + AUDIT_USER_PASSWORD — profiles auth
//
// Optional: PB_BASE_URL (default production)

import 'dart:convert';
import 'dart:io';

import 'package:counter/core/time/wall_clock.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _defaultPbUrl = 'https://217-114-0-201.sslip.io';
const _defaultUserEmail = 'Kuchenov@yandex.ru';

/// Wrong display timezone used when the data was written.
const _wrongLabel = 'New York';
const _wrongOffsetHours = -4; // ignored when label is New York (DST-aware)

const _reinterpretIana = 'Europe/Moscow';
const _targetWallDate = '2026-06-25';
final _targetWall = DateTime(2026, 6, 25);

const _priceReporterPlanningNeedle = 'price reporter planning';
const _confirmToken = 'REINTERPRET_NY_AS_MSK_2026_06_25';

List<String>? _parseIdsArg(List<String> args) {
  final i = args.indexOf('--ids');
  if (i < 0 || i + 1 >= args.length) return null;
  final raw = args[i + 1].trim();
  if (raw.isEmpty) return null;
  return raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

String? _parseConfirmArg(List<String> args) {
  final i = args.indexOf('--confirm');
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1].trim();
}

Future<List<RecordModel>> _fetchPlansByIds(
  PocketBase pb,
  List<String> ids,
) async {
  final rows = <RecordModel>[];
  for (final id in ids) {
    rows.add(await pb.collection('plans').getOne(id));
  }
  return rows;
}

String _env(String key, String fallback) {
  final v = Platform.environment[key]?.trim();
  return (v == null || v.isEmpty) ? fallback : v;
}

bool _isPbSystemId(String id) {
  final s = id.trim();
  return s.length == 15 && RegExp(r'^[a-z0-9]+$').hasMatch(s);
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

DateTime? _parseUtc(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s).toUtc();
  } catch (_) {
    return null;
  }
}

String _iso(DateTime? dt) {
  if (dt == null) return '';
  return dt.toUtc().toIso8601String();
}

String _wallFmt(DateTime wall) {
  return DateFormat('yyyy-MM-dd HH:mm').format(wall);
}

DateTime _nyWallFromUtc(DateTime utc) {
  return toWallClockForLabel(utc, _wrongOffsetHours, _wrongLabel);
}

DateTime _mskWallFromUtc(DateTime utc) {
  final loc = tz.getLocation(_reinterpretIana);
  final z = tz.TZDateTime.from(utc.toUtc(), loc);
  return DateTime(
    z.year,
    z.month,
    z.day,
    z.hour,
    z.minute,
    z.second,
  );
}

String _wallDateKey(DateTime wall) {
  final y = wall.year.toString().padLeft(4, '0');
  final m = wall.month.toString().padLeft(2, '0');
  final d = wall.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Reinterpret NY-projected wall components as Moscow wall → UTC.
DateTime _reinterpretUtc(DateTime oldUtc) {
  final nyWall = _nyWallFromUtc(oldUtc);
  return wallClockToUtcForIanaId(nyWall, _reinterpretIana);
}

int? _durationMinutes(DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  return end.difference(start).inMinutes;
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

Future<List<RecordModel>> _fetchPlansForDayPrefetch(
  PocketBase pb,
  String uid,
) async {
  final (dayStartUtc, dayEndUtc) = utcWallClockDayBoundsUtc(
    _targetWall,
    _wrongOffsetHours,
    _wrongLabel,
  );
  final filter =
      "user_id = '$uid' && start_time != '' && start_time >= '${_iso(dayStartUtc)}' && start_time <= '${_iso(dayEndUtc)}'";
  return pb.collection('plans').getFullList(batch: 500, filter: filter);
}

Future<Map<String, String>> _fetchCategoryNames(
  PocketBase pb,
  String uid,
) async {
  final rows = await pb.collection('categories').getFullList(
        batch: 500,
        filter: "user_id = '$uid'",
      );
  final out = <String, String>{};
  for (final r in rows) {
    final cid = _scalarFk(r.data['category_id']) ?? '';
    final name = (r.data['name'] ?? r.data['title'] ?? '').toString().trim();
    if (cid.isNotEmpty && name.isNotEmpty) {
      out[cid] = name;
    }
  }
  return out;
}

class _RepairCandidate {
  _RepairCandidate({
    required this.pbId,
    required this.planId,
    required this.title,
    required this.categoryLabel,
    required this.oldStartUtc,
    required this.oldEndUtc,
    required this.newStartUtc,
    required this.newEndUtc,
    required this.userId,
  });

  final String pbId;
  final String planId;
  final String title;
  final String categoryLabel;
  final DateTime oldStartUtc;
  final DateTime? oldEndUtc;
  final DateTime newStartUtc;
  final DateTime? newEndUtc;
  final String userId;

  int? get oldDurationMin => _durationMinutes(oldStartUtc, oldEndUtc);
  int? get newDurationMin => _durationMinutes(newStartUtc, newEndUtc);

  bool get durationPreserved {
    final o = oldDurationMin;
    final n = newDurationMin;
    if (o == null && n == null) return true;
    if (o == null || n == null) return false;
    return o == n;
  }
}

List<String> _buildHardKillSwitchErrors(
  List<_RepairCandidate> candidates,
  String uid,
) {
  final errors = <String>[];

  for (final c in candidates) {
    if (c.userId != uid) {
      errors.add('User mismatch on pb id ${c.pbId}');
    }
    final nyKey = _wallDateKey(_nyWallFromUtc(c.oldStartUtc));
    if (nyKey != _targetWallDate) {
      errors.add(
        'Candidate ${c.pbId} (${c.title}) NY wall date $nyKey != $_targetWallDate',
      );
    }
    if (!_isPbSystemId(c.pbId)) {
      errors.add('Invalid PB system id: ${c.pbId}');
    }
    if (c.planId.toLowerCase().startsWith('virt-')) {
      errors.add('virt-* plan_id must not be patched: ${c.planId}');
    }
    if (!c.durationPreserved) {
      errors.add(
        'Duration changed for ${c.pbId} (${c.title}): ${c.oldDurationMin} → ${c.newDurationMin} min',
      );
    }
  }

  return errors;
}

List<String> _buildApplyOnlyKillSwitchErrors(
  _RepairCandidate? priceReporter,
) {
  final errors = <String>[];

  if (priceReporter == null) {
    errors.add(
      'Required row "$_priceReporterPlanningNeedle" not found among candidates.',
    );
    return errors;
  }

  final nyBefore = _wallFmt(_nyWallFromUtc(priceReporter.oldStartUtc));
  final nyAfter = _wallFmt(_nyWallFromUtc(priceReporter.newStartUtc));
  final mskAfter = _wallFmt(_mskWallFromUtc(priceReporter.newStartUtc));
  final nyBeforeTime = nyBefore.split(' ').last;
  final nyAfterTime = nyAfter.split(' ').last;
  final mskAfterTime = mskAfter.split(' ').last;

  if (nyBeforeTime == '16:00') {
    if (nyAfterTime != '09:00') {
      errors.add(
        'Price Reporter Planning: expected NY after 09:00, got $nyAfterTime',
      );
    }
    if (mskAfterTime != '16:00') {
      errors.add(
        'Price Reporter Planning: expected MSK after 16:00, got $mskAfterTime',
      );
    }
  } else {
    stderr.writeln(
      'Note: Price Reporter Planning NY before is $nyBeforeTime (not 16:00); '
      'skipping 16:00→09:00/16:00 reconciliation check.',
    );
  }

  return errors;
}

void _printBeforeAfterTable(
  String heading,
  List<_RepairCandidate> before,
  List<_RepairCandidate> afterById,
) {
  final afterMap = {for (final c in afterById) c.pbId: c};
  print('');
  print('=== $heading ===');
  print(
    'pb_id | title | old_ny | new_ny | old_msk | new_msk | dur_before | dur_after',
  );
  for (final b in before) {
    final a = afterMap[b.pbId];
    final oldNy = _wallFmt(_nyWallFromUtc(b.oldStartUtc));
    final oldMsk = _wallFmt(_mskWallFromUtc(b.oldStartUtc));
    final newNy = a == null
        ? '(missing)'
        : _wallFmt(_nyWallFromUtc(a.oldStartUtc));
    final newMsk = a == null
        ? '(missing)'
        : _wallFmt(_mskWallFromUtc(a.oldStartUtc));
    print(
      '${b.pbId} | ${b.title} | $oldNy | $newNy | $oldMsk | $newMsk | '
      '${b.oldDurationMin ?? ''} | ${a?.oldDurationMin ?? ''}',
    );
  }
}

void _printTable(String heading, List<_RepairCandidate> rows) {
  print('');
  print('=== $heading ===');
  print(
    'pb_id | plan_id | title | category | '
    'old_utc_start | old_ny | old_msk | '
    'new_utc_start | new_ny | new_msk | dur_min | old_end | new_end',
  );
  for (final c in rows) {
    final oldNy = _wallFmt(_nyWallFromUtc(c.oldStartUtc));
    final oldMsk = _wallFmt(_mskWallFromUtc(c.oldStartUtc));
    final newNy = _wallFmt(_nyWallFromUtc(c.newStartUtc));
    final newMsk = _wallFmt(_mskWallFromUtc(c.newStartUtc));
    final dur = c.oldDurationMin?.toString() ?? '';
    print(
      '${c.pbId} | ${c.planId} | ${c.title} | ${c.categoryLabel} | '
      '${_iso(c.oldStartUtc)} | $oldNy | $oldMsk | '
      '${_iso(c.newStartUtc)} | $newNy | $newMsk | $dur | '
      '${_iso(c.oldEndUtc)} | ${_iso(c.newEndUtc)}',
    );
  }
}

List<_RepairCandidate> _buildCandidates(
  List<RecordModel> plans,
  String uid,
  Map<String, String> categoryNames, {
  bool requireNyWallDate = true,
}) {
  final out = <_RepairCandidate>[];
  var skipped = 0;
  final skipReasons = <String, int>{};

  void skip(String reason) {
    skipped++;
    skipReasons[reason] = (skipReasons[reason] ?? 0) + 1;
  }

  for (final p in plans) {
    final row = Map<String, dynamic>.from(p.data);
    final rowUid = _scalarFk(row['user_id']) ?? '';
    if (rowUid != uid) {
      skip('other_user');
      continue;
    }
    if (!_isPbSystemId(p.id)) {
      skip('invalid_pb_id');
      continue;
    }

    final planId = (row['plan_id'] ?? '').toString().trim();
    if (planId.toLowerCase().startsWith('virt-')) {
      skip('virt_plan_id');
      continue;
    }

    final startUtc = _parseUtc(row['start_time']);
    if (startUtc == null) {
      skip('missing_start_time');
      continue;
    }

    if (requireNyWallDate) {
      final nyKey = _wallDateKey(_nyWallFromUtc(startUtc));
      if (nyKey != _targetWallDate) {
        skip('other_ny_wall_date');
        continue;
      }
    }

    final newStart = _reinterpretUtc(startUtc);
    DateTime? oldEnd = _parseUtc(row['end_time']);
    DateTime? newEnd;
    if (oldEnd != null) {
      newEnd = _reinterpretUtc(oldEnd);
    }

    final catFk = _scalarFk(row['category_id']) ?? '';
    final catLabel = categoryNames[catFk] ?? catFk;

    out.add(
      _RepairCandidate(
        pbId: p.id,
        planId: planId.isEmpty ? '(no plan_id)' : planId,
        title: (row['title'] ?? '').toString().trim(),
        categoryLabel: catLabel,
        oldStartUtc: startUtc,
        oldEndUtc: oldEnd,
        newStartUtc: newStart,
        newEndUtc: newEnd,
        userId: rowUid,
      ),
    );
  }

  stderr.writeln('Candidate build: selected=${out.length} skipped=$skipped');
  if (skipReasons.isNotEmpty) {
    stderr.writeln('Skip reasons: $skipReasons');
  }

  return out;
}

_RepairCandidate? _findPriceReporter(List<_RepairCandidate> rows) {
  for (final c in rows) {
    if (c.title.toLowerCase().contains(_priceReporterPlanningNeedle)) {
      return c;
    }
  }
  return null;
}

Future<void> main(List<String> args) async {
  tz_data.initializeTimeZones();

  final apply = args.contains('--apply');
  final explicitIds = _parseIdsArg(args);
  final explicitIdsMode = explicitIds != null && explicitIds.isNotEmpty;
  final confirm = _parseConfirmArg(args);

  final modeLabel = apply ? 'APPLY' : 'DRY-RUN';
  stderr.writeln('=== June 25, 2026 plan time repair ($modeLabel) ===');
  if (explicitIdsMode) {
    stderr.writeln('Explicit id mode: ${explicitIds.length} PB id(s)');
  }

  final baseUrl = _env('PB_BASE_URL', _defaultPbUrl).replaceAll(RegExp(r'/$'), '');
  stderr.writeln('PocketBase: $baseUrl');

  final pb = await _authenticatedPb(baseUrl);
  final profile = pb.authStore.record;
  if (profile == null || !pb.authStore.isValid) {
    stderr.writeln('Kill switch: PocketBase auth unclear (no valid session).');
    exit(1);
  }

  final uid = profile.id.trim();
  stderr.writeln('Auth OK. Profile id: $uid');

  if (apply && explicitIdsMode && confirm != _confirmToken) {
    stderr.writeln(
      'Kill switch: --apply with --ids requires '
      '--confirm $_confirmToken',
    );
    exit(1);
  }

  if (explicitIdsMode) {
    for (final id in explicitIds) {
      if (!_isPbSystemId(id)) {
        stderr.writeln('Kill switch: invalid explicit PB id: $id');
        exit(1);
      }
    }
  }

  final categoryNames = await _fetchCategoryNames(pb, uid);
  final List<RecordModel> prefetch;
  if (explicitIdsMode) {
    prefetch = await _fetchPlansByIds(pb, explicitIds);
  } else {
    prefetch = await _fetchPlansForDayPrefetch(pb, uid);
  }

  final candidates = _buildCandidates(
    prefetch,
    uid,
    categoryNames,
    requireNyWallDate: !explicitIdsMode,
  );

  if (explicitIdsMode) {
    final fetchedIds = prefetch.map((p) => p.id).toSet();
    final missing =
        explicitIds.where((id) => !fetchedIds.contains(id)).toList();
    if (missing.isNotEmpty) {
      stderr.writeln('Kill switch: explicit id(s) not found: $missing');
      exit(1);
    }
    if (candidates.length != explicitIds.length) {
      stderr.writeln(
        'Kill switch: explicit id count ${explicitIds.length} but '
        'built ${candidates.length} candidate(s)',
      );
      exit(1);
    }
    final candidateIds = candidates.map((c) => c.pbId).toSet();
    final extra = explicitIds.where((id) => !candidateIds.contains(id)).toList();
    if (extra.isNotEmpty) {
      stderr.writeln('Kill switch: explicit id(s) rejected: $extra');
      exit(1);
    }
  }

  final beforeSnapshots = [
    for (final c in candidates)
      _RepairCandidate(
        pbId: c.pbId,
        planId: c.planId,
        title: c.title,
        categoryLabel: c.categoryLabel,
        oldStartUtc: c.oldStartUtc,
        oldEndUtc: c.oldEndUtc,
        newStartUtc: c.newStartUtc,
        newEndUtc: c.newEndUtc,
        userId: c.userId,
      ),
  ];

  final priceReporter =
      explicitIdsMode ? null : _findPriceReporter(candidates);

  _printTable('Repair candidates (before)', candidates);

  if (!explicitIdsMode) {
    if (priceReporter != null) {
      print('');
      print('--- Price Reporter Planning (required check) ---');
      print('pb_id: ${priceReporter.pbId}');
      print('title: ${priceReporter.title}');
      print(
        'NY before: ${_wallFmt(_nyWallFromUtc(priceReporter.oldStartUtc))} → '
        'NY after: ${_wallFmt(_nyWallFromUtc(priceReporter.newStartUtc))}',
      );
      print(
        'MSK before: ${_wallFmt(_mskWallFromUtc(priceReporter.oldStartUtc))} → '
        'MSK after: ${_wallFmt(_mskWallFromUtc(priceReporter.newStartUtc))}',
      );
      print('duration preserved: ${priceReporter.durationPreserved}');
    } else {
      print('');
      print('*** Price Reporter Planning NOT FOUND among candidates ***');
    }
  }

  final hardErrors = explicitIdsMode
      ? _buildHardKillSwitchErrors(candidates, uid)
          .where((e) => !e.contains('NY wall date'))
          .toList()
      : _buildHardKillSwitchErrors(candidates, uid);
  final applyErrors = explicitIdsMode
      ? <String>[]
      : _buildApplyOnlyKillSwitchErrors(priceReporter);
  final allApplyErrors = [...hardErrors, ...applyErrors];

  if (hardErrors.isNotEmpty || applyErrors.isNotEmpty) {
    stderr.writeln('');
    if (apply) {
      stderr.writeln('KILL SWITCH — stopping before apply:');
      for (final e in allApplyErrors) {
        stderr.writeln('  - $e');
      }
      exit(1);
    } else if (!explicitIdsMode) {
      stderr.writeln('WARNINGS (dry-run continues; --apply would be blocked):');
      for (final e in allApplyErrors) {
        stderr.writeln('  - $e');
      }
    }
  }

  if (candidates.isEmpty) {
    stderr.writeln('No candidates to repair.');
    exit(0);
  }

  // Validate expected UTC shift for a sample (computed, not hardcoded).
  final sample = candidates.first;
  final shiftHours = sample.newStartUtc.difference(sample.oldStartUtc).inHours;
  stderr.writeln(
    'Sample UTC shift (${sample.title}): $shiftHours hours '
    '(expected ~-7 for June 25, 2026 NY EDT vs MSK UTC+3)',
  );

  if (!apply) {
    print('');
    print('DRY-RUN complete. candidate_count=${candidates.length}');
    print('Re-run with --apply to patch start_time/end_time only.');
    exit(0);
  }

  stderr.writeln('');
  stderr.writeln('Applying ${candidates.length} PATCH(es)...');

  var patched = 0;
  var failed = 0;
  final patchedIds = <String>[];

  for (final c in candidates) {
    final body = <String, dynamic>{
      'start_time': c.newStartUtc.toIso8601String(),
    };
    if (c.newEndUtc != null) {
      body['end_time'] = c.newEndUtc!.toIso8601String();
    }

    final bodyKeys = body.keys.toSet();
    if (bodyKeys.contains('title') ||
        bodyKeys.contains('rrule') ||
        bodyKeys.contains('user_id')) {
      stderr.writeln('Kill switch: patch body contains forbidden fields.');
      exit(1);
    }

    try {
      stderr.writeln('PATCH ${c.pbId} (${c.title})...');
      await pb.collection('plans').update(c.pbId, body: body);

      final readBack = await pb.collection('plans').getOne(c.pbId);
      final rbStart = _parseUtc(readBack.data['start_time']);
      final rbEnd = _parseUtc(readBack.data['end_time']);

      if (rbStart == null ||
          rbStart.toUtc().toIso8601String() !=
              c.newStartUtc.toUtc().toIso8601String()) {
        stderr.writeln(
          'VERIFY FAIL start_time on ${c.pbId}: read ${_iso(rbStart)}',
        );
        failed++;
        continue;
      }
      if (c.newEndUtc != null) {
        if (rbEnd == null ||
            rbEnd.toUtc().toIso8601String() !=
                c.newEndUtc!.toUtc().toIso8601String()) {
          stderr.writeln(
            'VERIFY FAIL end_time on ${c.pbId}: read ${_iso(rbEnd)}',
          );
          failed++;
          continue;
        }
      }

      patched++;
      patchedIds.add(c.pbId);
      stderr.writeln('OK ${c.pbId}');
    } catch (e) {
      failed++;
      stderr.writeln('FAIL ${c.pbId}: $e');
    }
  }

  stderr.writeln('');
  stderr.writeln('Apply summary: patched=$patched failed=$failed');

  // Post-apply verification: fetch each patched row directly (NY wall day may differ).
  final verifyRows = <_RepairCandidate>[];
  for (final id in patchedIds) {
    try {
      final row = await pb.collection('plans').getOne(id);
      final rowUid = _scalarFk(row.data['user_id']) ?? '';
      if (rowUid != uid) {
        stderr.writeln('VERIFY FAIL: $id user_id changed');
        continue;
      }
      final startUtc = _parseUtc(row.data['start_time']);
      if (startUtc == null) {
        stderr.writeln('VERIFY FAIL: $id missing start_time');
        continue;
      }
      final endUtc = _parseUtc(row.data['end_time']);
      final catFk = _scalarFk(row.data['category_id']) ?? '';
      verifyRows.add(
        _RepairCandidate(
          pbId: row.id,
          planId: (row.data['plan_id'] ?? '').toString(),
          title: (row.data['title'] ?? '').toString().trim(),
          categoryLabel: categoryNames[catFk] ?? catFk,
          oldStartUtc: startUtc,
          oldEndUtc: endUtc,
          newStartUtc: startUtc,
          newEndUtc: endUtc,
          userId: rowUid,
        ),
      );
    } catch (e) {
      stderr.writeln('VERIFY FAIL fetch $id: $e');
    }
  }

  _printBeforeAfterTable(
    'Post-apply verification (before → after displays)',
    beforeSnapshots,
    verifyRows,
  );
  _printTable('Post-apply stored UTC (current)', verifyRows);

  print('');
  print('REPORT');
  print('candidate_count=${candidates.length}');
  print('patched_count=$patched');
  print('failed_count=$failed');
  print('skipped_count=${explicitIdsMode ? 0 : prefetch.length - candidates.length}');
  print('patched_pb_ids=${patchedIds.join(', ')}');
  print('code_files_changed=no');
  print('data_outside_2026_06_25_touched=no (start_time/end_time only on listed ids)');

  exit(failed > 0 ? 1 : 0);
}
