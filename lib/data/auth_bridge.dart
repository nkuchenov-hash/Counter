// Simple email+password auth against NocoDB profiles; session = profile_id in secure storage.
import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/nocodb_response.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthBridge {
  AuthBridge._();

  static const String _profileIdKey = 'profile_id';
  /// NocoDB v3 Data API base (`/api/v3/data/{baseId}`); same as [DatabaseService.baseUrl] (HTTPS, no `:8081`).
  static String get _baseUrl => DatabaseService.baseUrl;
  static const String _profilesRecords = 'mkiyat3508jooui/records';
  /// NocoDB column name for stored hash (matches CSV header).
  static const String _passwordColumnKey = 'password';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Auth and Content-Type in headers only (not query params). Required for NocoDB v3.
  static Map<String, String> get _headers => <String, String>{
        'xc-token': DatabaseService.nocoXcToken,
        'Content-Type': 'application/json',
      };

  /// Returns stored profile id (raw string, e.g. UUID or numeric) or null.
  static Future<String?> checkSession() async {
    try {
      final v = await _storage.read(key: _profileIdKey);
      if (v == null || v.isEmpty) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  /// Hashing law: always compare hashed passwords (SHA-256).
  /// EN: sha256(utf8(password)).toString() => hex string.
  /// RU: sha256(utf8(password)).toString() => hex строка.
  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// First created row from Noco POST / list responses; unwrap nested `fields` when present.
  static Map<String, dynamic>? _registrationPayloadFirstRowMap(dynamic resBody) {
    if (resBody is List && resBody.isNotEmpty) {
      final first = resBody.first;
      if (first is! Map) return null;
      final m = Map<String, dynamic>.from(first);
      final nested = m['fields'];
      if (nested is Map) return Map<String, dynamic>.from(nested);
      return m;
    }
    if (resBody is Map) {
      final rm = Map<String, dynamic>.from(resBody);
      final list = rm['list'] ?? rm['records'];
      if (list is List && list.isNotEmpty && list.first is Map) {
        final first = Map<String, dynamic>.from(list.first as Map);
        final nested = first['fields'];
        if (nested is Map) return Map<String, dynamic>.from(nested);
        return first;
      }
      final nested = rm['fields'];
      if (nested is Map) return Map<String, dynamic>.from(nested);
      if (rm.containsKey('user_id') ||
          rm.containsKey('email') ||
          rm.containsKey('userId')) {
        return rm;
      }
    }
    return null;
  }

  static Future<bool> signIn(String email, String password) async {
    print('AUTH_TRACE: Attempting network call for $email');
    try {
      final cleanEmail = email.trim();
      final hashedPassword = _hashPassword(password);
      // Uri.replace encodes query params, avoiding issues with @ and . in email.
      final url = Uri.parse('$_baseUrl/$_profilesRecords').replace(
        queryParameters: <String, String>{
          'where': '(email,eq,$cleanEmail)',
        },
      );
      print('AUTH_TRACE: URL created: $url');
      final res = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection Timeout'),
      );
      print('AUTH_TRACE: Response Code: ${res.statusCode}');
      print('DEBUG: Raw Body: ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final resBody = jsonDecode(res.body);
      if (resBody is! Map<String, dynamic>) return false;
      final response = NocoDbResponse.fromJson(resBody);
      if (response.isEmpty) {
        print('AUTH_LOGIC_FAIL: No record found for email');
        return false;
      }
      final userData = response.first!;
      print('DEBUG: App generated hash: $hashedPassword');
      print('DEBUG: Stored hash in DB: ${userData['password']}');
      print('DEBUG: Match result: ${userData['password'] == hashedPassword}');
      final storedHash = userData['password']?.toString();
      if (storedHash == null || storedHash != hashedPassword) {
        print('AUTH_LOGIC_FAIL: Password mismatch or missing');
        return false;
      }
      // Resolve profile_id: user_id is the unique user identifier in DB and code.
      final id = userData['user_id'] ?? userData['id'] ?? userData['Id'];
      if (id == null) return false;
      await _storage.write(key: _profileIdKey, value: id.toString());
      return true;
    } catch (e, stack) {
      print('AUTH_CRITICAL_ERROR: $e');
      print('STACKTRACE: $stack');
      return false;
    }
  }

  /// Create or claim account (data-safe, no deletion):
  /// - If email exists: PATCH that row's password (keeps existing integer id).
  /// - If email does not exist: POST a new profile row.
  /// - Then call signIn() so secure storage is set to profile_id.
  static Future<bool> registerAccount(String email, String password) async {
    try {
      print('AUTH_TRACE: Starting registration for $email');
      final hashedPassword = _hashPassword(password);
      print('AUTH_TRACE: Password hashed');

      // Check existing by email.
      final whereEmail = '(email,eq,$email)';
      final findUri = Uri.parse('$_baseUrl/$_profilesRecords')
          .replace(queryParameters: <String, String>{'where': whereEmail});
      final findRes = await http.get(findUri, headers: _headers);
      if (findRes.statusCode < 200 || findRes.statusCode >= 300) {
        return false;
      }

      final decoded = jsonDecode(findRes.body);
      if (decoded is! Map<String, dynamic>) return false;
      final list = decoded['list'];
      // If GET returns an EMPTY list (no matching email), immediately create.
      if (list is List && list.isNotEmpty) {
        final row = list.first;
        if (row is Map) {
          final rawId = row['user_id'] ?? row['id'];
          final id = rawId is int
              ? rawId
              : int.tryParse(rawId?.toString() ?? '') ?? 0;
          if (id > 0) {
            await http.patch(
              Uri.parse('$_baseUrl/$_profilesRecords/$id'),
              headers: _headers,
              body: jsonEncode(<String, dynamic>{
                _passwordColumnKey: hashedPassword,
              }),
            );
          }
        }
      } else {
        // Exact slug: .../mkiyat3508jooui/records (no trailing slash).
        final url = Uri.parse(
            '${DatabaseService.baseUrl}/mkiyat3508jooui/records');
        print('AUTH_TRACE: URL parsed: $url');
        // @DATA_MAP.md `profiles`: POST must nest columns under `fields`; include all required columns.
        final newUserId = DatabaseService.newClientUuid();
        final trimmedEmail = email.trim();
        final localPart =
            trimmedEmail.contains('@') ? trimmedEmail.split('@').first : trimmedEmail;
        final displayName =
            localPart.isNotEmpty ? localPart : 'User';
        final body = [
          <String, dynamic>{
            'fields': <String, dynamic>{
              'user_id': newUserId,
              'email': trimmedEmail,
              'password': hashedPassword,
              'display_name': displayName,
              'primary_language': 'en',
              'theme_mode': 'system',
              'preferred_timezone': 'UTC (UTC+0)',
              'timezone_offset': 0,
              'biometric_enabled': false,
            },
          },
        ];
        final bodyEncoded = jsonEncode(body);
        print('AUTH_TRACE: Body encoded: $bodyEncoded');
        try {
          print('AUTH_TRACE: Sending Request...');
          print('FINAL PAYLOAD: $bodyEncoded');
          final response = await http.post(
            Uri.parse(url.toString()),
            headers: <String, String>{
              ..._headers,
              'accept': 'application/json',
            },
            body: bodyEncoded,
          ).timeout(const Duration(seconds: 10));
          print('AUTH_TRACE: Response Received: ${response.statusCode}');
          if (response.statusCode >= 400) {
            print('CRITICAL_DB_REJECTION: ${response.body}');
            print(
                'REGISTRATION_DEBUG: Status ${response.statusCode}, Data: ${response.body}');
            return false;
          }
          if (response.statusCode == 200 ||
              response.statusCode == 201 ||
              response.statusCode == 204) {
            Map<String, dynamic>? data;
            try {
              final raw = response.body.trim();
              if (raw.isNotEmpty) {
                final resBody = jsonDecode(raw);
                data = _registrationPayloadFirstRowMap(resBody);
              }
            } catch (e) {
              print('AUTH_TRACE: Registration response parse skipped: $e');
            }
            print('AUTH_VICTORY_DATA: ${response.body}');
            final createdId = data == null
                ? null
                : (data['user_id'] ?? data['id'] ?? data['Id']);
            final sessionId = (createdId != null &&
                    createdId.toString().trim().isNotEmpty)
                ? createdId.toString().trim()
                : newUserId;
            print(
                'REGISTRATION_SUCCESS: session user_id=$sessionId (from response: ${createdId != null})');
            await _storage.write(key: _profileIdKey, value: sessionId);
            return true;
          }
        } catch (e) {
          print('AUTH_LOCAL_CRASH: $e');
          return false;
        }
      }

      // After sealing/upserting, establish session (e.g. after PATCH or if POST didn't return id).
      return await signIn(email, password);
    } catch (e, stack) {
      print('AUTH_CRITICAL_ERROR: $e');
      print(stack);
      return false;
    }
  }

  /// Clears profile id, Google session, and all secure storage so the user is not stuck in a broken session.
  static Future<void> signOut() async {
    try {
      final google = GoogleSignIn();
      await google.signOut();
      await google.disconnect();
    } catch (_) {}
    try {
      await _storage.delete(key: _profileIdKey);
      await _storage.deleteAll();
    } catch (_) {}
    print('AUTH_TRACE: All sessions cleared (Storage + Google)');
  }
}
