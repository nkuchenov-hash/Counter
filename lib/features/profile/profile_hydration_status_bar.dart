import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class ProfileHydrationStatusBar extends StatelessWidget {
  const ProfileHydrationStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = DatabaseService.instance;
    if (brain.profileHydratedFromPb) return const SizedBox.shrink();
    final err = brain.profileHydrationError?.trim();
    if (err == null || err.isEmpty) return const SizedBox.shrink();
    final locale = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer.withValues(alpha: 0.9),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () {
            unawaited(() async {
              final id = brain.currentProfileId;
              if (id == null || id.isEmpty) return;
              final ok = await brain.retryProfileHydration();
              if (!ok) return;
              unawaited(brain.loadInitialData(id));
            }());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.person_off_outlined, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(locale, 'profile_hydration_error_title'),
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  t(locale, 'profile_hydration_retry'),
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
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
