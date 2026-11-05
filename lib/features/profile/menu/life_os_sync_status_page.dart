import 'dart:async';

import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Live PocketBase outbox health — real state, no simulated connection indicator.
class LifeOsSyncStatusPage extends StatelessWidget {
  const LifeOsSyncStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ru = currentLocale.value.toLowerCase().startsWith('ru');
    final sync = DatabaseService.instance.offlineSync;
    return Theme(
      data: settingsNeutralTheme(context),
      child: Builder(builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          title: Text(ru ? 'Синхронизация' : 'Synchronization'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        body: ListenableBuilder(
          listenable: sync,
          builder: (context, _) {
            final status = sync.authPaused
                ? (ru ? 'Нужна авторизация' : 'Sign-in required')
                : sync.isOffline
                ? (ru ? 'Нет соединения' : 'Offline')
                : sync.isSyncing
                ? (ru ? 'Синхронизация…' : 'Syncing…')
                : sync.hasBlockingSyncError
                ? (ru ? 'Ошибка синхронизации' : 'Sync error')
                : (ru ? 'Подключено' : 'Connected');
            return AppSettingsPageBody(
              children: [
                AppSettingsNavigationGroup(
                  children: [
                    AppSettingsInfoRow(
                      label: ru ? 'Состояние' : 'Status',
                      value: status,
                    ),
                    AppSettingsInfoRow(
                      label: ru ? 'Ожидают отправки' : 'Pending changes',
                      value: sync.pendingCount.toString(),
                    ),
                  ],
                ),
                AppSettingsSectionCard(
                  title: ru ? 'Локальные изменения' : 'Local changes',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(ru
                          ? 'Изменения хранятся локально до подтверждённой отправки на сервер.'
                          : 'Changes remain local until the server confirms delivery.'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: Icon(AppMenuIcons.icon(AppMenuIconRole.sync)),
                        onPressed: sync.isSyncing ? null : () => unawaited(
                          DatabaseService.instance.flushPendingLocalMutations()),
                        label: Text(ru ? 'Повторить синхронизацию' : 'Retry synchronization'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      )),
    );
  }
}
