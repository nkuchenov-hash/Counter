// ---------------------------------------------------------------------------
// AUTH UI — Login / register / forgot password / OAuth (PocketBase `profiles`).
// Styling: global themes from main.dart ([appLightTheme]/[appDarkTheme]); width [kAuthFormMaxWidth].
// ---------------------------------------------------------------------------

import 'package:counter/core/theme.dart';
import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Auth gate: email/password, OAuth2 (PocketBase `profiles` collection only).
/// All server auth goes through [AuthBridge].
class AuthView extends StatefulWidget {
  const AuthView({super.key, this.onSignedIn});

  final VoidCallback? onSignedIn;

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  bool _loading = false;
  bool _loginMode = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _t(String key) => t(currentLocale.value, key);

  void _showMessage(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _mapAuthError(Object e) {
    if (e is AuthBridgeCancelled) return '';
    if (e is AuthBridgeException) {
      switch (e.message) {
        case 'empty_email':
          return _t('auth_empty_email');
        case 'empty_password':
          return _t('auth_enter_password');
        case 'password_mismatch':
          return _t('auth_password_mismatch');
        case 'provider_missing':
          return _t('auth_oauth_not_configured');
        case 'oauth_failed':
          return _t('auth_oauth_failed');
        case 'network':
          return _t('auth_invalid_credentials');
        default:
          return e.message;
      }
    }
    return _t('auth_invalid_credentials');
  }

  Future<void> _onSignedInSuccess() async {
    try {
      widget.onSignedIn?.call();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('NAVIGATION_ERROR: $e');
        debugPrint('$stack');
      }
      if (mounted) _showMessage(_t('auth_navigation_failed'));
    }
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty) {
      _showMessage(_t('auth_empty_email'));
      return;
    }
    if (password.isEmpty) {
      _showMessage(_t('auth_enter_password'));
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthBridge.loginWithPassword(email, password);
      if (!mounted) return;
      setState(() => _loading = false);
      await _onSignedInSuccess();
    } on AuthBridgeException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_mapAuthError(e));
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_t('auth_invalid_credentials'));
      }
      if (kDebugMode) {
        debugPrint('SIGNIN_CAUGHT: $e');
        debugPrint('$stack');
      }
    }
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (email.isEmpty) {
      _showMessage(_t('auth_empty_email'));
      return;
    }
    if (password.isEmpty) {
      _showMessage(_t('auth_enter_password'));
      return;
    }
    if (confirm.isEmpty) {
      _showMessage(_t('auth_confirm_password'));
      return;
    }
    if (password != confirm) {
      _showMessage(_t('auth_password_mismatch'));
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthBridge.register(email, password, confirm);
      if (!mounted) return;
      setState(() => _loading = false);
      await _onSignedInSuccess();
    } on AuthBridgeException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_mapAuthError(e));
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('AUTH_UI_ERROR: $e');
        debugPrint('$stack');
      }
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_t('auth_register_failed'));
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage(_t('auth_empty_email'));
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthBridge.requestPasswordReset(email);
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(_t('auth_reset_email_sent'));
    } on AuthBridgeException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_mapAuthError(e));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_t('auth_reset_email_sent'));
      }
    }
  }

  Future<void> _oauth(String providerName) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthBridge.loginWithOAuth2(providerName);
      if (!mounted) return;
      setState(() => _loading = false);
      await _onSignedInSuccess();
    } on AuthBridgeCancelled {
      if (mounted) setState(() => _loading = false);
    } on AuthBridgeException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_mapAuthError(e));
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_t('auth_oauth_failed'));
      }
      if (kDebugMode) {
        debugPrint('OAUTH_UI: $e');
        debugPrint('$stack');
      }
    }
  }

  InputDecoration _passwordDecoration({
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        tooltip: obscure ? _t('auth_show_password') : _t('auth_hide_password'),
        onPressed: onToggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kAuthFormMaxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _t('auth_headline'),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loginMode ? _t('auth_tab_login') : _t('auth_tab_register'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(_t('auth_tab_login')),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(_t('auth_tab_register')),
                      ),
                    ],
                    selected: {_loginMode},
                    onSelectionChanged: (s) {
                      setState(() {
                        _loginMode = s.first;
                        _confirmController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: _t('auth_email_label'),
                              hintText: _t('auth_email_hint'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: _loginMode
                                ? TextInputAction.done
                                : TextInputAction.next,
                            onSubmitted: (_) => _loginMode ? _signIn() : null,
                            decoration: _passwordDecoration(
                              label: _t('auth_password_label'),
                              obscure: _obscurePassword,
                              onToggle: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          if (_loginMode) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading ? null : _forgotPassword,
                                child: Text(_t('auth_forgot_password')),
                              ),
                            ),
                          ] else
                            const SizedBox(height: 12),
                          if (!_loginMode) ...[
                            TextField(
                              controller: _confirmController,
                              obscureText: _obscureConfirm,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _register(),
                              decoration: _passwordDecoration(
                                label: _t('auth_confirm_password_label'),
                                obscure: _obscureConfirm,
                                onToggle: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _loading
                                ? null
                                : (_loginMode ? _signIn : _register),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _loginMode
                                        ? _t('auth_sign_in')
                                        : _t('auth_create_account'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: theme.colorScheme.outlineVariant),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _t('auth_or_divider'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: theme.colorScheme.outlineVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _oauth(PbOauthProviderNames.google),
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: Text(_t('auth_oauth_google')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _oauth(PbOauthProviderNames.apple),
                        icon: const Icon(Icons.apple, size: 22),
                        label: Text(_t('auth_oauth_apple')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _oauth(PbOauthProviderNames.yandex),
                        icon: const Icon(Icons.login),
                        label: Text(_t('auth_oauth_yandex')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
