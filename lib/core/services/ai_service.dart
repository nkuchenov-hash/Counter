// Groq OpenAI-compatible API for Smart Plan. No Flutter imports.
// Paste your API key in [_apiKey] below.

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown when API/network/parse fails after a user-initiated Smart Plan request.
class AiServiceException implements Exception {
  AiServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// PocketBase / Planning UI must not import this file from widgets if you later
/// add Flutter — keep it pure Dart + http only.
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  // ---------------------------------------------------------------------------
  // PASTE YOUR GROQ API KEY HERE (https://console.groq.com/keys).
  // ---------------------------------------------------------------------------
  static const String _apiKey = 'YOUR_GROQ_API_KEY_HERE';

  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  static const String _systemPrompt =
      'You are a JSON-only API. Parse the user\'s text into a daily schedule. '
      'Rules: 1. Estimate logical times if not provided (Morning=09:00, Lunch=13:00, Dinner=19:00). '
      '2. Estimate duration in minutes based on context. '
      '3. Output ONLY a valid JSON array of objects with keys: title (String), '
      'startTime (String "HH:mm"), durationMinutes (int). '
      'Do not include markdown formatting or explanations.';

  /// Calls Groq (OpenAI-compatible) and returns normalized maps:
  /// `title` (String), `startTime` (String "HH:mm"), `durationMinutes` (int).
  /// Drops entries with empty titles. Fills missing time/duration with defaults.
  Future<List<Map<String, dynamic>>> processPlanningText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return <Map<String, dynamic>>[];

    final payload = <String, dynamic>{
      'model': _model,
      'messages': <Map<String, String>>[
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': trimmed},
      ],
      'temperature': 0.2,
    };

    final uri = Uri.parse(_endpoint);
    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      throw AiServiceException('Network error: $e');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiServiceException(
        'API HTTP ${res.statusCode}: ${res.body.length > 200 ? '${res.body.substring(0, 200)}…' : res.body}',
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw AiServiceException('Invalid API JSON: $e');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw AiServiceException('API returned no choices');
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw AiServiceException('Invalid choice shape');
    }
    final msg = first['message'];
    if (msg is! Map<String, dynamic>) {
      throw AiServiceException('Invalid message shape');
    }
    final contentRaw = msg['content'];
    if (contentRaw is! String || contentRaw.trim().isEmpty) {
      throw AiServiceException('Empty model content');
    }

    final List<dynamic> array;
    try {
      array = _parseJsonArrayFromModelContent(contentRaw);
    } catch (e) {
      throw AiServiceException('Could not parse schedule JSON: $e');
    }

    final out = <Map<String, dynamic>>[];
    for (final item in array) {
      if (item is! Map) continue;
      final m = _normalizePlanningItem(Map<String, dynamic>.from(
        item.map((k, v) => MapEntry(k.toString(), v)),
      ));
      final title = (m['title'] as String).trim();
      if (title.isEmpty) continue;
      out.add(m);
    }
    return out;
  }

  static List<dynamic> _parseJsonArrayFromModelContent(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
      final fence = s.lastIndexOf('```');
      if (fence >= 0) s = s.substring(0, fence).trim();
    }
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) return decoded;
    } catch (_) {
      final start = s.indexOf('[');
      final end = s.lastIndexOf(']');
      if (start >= 0 && end > start) {
        final decoded = jsonDecode(s.substring(start, end + 1));
        if (decoded is List) return decoded;
      }
    }
    throw const FormatException('Expected JSON array');
  }

  /// Accept alternate key casing / missing fields; defaults match prompt rules.
  static Map<String, dynamic> _normalizePlanningItem(Map<String, dynamic> m) {
    final title = (m['title'] ?? m['Title'] ?? '').toString().trim();

    var startRaw =
        (m['startTime'] ?? m['start_time'] ?? m['time'] ?? '09:00').toString();
    startRaw = startRaw.trim();
    if (startRaw.isEmpty) startRaw = '09:00';

    final durRaw = m['durationMinutes'] ??
        m['duration_minutes'] ??
        m['duration'] ??
        60;
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

    final hhmm = _normalizeToHHmm(startRaw);

    return <String, dynamic>{
      'title': title,
      'startTime': hhmm,
      'durationMinutes': durationMinutes,
    };
  }

  static final RegExp _hhmm = RegExp(r'^(\d{1,2}):(\d{2})$');

  static String _normalizeToHHmm(String raw) {
    final t = raw.trim();
    final m = _hhmm.firstMatch(t);
    if (m != null) {
      final h = int.tryParse(m.group(1) ?? '') ?? 9;
      final mi = int.tryParse(m.group(2) ?? '') ?? 0;
      final hh = h.clamp(0, 23);
      final mm = mi.clamp(0, 59);
      return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }
    return '09:00';
  }
}
