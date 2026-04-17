// Email+password and OAuth2 auth via PocketBase (profiles collection).
// Session = user_id in secure storage + PB auth store.
import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result of a PocketBase OAuth2 sign-in attempt (UI maps to snackbars).
enum OAuthSignInResult {
  success,
  cancelled,
  providerMissing,
  networkError,
  unknown,
}

/// Result of biometric-gated quick login using stored email/password.
enum BiometricLoginResult {
  success,
  cancelled,
  noCredentials,
  notAvailable,
  badCredentials,
  unknown,
}

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
  static const String _quickAuthEmail = 'quick_auth_email';
  static const String _quickAuthPassword = 'quick_auth_password';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Valid session: [PocketBase.authStore] only (no stale secure-storage fallback).
  /// All auth I/O uses [PbCollections.profiles], never `users`.
  static Future<String?> checkSession() async {
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final pb = DatabaseService.instance.pocketBase;
      if (!pb.authStore.isValid || pb.authStore.record == null) {
        try {
          await _storage.delete(key: _profileIdKey);
        } catch (_) {}
        return null;
      }
      final data = pb.authStore.record!.data;
      final uid = (data['user_id'] ?? '').toString().trim();
      final id = uid.isNotEmpty ? uid : pb.authStore.record!.id;
      if (id.isEmpty) {
        try {
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
      await pb.collection(PbCollections.profiles).authWithOAuth2(
            providerName,
            (Uri url) {
              unawaited(_launchOAuthUrl(url));
            },
            createData: _oauthProfileCreateData(),
          );
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
      await pb.collection(PbCollections.profiles).authWithPassword(
            cleanEmail,
            password,
          );
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
  /// On duplicate email (typical 400), falls back to [loginWithPassword].
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

    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final pb = DatabaseService.instance.pocketBase;
      final localPart =
          trimmedEmail.contains('@') ? trimmedEmail.split('@').first : trimmedEmail;
      final displayName = localPart.isNotEmpty ? localPart : 'User';
      final newUserId = DatabaseService.newClientUuid();
      await pb.collection(PbCollections.profiles).create(
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
    } on ClientException catch (e) {
      if (kDebugMode) debugPrint('[REGISTER_PB] ${e.statusCode} $e');
      if (e.statusCode == 400) {
        await loginWithPassword(trimmedEmail, password);
        return;
      }
      throw AuthBridgeException(_pbErrorMessage(e), statusCode: e.statusCode);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[AUTH_CRITICAL_ERROR] $e');
        debugPrint('$stack');
      }
      throw AuthBridgeException('network');
    }
    await loginWithPassword(trimmedEmail, password);
  }

  /// Password reset email ([PbCollections.profiles] auth collection).
  static Future<void> requestPasswordReset(String email) async {
    final e = email.trim();
    if (e.isEmpty) {
      throw AuthBridgeException('empty_email');
    }
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      await DatabaseService.instance.pocketBase
          .collection(PbCollections.profiles)
          .requestPasswordReset(e);
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

  /// Saves email/password for optional biometric quick login (secure storage).
  static Future<void> saveQuickLoginCredentials(
    String email,
    String password,
  ) async {
    final e = email.trim();
    if (e.isEmpty || password.isEmpty) return;
    await _storage.write(key: _quickAuthEmail, value: e);
    await _storage.write(key: _quickAuthPassword, value: password);
  }

  static Future<void> clearQuickLoginCredentials() async {
    try {
      await _storage.delete(key: _quickAuthEmail);
      await _storage.delete(key: _quickAuthPassword);
    } catch (_) {}
  }

  static Future<bool> hasQuickLoginCredentials() async {
    try {
      final e = await _storage.read(key: _quickAuthEmail);
      final p = await _storage.read(key: _quickAuthPassword);
      return e != null &&
          e.isNotEmpty &&
          p != null &&
          p.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Device can use biometrics (hardware + enrolled), excluding web.
  static Future<bool> canUseBiometricAuth() async {
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// After local biometric success, signs in with stored credentials.
  static Future<BiometricLoginResult> signInWithBiometric({
    required String localizedReason,
  }) async {
    if (kIsWeb) return BiometricLoginResult.notAvailable;
    final email = await _storage.read(key: _quickAuthEmail);
    final password = await _storage.read(key: _quickAuthPassword);
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return BiometricLoginResult.noCredentials;
    }
    final allowed = await canUseBiometricAuth();
    if (!allowed) return BiometricLoginResult.notAvailable;
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!ok) return BiometricLoginResult.cancelled;
      final signedIn = await signIn(email, password);
      return signedIn
          ? BiometricLoginResult.success
          : BiometricLoginResult.badCredentials;
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricLogin] $e');
      return BiometricLoginResult.unknown;
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
      await clearQuickLoginCredentials();
    } catch (_) {}
    if (kDebugMode) {
      debugPrint('[AUTH] Sessions cleared (PocketBase + profile_id + quick login).');
    }
  }
}
