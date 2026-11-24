import 'dart:async';

import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/core/app_snackbar.dart';
import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/auth/oauth_session.dart';
import 'package:counter/features/settings/people/people_settings_page.dart';
import 'package:counter/features/settings/people/people_strings.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Account: current user, People, connected calendars, and logout.
class AccountSecuritySection extends StatelessWidget {
  const AccountSecuritySection({
    super.key,
    this.showPeopleEntry = true,
  });

  final bool showPeopleEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return StreamBuilder<UserSettings>(
      stream: DatabaseService.instance.userSettingsStream,
      initialData: DatabaseService.instance.settings,
      builder: (context, snap) {
        final settings = snap.data ?? DatabaseService.instance.settings;
        final label = ProfileServiceExtension.resolveProfileDisplayLabelFor(
          settings: settings,
        );
        final hydrated = DatabaseService.instance.profileHydratedFromPb;
        final subtitle = label.isNotEmpty
            ? label
            : (hydrated
                  ? (AuthBridge.currentAuthEmail ?? '—')
                  : t(currentLocale.value, 'profile_hydration_error_title'));
        final loc = currentLocale.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodyLarge,
                        children: [
                          TextSpan(text: '${t(loc, 'signed_in_as')} '),
                          TextSpan(
                            text: subtitle,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _logout(context),
                    icon: Icon(
                      Icons.logout_rounded,
                      color: scheme.error,
                      size: 20,
                    ),
                    label: Text(
                      t(loc, 'log_out'),
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showPeopleEntry) ...[
            const Divider(height: 24),
            AppSettingsNavigationRow(
              title: peopleT(loc, 'title'),
              subtitle: peopleT(loc, 'subtitle'),
              leading: const Icon(Icons.people_alt_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PeopleSettingsPage(),
                  ),
                );
              },
            ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = DatabaseService.instance;
    if (db.offlineSync.pendingCount > 0 || db.offlineSync.isSyncing) {
      AppSnack.show(t(currentLocale.value, 'settings_sign_out_pending'), error: true);
      return;
    }
    var showSlowSnackBar = true;
    Future.delayed(const Duration(seconds: 1), () {
      if (showSlowSnackBar) {
        messenger.showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'logging_out'))),
        );
      }
    });
    try {
      await AuthBridge.signOut();
      await OAuthSession.instance.signOut();
    } catch (_) {
      showSlowSnackBar = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'sign_out_failed'))),
        );
      }
    } finally {
      showSlowSnackBar = false;
      try {
        DatabaseService.instance.clearLocalStateOnSignOut();
        DatabaseService.instance.onSignOut?.call();
      } catch (_) {}
    }
  }
}


/// One explicit-save name editor for all account entry points.
class ProfileNameEditor extends StatefulWidget {
  const ProfileNameEditor({super.key, this.onSaved});
  final VoidCallback? onSaved;

  @override
  State<ProfileNameEditor> createState() => _ProfileNameEditorState();
}

class _ProfileNameEditorState extends State<ProfileNameEditor> {
  final _db = DatabaseService.instance;
  late final TextEditingController _name;
  late final StreamSubscription<UserSettings> _subscription;
  late String _confirmed;
  late String _owner;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _confirmed = _db.settings.displayName?.trim() ?? '';
    _owner = _db.settings.userId;
    _name = TextEditingController(text: _confirmed);
    _subscription = _db.userSettingsStream.listen((settings) {
      if (!mounted) return;
      final value = settings.displayName?.trim() ?? '';
      final ownerChanged = settings.userId != _owner;
      if (_saving && !ownerChanged) return;
      setState(() {
        if (ownerChanged || _name.text.trim() == _confirmed) {
          _name.text = value;
        }
        _confirmed = value;
        _owner = settings.userId;
      });
    });
  }

  bool get _canSave => !_saving &&
      _name.text.trim().isNotEmpty && _name.text.trim() != _confirmed;

  Future<void> _save() async {
    if (!_canSave) return;
    final value = _name.text.trim();
    final owner = _owner;
    setState(() => _saving = true);
    bool ok = false;
    try {
      ok = await _db.saveDisplayName(value);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok && _owner == owner) _confirmed = value;
    });
    if (_owner != owner) return;
    if (ok) {
      widget.onSaved?.call();
      AppSnack.saved();
    } else {
      AppSnack.failed();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final email = AuthBridge.currentAuthEmail ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _name,
          labelText: t(loc, 'display_name_label'),
          textCapitalization: TextCapitalization.words,
          enabled: !_saving,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => unawaited(_save()),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(email, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.primary(
            label: loc.startsWith('ru') ? 'Сохранить имя' : 'Save name',
            loading: _saving,
            onPressed: _canSave ? () => unawaited(_save()) : null,
          ),
        ),
      ],
    );
  }
}
