// Email+password and OAuth2 auth via PocketBase (profiles collection).
import 'dart:async';
import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result of a PocketBase OAuth2 sign-in attempt (UI maps to snackbars).
enum OAuthSignInResult {
  success,
  cancelled,
  providerMissing,
  networkError,
  unknown,
}

/// Password reset request result from the app-owned safe reset route.
enum PasswordResetRequestResult { sent, notFound }

/// UI-facing auth failure (maps from PocketBase [ClientException] or validation).
class AuthBridgeException implements Exception {
  AuthBridgeException(this.message, {this.statusCode});

  /// User-visible or l10n key suffix; prefer showing as-is when from the server.
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// User dismissed OAuth or closed the browser flow without completing sign-in.
class AuthBridgeCancelled implements Exception {}

String _pbErrorMessage(ClientException e) {
  final r = e.response;
  final top = r['message'];
  if (top is String && top.trim().isNotEmpty) return top.trim();
  final data = r['data'];
  if (data is Map<String, dynamic>) {
    for (final v in data.values) {
      if (v is Map && v['message'] is String) {
        final m = (v['message'] as String).trim();
        if (m.isNotEmpty) return m;
      }
    }
  }
  return 'Request failed (${e.statusCode})';
}

class AuthBridge {
  AuthBridge._();

  static const String _profileIdKey = 'profile_id';
  static const String _appLockLastSuccessKey =
      'biometric_app_lock_last_success_ms';
  static const String _appLockLastBackgroundKey =
      'biometric_app_lock_last_background_ms';
  static const Duration appLockInactivityThreshold = Duration(days: 7);

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String? get currentAuthEmail {
    final rec = DatabaseService.instance.pocketBase.authStore.record;
    final email = rec?.data['email']?.toString().trim();
    return (email != null && email.isNotEmpty) ? email : null;
  }

  /// Valid session: [PocketBase.authStore] only (no stale secure-storage fallback).
  /// All auth I/O uses [PbCollections.profiles], never `users`.
  static Future<String?> checkSession() async {
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final pb = DatabaseService.instance.pocketBase;
      if (!pb.authStore.isValid || pb.authStore.record == null) {
        try {
          pb.authStore.clear();
          await _storage.delete(key: _profileIdKey);
        } catch (_) {}
        return null;
      }
      final data = pb.authStore.record!.data;
      final uid = (data['user_id'] ?? '').toString().trim();
      final id = uid.isNotEmpty ? uid : pb.authStore.record!.id;
      if (id.isEmpty) {
        try {
          pb.authStore.clear();
          await _storage.delete(key: _profileIdKey);
        } catch (_) {}
        return null;
      }
      await _storage.write(key: _profileIdKey, value: id);
      return id;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _launchOAuthUrl(Uri url) async {
    final mode = kIsWeb
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication;
    final ok = await launchUrl(url, mode: mode);
    if (!ok && kDebugMode) {
      debugPrint('[OAuth] launchUrl failed for $url');
    }
  }

  static Map<String, dynamic> _oauthProfileCreateData() {
    final newUserId = DatabaseService.newClientUuid();
    return <String, dynamic>{
      'user_id': newUserId,
      'display_name': 'User',
      'primary_language': 'en',
      'theme_mode': 'system',
      'preferred_timezone': 'UTC (UTC+0)',
      'timezone_offset': 0,
      'biometric_enabled': false,
    };
  }

  static Future<void> _persistProfileIdAfterAuth() async {
    final pb = DatabaseService.instance.pocketBase;
    final rec = pb.authStore.record;
    if (rec == null) return;
    final uid = (rec.data['user_id'] ?? '').toString().trim();
    final sessionId = uid.isNotEmpty ? uid : rec.id;
    await _storage.write(key: _profileIdKey, value: sessionId);
    await markAppUnlockSuccessful();
    if (kDebugMode) {
      debugPrint(
        '[PB] auth OK — record id ${rec.id}, business user_id $sessionId @ $kPocketBaseUrl',
      );
    }
  }

  /// OAuth2 names enabled for the `profiles` collection (empty if unreachable).
  static Future<Set<String>> availableOAuthProviderNames() async {
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final m = await DatabaseService.instance.pocketBase
          .collection(PbCollections.profiles)
          .listAuthMethods();
      return {for (final p in m.oauth2.providers) p.name};
    } catch (_) {
      return {};
    }
  }

  /// PocketBase `authWithOAuth2`; opens the provider URL via [url_launcher].
  static Future<OAuthSignInResult> signInWithOAuth(String providerName) async {
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final pb = DatabaseService.instance.pocketBase;
      await pb.collection(PbCollections.profiles).authWithOAuth2(providerName, (
        Uri url,
      ) {
        unawaited(_launchOAuthUrl(url));
      }, createData: _oauthProfileCreateData());
      await _persistProfileIdAfterAuth();
      unawaited(DatabaseService.instance.ensureRecordsRealtimeBridge());
      return OAuthSignInResult.success;
    } on ClientException catch (e) {
      if (kDebugMode) debugPrint('[PB OAuth] $e');
      final orig = e.originalError;
      if (orig is Exception &&
          orig.toString().toLowerCase().contains('missing provider')) {
        return OAuthSignInResult.providerMissing;
      }
      if (orig is StateError) {
        final m = orig.message.toLowerCase();
        if (m.contains('oauth2') || m.contains('state parameters')) {
          return OAuthSignInResult.cancelled;
        }
      }
      return OAuthSignInResult.networkError;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[PB OAuth] $e');
        debugPrint('$stack');
      }
      final s = e.toString().toLowerCase();
      if (s.contains('missing provider')) {
        return OAuthSignInResult.providerMissing;
      }
      return OAuthSignInResult.unknown;
    }
  }

  /// Email + password against [PbCollections.profiles] (never `users`).
  /// Throws [AuthBridgeException] on failure.
  static Future<void> loginWithPassword(String email, String password) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw AuthBridgeException('empty_email');
    }
    if (password.isEmpty) {
      throw AuthBridgeException('empty_password');
    }
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final pb = DatabaseService.instance.pocketBase;
      await pb
          .collection(PbCollections.profiles)
          .authWithPassword(cleanEmail, password);
    } on ClientException catch (e) {
      if (kDebugMode) debugPrint('[AUTH_PB] ${e.statusCode} $e');
      throw AuthBridgeException(_pbErrorMessage(e), statusCode: e.statusCode);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[AUTH_CRITICAL_ERROR] $e');
        debugPrint('$stack');
      }
      throw AuthBridgeException('network');
    }
    await _persistProfileIdAfterAuth();
    unawaited(DatabaseService.instance.ensureRecordsRealtimeBridge());
  }

  /// Register then sign in; throws [AuthBridgeException] on failure.
  static Future<void> register(
    String email,
    String password,
    String passwordConfirm,
  ) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw AuthBridgeException('empty_email');
    }
    if (password.isEmpty) {
      throw AuthBridgeException('empty_password');
    }
    if (password != passwordConfirm) {
      throw AuthBridgeException('password_mismatch');
    }

    var created = false;
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final pb = DatabaseService.instance.pocketBase;
      final localPart = trimmedEmail.contains('@')
          ? trimmedEmail.split('@').first
          : trimmedEmail;
      final displayName = localPart.isNotEmpty ? localPart : 'User';
      final newUserId = DatabaseService.newClientUuid();
      await pb
          .collection(PbCollections.profiles)
          .create(
            body: <String, dynamic>{
              'email': trimmedEmail,
              'password': password,
              'passwordConfirm': passwordConfirm,
              'user_id': newUserId,
              'display_name': displayName,
              'primary_language': 'en',
              'theme_mode': 'system',
              'preferred_timezone': 'UTC (UTC+0)',
              'timezone_offset': 0,
              'biometric_enabled': false,
            },
          );
      created = true;
    } on ClientException catch (e) {
      if (kDebugMode) debugPrint('[REGISTER_PB] ${e.statusCode} $e');
      throw AuthBridgeException(_pbErrorMessage(e), statusCode: e.statusCode);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[AUTH_CRITICAL_ERROR] $e');
        debugPrint('$stack');
      }
      throw AuthBridgeException('network');
    }
    if (created) {
      unawaited(requestVerification(trimmedEmail).catchError((_) {}));
    }
    await loginWithPassword(trimmedEmail, password);
  }

  /// Password reset email via app-owned safe route.
  ///
  /// Falls back to PocketBase's native request endpoint only when the custom
  /// route has not been deployed yet; that fallback cannot distinguish unknown
  /// emails from successful sends.
  static Future<PasswordResetRequestResult> requestPasswordReset(
    String email,
  ) async {
    final e = email.trim();
    if (e.isEmpty) {
      throw AuthBridgeException('empty_email');
    }
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final uri = Uri.parse(
        '$kPocketBaseUrl${PbAppApiRoutes.authRequestPasswordReset}',
      );
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{'email': e}),
      );
      if (response.statusCode == 404) {
        try {
          await DatabaseService.instance.pocketBase
              .collection(PbCollections.profiles)
              .requestPasswordReset(e);
          return PasswordResetRequestResult.sent;
        } on ClientException catch (ex) {
          if (ex.statusCode == 429) {
            throw AuthBridgeException('rate_limited', statusCode: 429);
          }
          throw AuthBridgeException(
            'reset_mail_unavailable',
            statusCode: ex.statusCode,
          );
        }
      }
      if (response.statusCode == 429) {
        throw AuthBridgeException('rate_limited', statusCode: 429);
      }
      if (response.statusCode >= 500) {
        throw AuthBridgeException(
          'reset_mail_unavailable',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthBridgeException(
          'reset_mail_unavailable',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw AuthBridgeException('reset_mail_unavailable');
      }
      if (decoded['exists'] == false) {
        return PasswordResetRequestResult.notFound;
      }
      if (decoded['exists'] == true && decoded['sent'] == true) {
        return PasswordResetRequestResult.sent;
      }
      throw AuthBridgeException('reset_mail_unavailable');
    } on AuthBridgeException {
      rethrow;
    } on FormatException {
      throw AuthBridgeException('reset_mail_unavailable');
    } on ClientException catch (ex) {
      if (ex.statusCode == 429) {
        throw AuthBridgeException('rate_limited', statusCode: 429);
      }
      throw AuthBridgeException(
        'reset_mail_unavailable',
        statusCode: ex.statusCode,
      );
    } catch (_) {
      try {
        await DatabaseService.instance.pocketBase
            .collection(PbCollections.profiles)
            .requestPasswordReset(e);
        return PasswordResetRequestResult.sent;
      } on ClientException catch (ex) {
        if (ex.statusCode == 429) {
          throw AuthBridgeException('rate_limited', statusCode: 429);
        }
        throw AuthBridgeException(
          'reset_mail_unavailable',
          statusCode: ex.statusCode,
        );
      } catch (_) {
        throw AuthBridgeException('reset_mail_unavailable');
      }
    }
  }

  static Future<void> confirmPasswordReset(
    String token,
    String newPassword,
    String newPasswordConfirm,
  ) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      throw AuthBridgeException('empty_reset_token');
    }
    if (newPassword.isEmpty) {
      throw AuthBridgeException('empty_password');
    }
    if (newPassword != newPasswordConfirm) {
      throw AuthBridgeException('password_mismatch');
    }
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      await DatabaseService.instance.pocketBase
          .collection(PbCollections.profiles)
          .confirmPasswordReset(cleanToken, newPassword, newPasswordConfirm);
      await signOut();
    } on ClientException catch (ex) {
      throw AuthBridgeException(_pbErrorMessage(ex), statusCode: ex.statusCode);
    }
  }

  static Future<void> requestVerification(String email) async {
    final e = email.trim();
    if (e.isEmpty) {
      throw AuthBridgeException('empty_email');
    }
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      await DatabaseService.instance.pocketBase
          .collection(PbCollections.profiles)
          .requestVerification(e);
    } on ClientException catch (ex) {
      throw AuthBridgeException(_pbErrorMessage(ex), statusCode: ex.statusCode);
    }
  }

  /// OAuth2 via [PbCollections.profiles]. Throws [AuthBridgeCancelled] if user aborts.
  static Future<void> loginWithOAuth2(String providerName) async {
    final r = await signInWithOAuth(providerName);
    switch (r) {
      case OAuthSignInResult.success:
        return;
      case OAuthSignInResult.cancelled:
        throw AuthBridgeCancelled();
      case OAuthSignInResult.providerMissing:
        throw AuthBridgeException('provider_missing', statusCode: 404);
      case OAuthSignInResult.networkError:
      case OAuthSignInResult.unknown:
        throw AuthBridgeException('oauth_failed');
    }
  }

  static Future<bool> signIn(String email, String password) async {
    try {
      await loginWithPassword(email, password);
      return true;
    } on AuthBridgeException {
      return false;
    }
  }

  /// Creates a new auth record when email is free, then signs in.
  /// [passwordConfirm] must match [password] before any request is sent.
  static Future<bool> registerAccount(
    String email,
    String password,
    String passwordConfirm,
  ) async {
    try {
      await register(email, password, passwordConfirm);
      return true;
    } on AuthBridgeException {
      return false;
    }
  }

  static bool get _isMobileBiometricPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  /// Device can use biometrics (hardware + enrolled), excluding web.
  static Future<bool> canUseBiometricAuth() async {
    if (!_isMobileBiometricPlatform) return false;
    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final enrolled = await auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markAppUnlockSuccessful() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _appLockLastSuccessKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  static Future<void> markAppBackgrounded() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _appLockLastBackgroundKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  static Future<bool> shouldRequireBiometricAppLock() async {
    if (!await canUseBiometricAuth()) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_appLockLastSuccessKey);
      if (last == null || last <= 0) return true;
      final elapsed = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(last),
      );
      return elapsed >= appLockInactivityThreshold;
    } catch (_) {
      return true;
    }
  }

  /// Local app-lock only. This never signs into PocketBase and never replaces server auth.
  static Future<bool> authenticateAppLock({
    required String localizedReason,
  }) async {
    final allowed = await canUseBiometricAuth();
    if (!allowed) return false;
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) await markAppUnlockSuccessful();
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricAppLock] $e');
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
    } catch (_) {}
    if (kDebugMode) {
      debugPrint('[AUTH] Sessions cleared (PocketBase + profile_id).');
    }
  }
}
