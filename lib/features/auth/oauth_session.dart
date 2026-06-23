import 'dart:async';

import 'package:counter/core/constants.dart';
import 'package:counter/core/web_redirect.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_login_yandex/flutter_login_yandex.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Unified user identity. ID_CONTRACT: uid is the single key for both Google and Yandex.
class OAuthUser {
  const OAuthUser({
    required this.uid,
    this.email,
    this.displayName,
    required this.provider,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String provider; // 'google' | 'yandex'
}

/// Auth vault: Google + Yandex sign-in, unified User, IAM token storage for Yandex Cloud.
/// NETWORK_SOVEREIGNTY: Data sync targets Yandex YDB; IAM token stored securely.
class OAuthSession {
  OAuthSession._();

  static final OAuthSession instance = OAuthSession._();

  static const String _keyIamToken = 'ydb_iam_token';
  static const String _keyCurrentUid = 'auth_current_uid';
  static const String _keyProvider = 'auth_provider';

  /// Redirect URI for OAuth. In production web mode uses [kProductionWebUrl] so Google/Yandex redirect back to GitHub Pages.
  static String get redirectUri => webOAuthRedirectUri();

  /// serverClientId MUST be the **Web** client ID so Google returns an id_token Supabase accepts.
  /// On Web, `serverClientId` is not supported (google_sign_in_web asserts), so omit it.
  late final GoogleSignIn _googleSignIn = kIsWeb
      ? GoogleSignIn(scopes: <String>['email', 'profile'])
      : GoogleSignIn(scopes: <String>['email', 'profile'], serverClientId: kGoogleWebClientId);

  final FlutterLoginYandex _yandexLogin = FlutterLoginYandex();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  OAuthUser? _currentUser;
  final StreamController<OAuthUser?> _authController = StreamController<OAuthUser?>.broadcast();

  /// Current signed-in user. Null when signed out or not yet loaded.
  OAuthUser? get currentUser => _currentUser;

  /// Stream of auth state: emits current user on sign-in, null on sign-out.
  Stream<OAuthUser?> get authStateChanges => _authController.stream;

  /// Initialize: restore session from secure storage so uid is available before first network call.
  Future<void> initialize() async {
    try {
      final uid = await _secureStorage.read(key: _keyCurrentUid);
      final provider = await _secureStorage.read(key: _keyProvider);
      if (uid != null && uid.isNotEmpty && provider != null) {
        _currentUser = OAuthUser(
          uid: uid,
          email: null,
          displayName: null,
          provider: provider,
        );
        _authController.add(_currentUser);
      }
    } catch (_) {}
  }

  /// Sign in with Google. AUTH_GATE: INITIALIZATION_GUARD and ID_CONTRACT (Supabase UUID).
  /// Web: uses signInWithOAuth (only reliable way to get a session). Non-Web: uses GoogleSignIn + signInWithIdToken.
  /// BANNED: Do not use google_sign_in accessToken as substitute for idToken in Supabase.
  /// Pass [debugContext] to enable nuclear debug bottom sheets (Login Started, Account NULL, full error+stack).
  Future<OAuthUser?> signInWithGoogle([BuildContext? debugContext]) async {
    void showDebugSheet(String message, {String? stackTrace}) {
      if (debugContext == null || !debugContext.mounted) return;
      final ctx = debugContext;
      showModalBottomSheet<void>(
        context: ctx,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewPadding.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(message, style: Theme.of(ctx).textTheme.bodyLarge),
                  if (stackTrace != null && stackTrace.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('StackTrace:', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    SelectableText(stackTrace, style: const TextStyle(fontSize: 10)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      if (debugContext != null && debugContext.mounted) {
        showDebugSheet('Login Started...');
      }
      // Simple auth: NocoDB uses email+password only. Google sign-in not used.
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        if (debugContext != null && debugContext.mounted) {
          showDebugSheet('Google Account was NULL');
        }
        return null;
      }
      final String uid = account.id.isNotEmpty
          ? account.id
          : 'google_${account.email.hashCode.abs()}';
      final user = OAuthUser(
        uid: uid,
        email: account.email,
        displayName: account.displayName,
        provider: 'google',
      );
      await _setSession(user);
      return user;
    } catch (e, st) {
      debugPrint('signInWithGoogle error: $e\n$st');
      if (debugContext != null && debugContext.mounted) {
        showDebugSheet(e.toString(), stackTrace: st.toString());
      }
      rethrow;
    }
  }

  /// Sign in with Yandex. Returns unified User or null on failure.
  /// Uses flutter_login_yandex; uid derived from token for this session (backend can map token → uid later).
  Future<OAuthUser?> signInWithYandex() async {
    try {
      final response = await _yandexLogin.signIn();
      if (response == null) return null;

      final token = response['token'] as String?;
      if (token == null || token.isEmpty) return null;

      // ID_CONTRACT: stable uid for Yandex. Use deterministic part of token; backend can return canonical uid.
      final String uid = 'yandex_${token.length > 32 ? token.substring(0, 32).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '') : token.hashCode.abs()}';
      final user = OAuthUser(
        uid: uid,
        email: null,
        displayName: null,
        provider: 'yandex',
      );
      await _setSession(user);
      return user;
    } catch (e, st) {
      debugPrint('signInWithYandex error: $e\n$st');
      return null;
    }
  }

  Future<void> _setSession(OAuthUser user) async {
    _currentUser = user;
    _authController.add(user);
    try {
      await _secureStorage.write(key: _keyCurrentUid, value: user.uid);
      await _secureStorage.write(key: _keyProvider, value: user.provider);
    } catch (_) {}
  }

  /// Sign out: clear user and stored keys. Does not clear IAM token (used for YDB API).
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (_) {}
    _currentUser = null;
    _authController.add(null);
    try {
      await _secureStorage.delete(key: _keyCurrentUid);
      await _secureStorage.delete(key: _keyProvider);
    } catch (_) {}
  }

  // ---------- IAM token for Yandex Cloud (YDB API) ----------

  /// Store IAM token securely. Call after obtaining token (e.g. from backend or service account).
  Future<void> setIamToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _secureStorage.delete(key: _keyIamToken);
      return;
    }
    await _secureStorage.write(key: _keyIamToken, value: token);
  }

  /// Read IAM token for Authorization header. Returns null if not set.
  Future<String?> getIamToken() async {
    return _secureStorage.read(key: _keyIamToken);
  }
}
