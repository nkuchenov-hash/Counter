import 'dart:async';import 'package:counter/features/auth/oauth_session.dart';import 'package:counter/data/auth_bridge.dart';import 'package:counter/data/database_service.dart';import 'package:counter/data/models.dart';import 'package:counter/l10n/dictionary.dart';import 'package:flutter/material.dart';/// Account: current user + Logout in one row (PocketBase-hydrated identity).
class AccountSecuritySection extends StatelessWidget {
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
        return Padding(
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
                icon: Icon(Icons.logout_rounded, color: scheme.error, size: 20),
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
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(context);
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
