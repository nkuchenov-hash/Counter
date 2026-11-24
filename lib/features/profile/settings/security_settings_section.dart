import 'dart:async';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Account credentials and capability-gated app lock, using canonical controls.
class SecuritySection extends StatefulWidget {
  const SecuritySection({super.key, this.onSaved, this.embedded = false});

  final VoidCallback? onSaved;
  final bool embedded;

  @override
  State<SecuritySection> createState() => SecuritySectionState();
}

class SecuritySectionState extends State<SecuritySection> {
  late final Future<bool> _capabilityFuture = AuthBridge.canUseBiometricAuth();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _editing = false;
  bool _visible = false;
  bool _changing = false;
  bool _sendingPasswordReset = false;
  bool _savingLock = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _clearPasswords() {
    _current.clear();
    _next.clear();
    _confirm.clear();
  }

  Future<void> _changePassword() async {
    if (_changing) return;
    final loc = currentLocale.value;
    final current = _current.text;
    final next = _next.text;
    final confirm = _confirm.text;
    String? error;
    if (current.isEmpty || next.isEmpty) {
      error = t(loc, 'auth_enter_password');
    } else if (next != confirm) {
      error = t(loc, 'auth_password_mismatch');
    } else if (current == next) {
      error = t(loc, 'settings_password_different');
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() { _changing = true; _error = null; });
    try {
      final restored = await AuthBridge.changePassword(
        currentPassword: current, newPassword: next, confirmation: confirm);
      if (!mounted) return;
      TextInput.finishAutofillContext();
      _clearPasswords();
      setState(() { _editing = false; _visible = false; });
      AppSnack.show(t(loc, restored
          ? 'settings_password_changed' : 'settings_password_changed_sign_in'));
      widget.onSaved?.call();
    } on AuthBridgeException catch (e) {
      if (!mounted) return;
      setState(() => _error = t(loc, e.statusCode == 429
          ? 'auth_too_many_attempts'
          : e.message == 'wrong_current_password'
            ? 'settings_password_wrong_current'
            : 'settings_password_change_failed'));
    } catch (_) {
      if (mounted) setState(() => _error = t(loc, 'settings_password_change_failed'));
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _sendPasswordReset(String email) async {
    if (_sendingPasswordReset || _changing) return;
    setState(() => _sendingPasswordReset = true);
    try {
      await AuthBridge.requestPasswordReset(email);
      if (mounted) AppSnack.show(t(currentLocale.value, 'auth_reset_email_sent'));
    } catch (e) {
      if (mounted) AppSnack.show(t(currentLocale.value,
        e is AuthBridgeException && e.statusCode == 429
          ? 'auth_too_many_attempts' : 'profile_password_reset_send_failed'), error: true);
    } finally {
      if (mounted) setState(() => _sendingPasswordReset = false);
    }
  }

  Future<void> _setLock(bool value) async {
    if (_savingLock) return;
    setState(() => _savingLock = true);
    try {
      if (value && !await AuthBridge.authenticateAppLock(
          localizedReason: t(currentLocale.value, 'vault_locked_subtitle'))) return;
      final ok = await DatabaseService.instance.saveBiometricPreference(value);
      if (!mounted) return;
      if (ok) {
        if (value) await AuthBridge.markAppUnlockSuccessful();
        widget.onSaved?.call();
        AppSnack.saved();
      } else {
        AppSnack.failed();
      }
    } catch (_) {
      if (mounted) AppSnack.failed();
    } finally {
      if (mounted) setState(() => _savingLock = false);
    }
  }

  Widget _passwordField(TextEditingController controller, String label, String autofill) =>
      AppTextField(
        controller: controller,
        labelText: label,
        variant: AppTextFieldVariant.password,
        obscureText: !_visible,
        enabled: !_changing,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [autofill],
        onChanged: (_) { if (_error != null) setState(() => _error = null); },
      );

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final email = AuthBridge.currentAuthEmail?.trim() ?? '';
    final hasEmail = email.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(loc, 'auth_password_label'), style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (!_editing)
          AppButton.primary(
            label: t(loc, 'settings_password_change'),
            onPressed: hasEmail ? () => setState(() => _editing = true) : null,
          )
        else AutofillGroup(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _passwordField(_current, t(loc, 'settings_password_current'), AutofillHints.password),
            const SizedBox(height: 12),
            _passwordField(_next, t(loc, 'settings_password_new'), AutofillHints.newPassword),
            const SizedBox(height: 12),
            _passwordField(_confirm, t(loc, 'auth_confirm_password_label'), AutofillHints.newPassword),
            const SizedBox(height: 8),
            Row(children: [
              AppIconButton(
                icon: _visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                tooltip: t(loc, _visible ? 'auth_hide_password' : 'auth_show_password'),
                onPressed: _changing ? null : () => setState(() => _visible = !_visible),
              ),
              Expanded(child: Text(t(loc, 'settings_password_hint'))),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              AppButton.primary(
                label: t(loc, 'settings_password_change'),
                loading: _changing,
                onPressed: _changing ? null : () => unawaited(_changePassword()),
              ),
              AppButton.ghost(
                label: t(loc, 'cancel'),
                onPressed: _changing ? null : () {
                  _clearPasswords();
                  setState(() { _editing = false; _visible = false; _error = null; });
                },
              ),
            ]),
          ],
        )),
        const SizedBox(height: 20),
        Text(t(loc, 'settings_password_recovery'), style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(t(loc, 'settings_password_recovery_hint'), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        AppButton.secondary(
          label: t(loc, 'settings_password_recovery_send'),
          icon: Icons.mail_outline_rounded,
          loading: _sendingPasswordReset,
          onPressed: hasEmail && !_changing && !_sendingPasswordReset
            ? () => unawaited(_sendPasswordReset(email)) : null,
        ),
        if (!hasEmail) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(t(loc, 'profile_password_reset_no_email')),
        ),
        if (!kIsWeb) FutureBuilder<bool>(
          future: _capabilityFuture,
          builder: (context, snap) {
            if (snap.data != true) return const SizedBox.shrink();
            return StreamBuilder<UserSettings>(
              stream: DatabaseService.instance.userSettingsStream,
              initialData: DatabaseService.instance.settings,
              builder: (context, snapshot) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 36),
                  Text(t(loc, 'settings_device_protection'), style: theme.textTheme.titleMedium),
                  AppSettingsControlRow(
                    title: t(loc, 'biometric_lock'),
                    subtitle: t(loc, 'biometric_lock_subtitle'),
                    leading: const Icon(Icons.fingerprint_rounded),
                    value: snapshot.data?.biometricEnabled ?? false,
                    onChanged: _savingLock ? null : (v) => unawaited(_setLock(v)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
