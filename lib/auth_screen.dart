import 'package:counter/data/auth_bridge.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Auth gate: email + password. Session = profile_id in secure storage.
/// Primary: Sign In. Secondary: Create Account (claim or new).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onSignedIn});

  final VoidCallback? onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showAuthError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    // TEMP: bypass empty checks so signIn is always called for traces
    // if (email.isEmpty) { _showAuthError(...); return; }
    // if (password.isEmpty) { _showAuthError('Enter password'); return; }
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final success = await AuthBridge.signIn(email, password);
      if (!mounted) return;
      setState(() => _loading = false);
      if (success) {
        try {
          widget.onSignedIn?.call();
        } catch (e, stack) {
          print('NAVIGATION_ERROR: $e');
          print(stack);
          if (mounted) _showAuthError('Navigation failed. Please try again.');
          return;
        }
      } else {
        _showAuthError('Invalid email or password.');
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _loading = false);
        _showAuthError('Invalid email or password.');
        print('SIGNIN_CAUGHT: $e');
        print(stack);
      }
    }
  }

  Future<void> _createAccount() async {
    _loading = true;
    setState(() {});
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty) {
      _loading = false;
      setState(() {});
      _showAuthError(t(currentLocale.value, 'enter_email'));
      return;
    }
    if (password.isEmpty) {
      _loading = false;
      setState(() {});
      _showAuthError('Enter password');
      return;
    }
    try {
      final ok = await AuthBridge.registerAccount(email, password);
      if (!mounted) return;
      setState(() => _loading = false);
      if (ok) {
        widget.onSignedIn?.call();
      } else {
        _showAuthError('Could not create account. Please try again.');
      }
    } catch (e, stack) {
      // Global catch: BrowserClientException, CORS, timeout, etc.
      print('AUTH_UI_ERROR: $e');
      print(stack);
      if (mounted) {
        setState(() => _loading = false);
        _showAuthError('Could not create account. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'LIFE OS',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
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
                            labelText: 'Email',
                            hintText: 'you@example.com',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _signIn(),
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            hintText: '••••••••',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _loading ? null : _signIn,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Sign In'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loading ? null : _createAccount,
                          child: const Text('Create Account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
