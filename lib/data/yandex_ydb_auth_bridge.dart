// ---------------------------------------------------------------------------
// Auth bridge for YDB (Russia): uid from AuthService; session stored in app_sessions in Yandex Cloud (backend responsibility).
// ---------------------------------------------------------------------------

import 'package:counter/auth_service.dart';
import 'package:counter/data/auth_bridge.dart';

/// YDB auth: current user from AuthService (Google/Yandex native). Backend stores session in app_sessions when user signs in.
class YandexYdbAuthBridge implements AuthBridge {
  @override
  String? getCurrentUid() => AuthService.instance.currentUser?.uid;

  @override
  Future<void> signInWithGoogle() async {
    await AuthService.instance.signInWithGoogle();
  }

  @override
  Future<void> signInWithYandex() async {
    await AuthService.instance.signInWithYandex();
  }

  @override
  Future<void> exchangeCodeForSession(String authCode) async {
    // Supabase OAuth callback; when using YDB we do not use Supabase auth. No-op. Session for YDB is stored by backend in app_sessions after AuthService sign-in.
  }

  @override
  Future<void> signInWithOtp(String email) async {
    throw UnsupportedError('Email OTP is only available with Supabase. Use Google or Yandex sign-in.');
  }

  @override
  Future<void> verifyOtp(String email, String code) async {
    throw UnsupportedError('Email OTP is only available with Supabase. Use Google or Yandex sign-in.');
  }
}
