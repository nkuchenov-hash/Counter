// Email+password auth via PocketBase (profiles collection). Session = user_id in secure storage + PB auth store.
import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pocketbase/pocketbase.dart';

class AuthBridge {
  AuthBridge._();

  static const String _profileIdKey = 'profile_id';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Stored profile id (UUID string used as `user_id` on rows) or null.
  static Future<String?> checkSession() async {
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final pb = DatabaseService.instance.pocketBase;
      if (pb.authStore.isValid && pb.authStore.record != null) {
        final data = pb.authStore.record!.data;
        final uid = (data['user_id'] ?? '').toString().trim();
        final id = uid.isNotEmpty ? uid : pb.authStore.record!.id;
        if (id.isNotEmpty) {
          await _storage.write(key: _profileIdKey, value: id);
          return id;
        }
      }
    } catch (_) {}
    try {
      final v = await _storage.read(key: _profileIdKey);
      if (v == null || v.isEmpty) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> signIn(String email, String password) async {
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final pb = DatabaseService.instance.pocketBase;
      final cleanEmail = email.trim();
      if (cleanEmail.isEmpty) return false;
      await pb.collection(PbCollections.profiles).authWithPassword(
            cleanEmail,
            password,
          );
      final rec = pb.authStore.record;
      if (rec == null) return false;
      final uid = (rec.data['user_id'] ?? '').toString().trim();
      final sessionId = uid.isNotEmpty ? uid : rec.id;
      await _storage.write(key: _profileIdKey, value: sessionId);
      if (kDebugMode) {
        debugPrint(
          '[PB] profiles.authWithPassword OK — record id ${rec.id}, '
          'business user_id $sessionId @ $kPocketBaseUrl',
        );
      }
      return true;
    } on ClientException catch (e) {
      print('AUTH_PB: ${e.statusCode} $e');
      return false;
    } catch (e, stack) {
      print('AUTH_CRITICAL_ERROR: $e');
      print('STACKTRACE: $stack');
      return false;
    }
  }

  /// Creates a new auth record when email is free, then signs in.
  static Future<bool> registerAccount(String email, String password) async {
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final pb = DatabaseService.instance.pocketBase;
      final trimmedEmail = email.trim();
      if (trimmedEmail.isEmpty || password.isEmpty) return false;
      final localPart =
          trimmedEmail.contains('@') ? trimmedEmail.split('@').first : trimmedEmail;
      final displayName =
          localPart.isNotEmpty ? localPart : 'User';
      final newUserId = DatabaseService.newClientUuid();
      await pb.collection(PbCollections.profiles).create(
            body: <String, dynamic>{
              'email': trimmedEmail,
              'password': password,
              'passwordConfirm': password,
              'user_id': newUserId,
              'display_name': displayName,
              'primary_language': 'en',
              'theme_mode': 'system',
              'preferred_timezone': 'UTC (UTC+0)',
              'timezone_offset': 0,
              'biometric_enabled': false,
            },
          );
      return signIn(trimmedEmail, password);
    } on ClientException catch (e) {
      print('REGISTER_PB: ${e.statusCode} $e');
      if (e.statusCode == 400) {
        return signIn(email.trim(), password);
      }
      return false;
    } catch (e, stack) {
      print('AUTH_CRITICAL_ERROR: $e');
      print(stack);
      return false;
    }
  }

  static Future<void> signOut() async {
    try {
      final google = GoogleSignIn();
      await google.signOut();
      await google.disconnect();
    } catch (_) {}
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      DatabaseService.instance.pocketBase.authStore.clear();
    } catch (_) {}
    try {
      await _storage.delete(key: _profileIdKey);
      await _storage.deleteAll();
    } catch (_) {}
    print('AUTH_TRACE: All sessions cleared (Storage + Google + PocketBase)');
  }
}
