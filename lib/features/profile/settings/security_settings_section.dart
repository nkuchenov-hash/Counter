import 'dart:async';import 'package:counter/core/app_snackbar.dart';import 'package:counter/core/widgets/app_button.dart';import 'package:counter/data/auth_bridge.dart';import 'package:counter/data/database_service.dart';import 'package:counter/l10n/dictionary.dart';import 'package:flutter/foundation.dart' show kIsWeb;import 'package:flutter/material.dart';/// Security (Profile): biometric app-lock toggle. Hidden unless this device can really authenticate.
class SecuritySection extends StatefulWidget {
  const SecuritySection({this.onSaved, this.embedded = false});

  final VoidCallback? onSaved;
  final bool embedded;

  @override
  State<SecuritySection> createState() => SecuritySectionState();
}

class SecuritySectionState extends State<SecuritySection> {
  late final Future<bool> _capabilityFuture = AuthBridge.canUseBiometricAuth();
  bool _sendingPasswordReset = false;

  String _mapPasswordResetError(Object error) {
    if (error is AuthBridgeException && error.statusCode == 429) {
      return t(currentLocale.value, 'auth_too_many_attempts');
    }
    return t(currentLocale.value, 'profile_password_reset_send_failed');
  }

  Future<void> _sendPasswordReset(String email) async {
    if (_sendingPasswordReset) return;
    setState(() => _sendingPasswordReset = true);
    try {
      final result = await AuthBridge.requestPasswordReset(email);
      if (!mounted) return;
      switch (result) {
        case PasswordResetRequestResult.sent:
          AppSnack.show(t(currentLocale.value, 'profile_password_reset_sent'));
          break;
        case PasswordResetRequestResult.notFound:
          AppSnack.show(
            t(currentLocale.value, 'profile_password_reset_send_failed'),
            error: true,
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        AppSnack.show(_mapPasswordResetError(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _sendingPasswordReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final accountEmail = AuthBridge.currentAuthEmail?.trim() ?? '';
    final hasEmail = accountEmail.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[
          Text(t(loc, 'security_section'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            t(loc, 'profile_password_reset_subtitle'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (!hasEmail) ...[
          const SizedBox(height: 8),
          Text(
            t(loc, 'profile_password_reset_no_email'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        AppButton.secondary(
          label: _sendingPasswordReset
              ? t(loc, 'profile_password_reset_sending')
              : t(loc, 'profile_password_reset_send_button'),
          icon: Icons.mark_email_read_outlined,
          onPressed: hasEmail && !_sendingPasswordReset
              ? () => unawaited(_sendPasswordReset(accountEmail))
              : null,
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: 8),
          FutureBuilder<bool>(
            future: _capabilityFuture,
            builder: (context, snap) {
              if (snap.data != true) return const SizedBox.shrink();
              final s = DatabaseService.instance.settings;
              return SwitchListTile(
                value: s.biometricEnabled,
                onChanged: (bool value) async {
                  try {
                    if (value) {
                      final unlocked = await AuthBridge.authenticateAppLock(
                        localizedReason: t(
                          currentLocale.value,
                          'vault_locked_subtitle',
                        ),
                      );
                      if (!unlocked) return;
                    }
                    final ok = await DatabaseService.instance.saveSettings(
                      s.copyWith(biometricEnabled: value),
                    );
                    if (ok) {
                      if (value) await AuthBridge.markAppUnlockSuccessful();
                      widget.onSaved?.call();
                      AppSnack.saved();
                    } else {
                      AppSnack.failed();
                    }
                  } catch (_) {
                    AppSnack.failed();
                  }
                },
                title: Text(t(currentLocale.value, 'biometric_lock')),
                subtitle: Text(
                  t(currentLocale.value, 'biometric_lock_subtitle'),
                ),
                secondary: const Icon(Icons.fingerprint_rounded),
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
        ],
      ],
    );
  }
}
