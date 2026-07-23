// ignore_for_file: avoid_print
//
// Read-only PocketBase export: Price Reporter timeline records → CSV timesheet.
// Does NOT mutate PocketBase (auth POST only).
//
// Auth (one of):
//   PB_AUTH_JSON — full pb_auth localStorage JSON
//   AUDIT_USER_EMAIL + AUDIT_USER_PASSWORD — profiles auth
//
// Optional: PB_BASE_URL (default production)
//
// Run from repo root:
//   dart run scripts/manual/export_price_reporter_timesheet.dart

import 'dart:convert';
import 'dart:io';

import 'package:counter/shared/time/wall_clock.dart';
import 'package:counter/data/voice/price_reporter_client_match.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:timezone/data/latest.dart' as tz_data;

const _defaultPbUrl = 'https://217-114-0-201.sslip.io';
const _defaultUserEmail = 'Kuchenov@yandex.ru';
const _fallbackUserLabel = 'Nick Kuchenov';
final _rangeStartWall = DateTime(2026, 5, 11);
const _priceReporterNeedle = 'price reporter';

const _mainCsvPath = 'exports/price_reporter_timesheet_2026-05-11_to_now.csv';
const _auditCsvPath =
    'exports/price_reporter_timesheet_2026-05-11_to_now_audit.csv';

final _dateFormat = DateFormat('MMM d, yyyy', 'en_US');

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

int _profileOffsetHours(Map<String, dynamic> profile) {
  final raw = profile['timezone_offset'];
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

String _profilePreferredTz(Map<String, dynamic> profile) {
  return (profile['preferred_timezone'] ?? profile['preferredTimeZone'] ?? '')
      .toString()
      .trim();
}

String _profileUserLabel(Map<String, dynamic> profile) {
  final display = (profile['display_name'] ?? '').toString().trim();
  if (display.isNotEmpty) return display;
  final name = (profile['name'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  final email = (profile['email'] ?? '').toString().trim();
  if (email.isNotEmpty) return email;
  return _fallbackUserLabel;
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

bool _fieldMatchesPriceReporter(String? value) {
  return (value ?? '').trim().toLowerCase() == _priceReporterNeedle;
}

bool _categoryMatchesPriceReporter(Map<String, dynamic> data) {
  if (_fieldMatchesPriceReporter(data['name']?.toString())) return true;
  if (_fieldMatchesPriceReporter(data['category_id']?.toString())) return true;
  if (_fieldMatchesPriceReporter(data['normalized_id']?.toString())) {
    return true;
  }

  final localized = data['localized_names'];
  if (localized is Map) {
    for (final v in localized.values) {
      if (_fieldMatchesPriceReporter(v?.toString())) return true;
    }
  } else if (localized is String && localized.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(localized);
      if (parsed is Map) {
        for (final v in parsed.values) {
          if (_fieldMatchesPriceReporter(v?.toString())) return true;
        }
      }
    } catch (_) {}
  }
  return false;
}

bool _isDescendantOf(
  String categoryId,
  String ancestorId,
  Map<String, String?> parentById,
) {
  var cur = categoryId;
  final seen = <String>{};
  while (true) {
    if (cur == ancestorId) return true;
    if (!seen.add(cur)) return false;
    final parent = parentById[cur];
    if (parent == null || parent.isEmpty) return false;
    cur = parent;
  }
}

Set<String> _collectSubtreeIds(
  String rootId,
  Map<String, List<String>> childrenByParent,
) {
  final result = <String>{rootId};
  final queue = <String>[rootId];
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    for (final child in childrenByParent[cur] ?? const <String>[]) {
      if (result.add(child)) queue.add(child);
    }
  }
  return result;
}

Map<String, String> _categoryNamesById(List<RecordModel> categories) {
  return {
    for (final c in categories)
      c.id: (c.data['name'] ?? c.data['category_id'] ?? c.id).toString(),
  };
}

DateTime? _parseUtc(dynamic raw) {
  final s = (raw ?? '').toString().trim();
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s).toUtc();
  } catch (_) {
    return null;
  }
}

String _joinRawText(String title, String? note) {
  final t = title.trim();
  final n = (note ?? '').trim();
  if (t.isEmpty) return n;
  if (n.isEmpty) return t;
  return '$t $n';
}

String _iso(DateTime dt) => dt.toUtc().toIso8601String();

String _wallIso(DateTime wall) {
  final y = wall.year.toString().padLeft(4, '0');
  final m = wall.month.toString().padLeft(2, '0');
  final d = wall.day.toString().padLeft(2, '0');
  final h = wall.hour.toString().padLeft(2, '0');
  final mi = wall.minute.toString().padLeft(2, '0');
  final s = wall.second.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$mi:$s';
}

void _ensureDir(String path) {
  Directory(path).createSync(recursive: true);
}

void _writeCsv(String path, List<List<dynamic>> rows) {
  final content = const ListToCsvConverter().convert(rows);
  File(path).writeAsStringSync('$content\n');
}

class _ExportRow {
  _ExportRow({
    required this.user,
    required this.client,
    required this.durationMinutes,
    required this.dateLabel,
    required this.note,
    required this.recordId,
    required this.pbRecordId,
    required this.categoryName,
    required this.rawTitle,
    required this.rawNote,
    required this.startUtc,
    required this.endUtc,
    required this.startWall,
    required this.endWall,
    required this.match,
    required this.beforeClient,
    required this.runningClamped,
  });

  final String user;
  final String client;
  final int durationMinutes;
  final String dateLabel;
  final String note;
  final String recordId;
  final String pbRecordId;
  final String categoryName;
  final String rawTitle;
  final String rawNote;
  final DateTime startUtc;
  final DateTime endUtc;
  final DateTime startWall;
  final DateTime endWall;
  final PriceReporterClientMatchResult match;
  final String beforeClient;
  final bool runningClamped;
}

Future<void> main() async {
  tz_data.initializeTimeZones();

  final baseUrl = _env('PB_BASE_URL', _defaultPbUrl).replaceAll(RegExp(r'/$'), '');
  final userEmail = _env('AUDIT_USER_EMAIL', _defaultUserEmail);
  final nowUtc = DateTime.now().toUtc();

  stderr.writeln('=== Price Reporter timesheet export (read-only) ===');
  stderr.writeln('PB: $baseUrl');
  stderr.writeln('User email: $userEmail');
  stderr.writeln('Category match helper: $kPriceReporterClientMatchSource');
  stderr.writeln('Helper extracted: lib/data/voice/price_reporter_client_match.dart');

  final pb = await _authenticatedPb(baseUrl);
  final profile = pb.authStore.record;
  if (profile == null) {
    stderr.writeln('Auth succeeded but no profile record in session.');
    exit(1);
  }

  final uid = profile.id.trim();
  final profileData = Map<String, dynamic>.from(profile.data);
  profileData['email'] ??= (profile.data['email'] ?? '').toString();
  final offsetHours = _profileOffsetHours(profileData);
  final preferredTz = _profilePreferredTz(profileData);
  final userLabel = _profileUserLabel(profileData);

  stderr.writeln('Auth OK.');
  stderr.writeln('Profile id: $uid');
  stderr.writeln('Profile email: ${profileData['email'] ?? userEmail}');
  stderr.writeln('Profile display name: $userLabel');
  stderr.writeln(
    'Profile timezone: preferred_timezone="$preferredTz" timezone_offset=$offsetHours',
  );

  final (rangeStartUtc, _) = utcWallClockDayBoundsUtc(
    _rangeStartWall,
    offsetHours,
    preferredTz,
  );
  final rangeEndUtc = nowUtc;

  final rangeStartWall = toWallClockForLabel(rangeStartUtc, offsetHours, preferredTz);
  final rangeEndWall = toWallClockForLabel(rangeEndUtc, offsetHours, preferredTz);

  stderr.writeln(
    'Date range wall: ${_wallIso(rangeStartWall)} inclusive → ${_wallIso(rangeEndWall)} exclusive',
  );
  stderr.writeln(
    'Date range UTC: ${_iso(rangeStartUtc)} inclusive → ${_iso(rangeEndUtc)} exclusive',
  );

  final categories = await _fetchAll(pb, 'categories', 'user_id = "$uid"');
  final parentById = <String, String?>{
    for (final c in categories) c.id: _scalarFk(c.data['parent_id']),
  };
  final childrenByParent = <String, List<String>>{};
  for (final c in categories) {
    final parent = parentById[c.id];
    if (parent != null && parent.isNotEmpty) {
      childrenByParent.putIfAbsent(parent, () => []).add(c.id);
    }
  }

  final matched = categories
      .where((c) => _categoryMatchesPriceReporter(c.data))
      .toList();

  if (matched.isEmpty) {
    stderr.writeln('No Price Reporter category match. Candidates checked:');
    for (final c in categories) {
      stderr.writeln(
        '  id=${c.id} name=${c.data['name']} category_id=${c.data['category_id']} normalized_id=${c.data['normalized_id']}',
      );
    }
    exit(1);
  }

  final roots = matched
      .where(
        (c) => !matched.any(
          (other) =>
              other.id != c.id && _isDescendantOf(c.id, other.id, parentById),
        ),
      )
      .toList();

  if (roots.length > 1) {
    stderr.writeln(
      'Ambiguous Price Reporter categories (${roots.length} independent matches). Export stopped.',
    );
    for (final c in roots) {
      stderr.writeln(
        '  id=${c.id} name=${c.data['name']} category_id=${c.data['category_id']} parent_id=${parentById[c.id] ?? ''}',
      );
    }
    exit(1);
  }

  final root = roots.first;
  final categoryIds = _collectSubtreeIds(root.id, childrenByParent);
  final categoryNames = _categoryNamesById(categories);

  final subtreeRows = categories
      .where((c) => categoryIds.contains(c.id) && c.id != root.id)
      .map((c) => (id: c.id, data: Map<String, dynamic>.from(c.data)))
      .toList();

  final clientIndex = PriceReporterClientIndex.fromPbSubtree(
    parentPbId: root.id,
    parentData: Map<String, dynamic>.from(root.data),
    subtreeRows: subtreeRows,
  );

  stderr.writeln('Price Reporter parent: id=${root.id} name=${clientIndex.parentDisplayName}');
  stderr.writeln('Child categories loaded: ${subtreeRows.length}');
  stderr.writeln('Allowed Client set count: ${clientIndex.allowedClients.length}');
  stderr.writeln('Keyword/alias entries built: ${clientIndex.keywordAliasCount}');
  stderr.writeln(
    'Ambiguous aliases skipped: ${clientIndex.ambiguousAliasesSkipped}',
  );
  stderr.writeln('Prefix aliases for matching: ${clientIndex.prefixAliases.length}');

  final categoryFilter = categoryIds
      .map((id) => 'category_id = "$id"')
      .join(' || ');
  final records = await _fetchAll(
    pb,
    'records',
    'user_id = "$uid" && start_time < "${_iso(rangeEndUtc)}" && ($categoryFilter)',
  );

  final exportRows = <_ExportRow>[];
  var runningClampedCount = 0;

  for (final r in records) {
    final catId = _scalarFk(r.data['category_id']);
    if (catId == null || !categoryIds.contains(catId)) continue;

    final startUtc = _parseUtc(r.data['start_time']);
    if (startUtc == null) continue;

    final endParsed = _parseUtc(r.data['end_time']);
    final runningOpen = endParsed == null;
    final effectiveEndUtc = runningOpen ? nowUtc : endParsed;

    if (!effectiveEndUtc.isAfter(rangeStartUtc)) continue;
    if (!startUtc.isBefore(rangeEndUtc)) continue;

    final clampStartUtc =
        startUtc.isBefore(rangeStartUtc) ? rangeStartUtc : startUtc;
    final clampEndUtc =
        effectiveEndUtc.isAfter(rangeEndUtc) ? rangeEndUtc : effectiveEndUtc;
    if (!clampEndUtc.isAfter(clampStartUtc)) continue;

    final durationMinutes =
        (clampEndUtc.difference(clampStartUtc).inMilliseconds / 60000).round();
    if (durationMinutes <= 0) continue;

    final startWall =
        toWallClockForLabel(clampStartUtc, offsetHours, preferredTz);
    final endWall = toWallClockForLabel(clampEndUtc, offsetHours, preferredTz);
    final dateLabel = _dateFormat.format(
      DateTime(startWall.year, startWall.month, startWall.day),
    );

    final rawTitle = (r.data['title'] ?? '').toString();
    final rawNote = (r.data['note'] ?? '').toString();
    final rawText = _joinRawText(rawTitle, rawNote);
    final beforeClient = clientBeforeTextRules(
      index: clientIndex,
      recordCategoryPbId: catId,
    );
    final match = resolvePriceReporterClient(
      index: clientIndex,
      rawText: rawText,
      recordCategoryPbId: catId,
    );

    if (runningOpen) runningClampedCount++;

    exportRows.add(
      _ExportRow(
        user: userLabel,
        client: match.client,
        durationMinutes: durationMinutes,
        dateLabel: dateLabel,
        note: match.note,
        recordId: (r.data['record_id'] ?? '').toString(),
        pbRecordId: r.id,
        categoryName: categoryNames[catId] ?? catId,
        rawTitle: rawTitle,
        rawNote: rawNote,
        startUtc: clampStartUtc,
        endUtc: clampEndUtc,
        startWall: startWall,
        endWall: endWall,
        match: match,
        beforeClient: beforeClient,
        runningClamped: runningOpen,
      ),
    );
  }

  exportRows.sort((a, b) {
    final byStart = a.startUtc.compareTo(b.startUtc);
    if (byStart != 0) return byStart;
    return a.pbRecordId.compareTo(b.pbRecordId);
  });

  final totalMinutes =
      exportRows.fold<int>(0, (sum, row) => sum + row.durationMinutes);
  final parentName = clientIndex.parentDisplayName;

  final beforePriceReporterCount = exportRows
      .where((r) => r.beforeClient == parentName)
      .length;
  final afterPriceReporterCount =
      exportRows.where((r) => r.client == parentName).length;

  final reasonCounts = <String, int>{};
  for (final r in exportRows) {
    reasonCounts[r.match.reason] = (reasonCounts[r.match.reason] ?? 0) + 1;
  }

  final ambiguousCount =
      exportRows.where((r) => r.match.confidence == 'ambiguous').length;

  final improved = exportRows
      .where(
        (r) =>
            r.beforeClient == parentName &&
            r.client != parentName &&
            r.client != r.beforeClient,
      )
      .toList();

  final stillParent = exportRows.where((r) => r.client == parentName).toList();

  final invalidClients = exportRows
      .where((r) => !clientIndex.allowedClients.contains(r.client))
      .toList();

  stderr.writeln('Total rows exported: ${exportRows.length}');
  stderr.writeln('Total exported minutes: $totalMinutes');
  stderr.writeln(
    'Total exported hours (report only): ${(totalMinutes / 60).toStringAsFixed(2)}',
  );
  if (runningClampedCount > 0) {
    stderr.writeln(
      'Running records clamped to now: $runningClampedCount (end_time was null)',
    );
  }
  stderr.writeln(
    'Client = $parentName before (category-only baseline): $beforePriceReporterCount',
  );
  stderr.writeln('Client = $parentName after: $afterPriceReporterCount');
  stderr.writeln('Ambiguous rows: $ambiguousCount');
  stderr.writeln('Count by client_extraction_reason:');
  for (final e in reasonCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value))) {
    stderr.writeln('  ${e.key}: ${e.value}');
  }
  if (invalidClients.isNotEmpty) {
    stderr.writeln(
      'ERROR: ${invalidClients.length} rows have Client outside allowed set.',
    );
    exit(1);
  }

  if (exportRows.isEmpty) {
    stderr.writeln('Zero export rows — CSV files not written.');
    exit(0);
  }

  _ensureDir('exports');

  final mainRows = <List<dynamic>>[
    ['User', 'Client', 'Duration', 'Date', 'Note'],
    ...exportRows.map(
      (r) => [r.user, r.client, r.durationMinutes, r.dateLabel, r.note],
    ),
  ];
  final auditRows = <List<dynamic>>[
    [
      'User',
      'Client',
      'Duration',
      'Date',
      'Note',
      'record_id',
      'pb_record_id',
      'category_name',
      'raw_title',
      'raw_note',
      'start_utc',
      'end_utc',
      'start_wall',
      'end_wall',
      'duration_minutes',
      'client_extraction_confidence',
      'client_extraction_reason',
      'matched_keyword_or_alias',
      'matched_category_id',
      'matched_category_name',
      'allowed_client_set_match',
      'app_rule_result',
      'ambiguous_matches',
      'running_clamped',
    ],
    ...exportRows.map(
      (r) => [
        r.user,
        r.client,
        r.durationMinutes,
        r.dateLabel,
        r.note,
        r.recordId,
        r.pbRecordId,
        r.categoryName,
        r.rawTitle,
        r.rawNote,
        _iso(r.startUtc),
        _iso(r.endUtc),
        _wallIso(r.startWall),
        _wallIso(r.endWall),
        r.durationMinutes,
        r.match.confidence,
        r.match.reason,
        r.match.matchedKeywordOrAlias ?? '',
        r.match.matchedCategoryPbId ?? '',
        r.match.matchedCategoryName ?? '',
        r.match.allowedClientSetMatch ? 'true' : 'false',
        r.match.appRuleResult ?? '',
        r.match.ambiguousMatches.join('; '),
        r.runningClamped ? 'true' : 'false',
      ],
    ),
  ];

  _writeCsv(_mainCsvPath, mainRows);
  _writeCsv(_auditCsvPath, auditRows);

  stderr.writeln('Output CSV: $_mainCsvPath');
  stderr.writeln('Audit CSV: $_auditCsvPath');

  stderr.writeln(
    'Improved from $parentName to child category (first ${improved.length < 40 ? improved.length : 40}):',
  );
  final improvedPreview = improved.length < 40 ? improved.length : 40;
  for (var i = 0; i < improvedPreview; i++) {
    final r = improved[i];
    stderr.writeln(
      '  ${i + 1}. ${r.dateLabel} | ${r.durationMinutes}m | client="${r.client}" | reason=${r.match.reason} | note="${r.note}"',
    );
  }

  stderr.writeln(
    'Still $parentName (first ${stillParent.length < 15 ? stillParent.length : 15} examples):',
  );
  final stillPreview = stillParent.length < 15 ? stillParent.length : 15;
  for (var i = 0; i < stillPreview; i++) {
    final r = stillParent[i];
    stderr.writeln(
      '  ${i + 1}. ${r.dateLabel} | note="${_joinRawText(r.rawTitle, r.rawNote)}" | category=${r.categoryName} | reason=${r.match.reason}',
    );
  }

  stdout.writeln('EXPORT_OK rows=${exportRows.length} minutes=$totalMinutes');
  stdout.writeln('MAIN_CSV=$_mainCsvPath');
  stdout.writeln('AUDIT_CSV=$_auditCsvPath');
}
