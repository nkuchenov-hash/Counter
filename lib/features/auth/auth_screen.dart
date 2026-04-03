import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Auth gate: email/password, OAuth2 (PocketBase), optional biometric quick login.
/// All PocketBase access goes through [AuthBridge] only.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onSignedIn});

  final VoidCallback? onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = false;
  bool _loginMode = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _rememberBiometric = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  Set<String> _oauthProviders = {};
  bool _quickLoginStored = false;
  bool _biometricCapable = false;

  @override
  void initState() {
    super.initState();
    _reloadProvidersAndBiometricState();
  }

  Future<void> _reloadProvidersAndBiometricState() async {
    final names = await AuthBridge.availableOAuthProviderNames();
    final quick = await AuthBridge.hasQuickLoginCredentials();
    final bio = await AuthBridge.canUseBiometricAuth();
    if (!mounted) return;
    setState(() {
      _oauthProviders = names;
      _quickLoginStored = quick;
      _biometricCapable = bio;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _t(String key) => t(currentLocale.value, key);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      final success = await AuthBridge.signIn(email, password);
      if (!mounted) return;
      setState(() => _loading = false);
      if (success) {
        if (!kIsWeb && _rememberBiometric && _biometricCapable) {
          await AuthBridge.saveQuickLoginCredentials(email, password);
        }
        await _reloadProvidersAndBiometricState();
        await _onSignedInSuccess();
      } else {
        _showMessage(_t('auth_invalid_credentials'));
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_t('auth_invalid_credentials'));
        if (kDebugMode) {
          debugPrint('SIGNIN_CAUGHT: $e');
          debugPrint('$stack');
        }
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
      final ok = await AuthBridge.registerAccount(email, password, confirm);
      if (!mounted) return;
      setState(() => _loading = false);
      if (ok) {
        if (!kIsWeb && _rememberBiometric && _biometricCapable) {
          await AuthBridge.saveQuickLoginCredentials(email, password);
        }
        await _reloadProvidersAndBiometricState();
        await _onSignedInSuccess();
      } else {
        _showMessage(_t('auth_register_failed'));
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

  Future<void> _oauth(String providerName) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await AuthBridge.signInWithOAuth(providerName);
      if (!mounted) return;
      setState(() => _loading = false);
      switch (result) {
        case OAuthSignInResult.success:
          await _reloadProvidersAndBiometricState();
          await _onSignedInSuccess();
        case OAuthSignInResult.cancelled:
          break;
        case OAuthSignInResult.providerMissing:
          _showMessage(_t('auth_oauth_not_configured'));
        case OAuthSignInResult.networkError:
        case OAuthSignInResult.unknown:
          _showMessage(_t('auth_oauth_failed'));
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

  Future<void> _biometricSignIn() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await AuthBridge.signInWithBiometric(
        localizedReason: _t('auth_biometric_reason'),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      switch (result) {
        case BiometricLoginResult.success:
          await _onSignedInSuccess();
        case BiometricLoginResult.cancelled:
          break;
        case BiometricLoginResult.noCredentials:
          _showMessage(_t('auth_biometric_no_credentials'));
        case BiometricLoginResult.notAvailable:
          _showMessage(_t('biometric_not_available'));
        case BiometricLoginResult.badCredentials:
          _showMessage(_t('auth_invalid_credentials'));
        case BiometricLoginResult.unknown:
          _showMessage(_t('auth_biometric_failed'));
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage(_t('auth_biometric_failed'));
      }
      if (kDebugMode) {
        debugPrint('BIOMETRIC_UI: $e');
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
    final showGoogle = _oauthProviders.contains(PbOauthProviderNames.google);
    final showYandex = _oauthProviders.contains(PbOauthProviderNames.yandex);
    final showAnyOAuth = showGoogle || showYandex;
    final showBioButton =
        !kIsWeb && _loginMode && _quickLoginStored && _biometricCapable;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
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
                  if (showBioButton) ...[
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _biometricSignIn,
                      icon: const Icon(Icons.fingerprint),
                      label: Text(_t('auth_biometric_button')),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                          if (!_loginMode) ...[
                            const SizedBox(height: 12),
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
                          if (!kIsWeb && _biometricCapable) ...[
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              value: _rememberBiometric,
                              onChanged: _loading
                                  ? null
                                  : (v) => setState(
                                      () => _rememberBiometric = v ?? false,
                                    ),
                              title: Text(
                                _t('auth_biometric_remember'),
                                style: theme.textTheme.bodySmall,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
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
                  if (showAnyOAuth) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: theme.colorScheme.outlineVariant,
                          ),
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
                          child: Divider(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (showGoogle)
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _oauth(PbOauthProviderNames.google),
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: Text(_t('auth_oauth_google')),
                      ),
                    if (showGoogle && showYandex) const SizedBox(height: 8),
                    if (showYandex)
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _oauth(PbOauthProviderNames.yandex),
                        icon: const Icon(Icons.login),
                        label: Text(_t('auth_oauth_yandex')),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
