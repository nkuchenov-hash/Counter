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

/// Thrown by [AuthBridge.loginWithPassword], [register], [requestPasswordReset],
/// [loginWithOAuth2] so UI can map messages without parsing booleans.
class AuthBridgeException implements Exception {
  AuthBridgeException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthBridge {
  AuthBridge._();

  static const String _profileIdKey = 'profile_id';
  static const String _quickAuthEmail = 'quick_auth_email';
  static const String _quickAuthPassword = 'quick_auth_password';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Returns the business profile id only when [PocketBase.authStore] has a
  /// **valid** session (token not expired). Does not treat cached storage alone
  /// as signed-in — gate the app on [authStore.isValid].
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
      if (id.isNotEmpty) {
        await _storage.write(key: _profileIdKey, value: id);
        return id;
      }
    } catch (_) {}
    try {
      await _storage.delete(key: _profileIdKey);
    } catch (_) {}
    return null;
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

  /// OAuth2 via [PbCollections.profiles] only. Throws [AuthBridgeException] on failure.
  static Future<void> loginWithOAuth2(String provider) async {
    final result = await signInWithOAuth(provider);
    switch (result) {
      case OAuthSignInResult.success:
        return;
      case OAuthSignInResult.cancelled:
        throw AuthBridgeException('oauth_cancelled', null);
      case OAuthSignInResult.providerMissing:
        throw AuthBridgeException('oauth_provider_missing', 404);
      case OAuthSignInResult.networkError:
        throw AuthBridgeException('oauth_network', null);
      case OAuthSignInResult.unknown:
        throw AuthBridgeException('oauth_unknown', null);
    }
  }

  /// Email/password against [PbCollections.profiles] (`authWithPassword`).
  static Future<void> loginWithPassword(String email, String password) async {
    await DatabaseService.instance.ensurePocketBaseReady();
    final pb = DatabaseService.instance.pocketBase;
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw AuthBridgeException('empty_email', 400);
    }
    try {
      await pb.collection(PbCollections.profiles).authWithPassword(
            cleanEmail,
            password,
          );
      final rec = pb.authStore.record;
      if (rec == null) {
        throw AuthBridgeException('auth_failed', null);
      }
      final uid = (rec.data['user_id'] ?? '').toString().trim();
      final sessionId = uid.isNotEmpty ? uid : rec.id;
      await _storage.write(key: _profileIdKey, value: sessionId);
      if (kDebugMode) {
        debugPrint(
          '[PB] profiles.authWithPassword OK — record id ${rec.id}, '
          'business user_id $sessionId @ $kPocketBaseUrl',
        );
      }
      unawaited(DatabaseService.instance.ensureRecordsRealtimeBridge());
    } on ClientException catch (e) {
      if (kDebugMode) debugPrint('[AUTH_PB] ${e.statusCode} $e');
      throw AuthBridgeException(e.toString(), e.statusCode);
    } catch (e, stack) {
      if (e is AuthBridgeException) rethrow;
      if (kDebugMode) {
        debugPrint('[AUTH_CRITICAL_ERROR] $e');
        debugPrint('$stack');
      }
      throw AuthBridgeException(e.toString(), null);
    }
  }

  /// Same as [loginWithPassword] but returns [bool] for biometric / legacy call sites.
  static Future<bool> signIn(String email, String password) async {
    try {
      await loginWithPassword(email, password);
      return true;
    } on AuthBridgeException {
      return false;
    }
  }

  /// Register then sign in; all requests use [PbCollections.profiles] only.
  static Future<void> register(
    String email,
    String password,
    String passwordConfirm,
  ) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw AuthBridgeException('missing_fields', 400);
    }
    if (password != passwordConfirm) {
      throw AuthBridgeException('password_mismatch', 400);
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
      await loginWithPassword(trimmedEmail, password);
    } on ClientException catch (e) {
      if (kDebugMode) debugPrint('[REGISTER_PB] ${e.statusCode} $e');
      if (e.statusCode == 400) {
        await loginWithPassword(trimmedEmail, password);
        return;
      }
      throw AuthBridgeException(e.toString(), e.statusCode);
    } catch (e, stack) {
      if (e is AuthBridgeException) rethrow;
      if (kDebugMode) {
        debugPrint('[AUTH_CRITICAL_ERROR] $e');
        debugPrint('$stack');
      }
      throw AuthBridgeException(e.toString(), null);
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

  /// POST …/collections/profiles/request-password-reset
  static Future<void> requestPasswordReset(String email) async {
    final e = email.trim();
    if (e.isEmpty) {
      throw AuthBridgeException('empty_email', 400);
    }
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      await DatabaseService.instance.pocketBase
          .collection(PbCollections.profiles)
          .requestPasswordReset(e);
    } on ClientException catch (ex) {
      throw AuthBridgeException(ex.toString(), ex.statusCode);
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
