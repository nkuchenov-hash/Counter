part of '../database_service.dart';

extension PlanAiBackendExtension on DatabaseService {
  /// Natural-language → structured task hints via `POST …/api/ai/parse-task` only.
  /// Flutter stays **LLM-agnostic**; routing and provider live on the server.
  Future<AiParsedTaskHint?> parseTaskViaAiBackend({
    required String rawUtterance,
    String? wallDateKey,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    final text = rawUtterance.trim();
    if (text.isEmpty) return null;
    try {
      await ensurePocketBaseReady();
      final token = _pb.authStore.token.trim();
      if (token.isEmpty) return null;
      final base = kPocketBaseUrl.replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$base${PbAppApiRoutes.aiParseTask}');
      final payload = <String, dynamic>{
        'text': text,
        'ui_locale': currentLocale.value,
        if (wallDateKey != null && wallDateKey.trim().isNotEmpty)
          'wall_date_key': wallDateKey.trim(),
      };
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      int? ih(dynamic v) => v == null ? null : int.tryParse(v.toString());
      return AiParsedTaskHint(
        cleanedTitle:
            map['cleaned_title']?.toString() ?? map['title']?.toString(),
        startHour: ih(map['start_hour'] ?? map['hour']),
        startMinute: ih(map['start_minute'] ?? map['minute']),
        endHour: ih(map['end_hour']),
        endMinute: ih(map['end_minute']),
        rawJson: map,
      );
    } catch (_) {
      return null;
    }
  }

  static final RegExp _aiPlanningHhmm = RegExp(r'^(\d{1,2}):(\d{2})$');

  static String _normalizeAiPlanningTimeHHmm(String raw) {
    final t = raw.trim();
    final m = _aiPlanningHhmm.firstMatch(t);
    if (m != null) {
      final h = int.tryParse(m.group(1) ?? '') ?? 9;
      final mi = int.tryParse(m.group(2) ?? '') ?? 0;
      final hh = h.clamp(0, 23);
      final mm = mi.clamp(0, 59);
      return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }
    return '09:00';
  }

  /// Accept alternate key casing / missing fields; defaults match Smart Plan expectations.
  static Map<String, dynamic> _normalizeAiPlanningItem(Map<String, dynamic> m) {
    final title = (m['title'] ?? m['Title'] ?? '').toString().trim();

    var startRaw = (m['startTime'] ?? m['start_time'] ?? m['time'] ?? '09:00')
        .toString();
    startRaw = startRaw.trim();
    if (startRaw.isEmpty) startRaw = '09:00';

    final durRaw =
        m['durationMinutes'] ?? m['duration_minutes'] ?? m['duration'] ?? 60;
    var durationMinutes = 60;
    if (durRaw is int) {
      durationMinutes = durRaw;
    } else if (durRaw is num) {
      durationMinutes = durRaw.round();
    } else {
      durationMinutes = int.tryParse(durRaw.toString().trim()) ?? 60;
    }
    if (durationMinutes < 1) durationMinutes = 1;
    if (durationMinutes > 24 * 60) durationMinutes = 24 * 60;

    final hhmm = _normalizeAiPlanningTimeHHmm(startRaw);

    final catRaw =
        m['category'] ??
        m['Category'] ??
        m['categoryName'] ??
        m['category_name'];
    String? categoryLabel;
    if (catRaw != null) {
      final s = catRaw.toString().trim();
      if (s.isNotEmpty) {
        final sl = s.toLowerCase();
        if (sl != 'uncategorized' &&
            sl != 'null' &&
            sl != 'none' &&
            sl != 'n/a') {
          categoryLabel = s;
        }
      }
    }

    return <String, dynamic>{
      'title': title,
      'startTime': hhmm,
      'durationMinutes': durationMinutes,
      'category': categoryLabel,
    };
  }

  static List<dynamic>? _aiPlanningItemsListFromDecoded(dynamic decoded) {
    if (decoded is List<dynamic>) return decoded;
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    final raw =
        map['items'] ??
        map['tasks'] ??
        map['planning_items'] ??
        map['schedule'];
    if (raw is List<dynamic>) return raw;
    return null;
  }

  /// Smart Plan: natural-language batch via `POST …/api/ai/parse-task` with `output: planning_items`.
  /// Server returns a JSON object whose `items` / `tasks` / `planning_items` / `schedule` key holds
  /// the task list. Client stays vendor-neutral.
  Future<List<Map<String, dynamic>>> parsePlanningItemsViaAiBackend({
    required String rawText,
    required List<String> allowedCategoryNames,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty) return <Map<String, dynamic>>[];
    if (!_isInitialized || !_hasAuthenticatedUserId) {
      throw AiBackendException('Not signed in');
    }
    await ensurePocketBaseReady();
    final token = _pb.authStore.token.trim();
    if (token.isEmpty) {
      throw AiBackendException('Not signed in');
    }
    final base = kPocketBaseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base${PbAppApiRoutes.aiParseTask}');
    final names = List<String>.from(allowedCategoryNames)
      ..removeWhere((s) => s.trim().isEmpty);
    final payload = <String, dynamic>{
      'text': text,
      'ui_locale': currentLocale.value,
      'output': 'planning_items',
      'allowed_category_names': names,
    };
    late final http.Response res;
    try {
      res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
      throw AiBackendException('Network error: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiBackendException('Request failed (${res.statusCode})');
    }
    late final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (e) {
      throw AiBackendException('Invalid response: $e');
    }
    final rawList = _aiPlanningItemsListFromDecoded(decoded);
    if (rawList == null) {
      throw AiBackendException('No planning items in response');
    }
    final out = <Map<String, dynamic>>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final m = _normalizeAiPlanningItem(
        Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
      final title = (m['title'] as String).trim();
      if (title.isEmpty) continue;
      out.add(m);
    }
    return out;
  }
}
