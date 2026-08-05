import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/confirm_dialog.dart';
import 'package:counter/data/calendar_integrations/calendar_integration_service.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class CalendarIntegrationsSection extends StatefulWidget {
  const CalendarIntegrationsSection({super.key});

  @override
  State<CalendarIntegrationsSection> createState() =>
      _CalendarIntegrationsSectionState();
}

class _CalendarIntegrationsSectionState
    extends State<CalendarIntegrationsSection> {
  CalendarIntegrationService get _service => CalendarIntegrationService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_service.loadStatus());
  }

  List<({String id, String path})> _categoryOptions() {
    final out = <({String id, String path})>[];
    for (final pair in DatabaseService.instance.allCategoryIdPathPairs) {
      final rule = DatabaseService.instance.getCategoryRuleById(pair.id);
      final backendId = rule?.backendRowId?.trim() ?? '';
      if (backendId.isEmpty || backendId.length < 15 || rule!.isArchived) {
        continue;
      }
      out.add((id: backendId, path: pair.path));
    }
    return out;
  }

  String _providerStatus(
    String locale,
    CalendarProviderConnection connection,
  ) {
    if (!connection.serverConfigured) {
      return t(locale, 'calendar_integrations_server_setup_required');
    }
    if (!connection.configured) {
      return t(locale, 'calendar_integrations_not_connected');
    }
    return switch (connection.status) {
      'connecting' => t(locale, 'calendar_integrations_connecting'),
      'syncing' => t(locale, 'calendar_integrations_syncing'),
      'error' => t(locale, 'calendar_integrations_error'),
      _ => t(locale, 'calendar_integrations_connected'),
    };
  }

  Future<void> _connect(CalendarIntegrationProvider provider) async {
    await _service.connect(provider);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _sync(CalendarIntegrationProvider provider) async {
    await _service.syncNow(provider);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _disconnect(
    CalendarIntegrationProvider provider,
    String locale,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: t(locale, 'calendar_integrations_disconnect_title'),
      body: t(locale, 'calendar_integrations_disconnect_body'),
      confirmText: t(locale, 'calendar_integrations_disconnect'),
      destructive: true,
    );
    if (confirmed != true) return;
    await _service.disconnect(provider);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveCalendar(
    CalendarProviderConnection connection,
    CalendarSourceConfig changed,
  ) async {
    final next = <CalendarSourceConfig>[
      for (final calendar in connection.calendars)
        if (calendar.id == changed.id) changed else calendar,
    ];
    await _service.saveCalendars(connection.provider, next);
    if (!mounted) return;
    setState(() {});
  }

  String _formatLastSync(String locale, DateTime? value) {
    if (value == null) return t(locale, 'calendar_integrations_never_synced');
    final local = value.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '${t(locale, 'calendar_integrations_last_sync')}: $date';
  }

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    return ValueListenableBuilder<CalendarIntegrationState>(
      valueListenable: _service.state,
      builder: (context, state, _) {
        if (state.loading && state.connections.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: AppLoading(size: AppLoadingSize.small)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            Text(
              t(locale, 'calendar_integrations_title'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              t(locale, 'calendar_integrations_subtitle'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            for (final provider in CalendarIntegrationProvider.values) ...[
              _ProviderCard(
                provider: provider,
                connection: state.connectionFor(provider),
                busy: state.actionProvider == provider,
                statusLabel: state.connectionFor(provider) == null
                    ? t(locale, 'calendar_integrations_not_connected')
                    : _providerStatus(locale, state.connectionFor(provider)!),
                categories: _categoryOptions(),
                formatLastSync: (value) => _formatLastSync(locale, value),
                onConnect: () => unawaited(_connect(provider)),
                onRefresh: () => unawaited(_service.loadStatus()),
                onSync: () => unawaited(_sync(provider)),
                onDisconnect: () => unawaited(_disconnect(provider, locale)),
                onCalendarChanged: (connection, calendar) =>
                    unawaited(_saveCalendar(connection, calendar)),
              ),
              const SizedBox(height: 12),
            ],
            if (state.error != null && state.error!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  state.error == 'server_calendar_integrations_not_deployed'
                      ? t(locale, 'calendar_integrations_server_not_deployed')
                      : state.error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.connection,
    required this.busy,
    required this.statusLabel,
    required this.categories,
    required this.formatLastSync,
    required this.onConnect,
    required this.onRefresh,
    required this.onSync,
    required this.onDisconnect,
    required this.onCalendarChanged,
  });

  final CalendarIntegrationProvider provider;
  final CalendarProviderConnection? connection;
  final bool busy;
  final String statusLabel;
  final List<({String id, String path})> categories;
  final String Function(DateTime? value) formatLastSync;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;
  final void Function(
    CalendarProviderConnection connection,
    CalendarSourceConfig calendar,
  ) onCalendarChanged;

  IconData get _icon => switch (provider) {
        CalendarIntegrationProvider.microsoft => Icons.video_call_rounded,
        CalendarIntegrationProvider.google => Icons.calendar_month_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final connected = connection?.configured == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      connection?.accountLabel ?? statusLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (!connected)
                AppButton.secondary(
                  label: t(locale, 'calendar_integrations_connect'),
                  icon: Icons.link_rounded,
                  size: AppButtonSize.s,
                  loading: busy,
                  onPressed: connection?.serverConfigured == false
                      ? null
                      : onConnect,
                )
              else
                AppButton.ghost(
                  label: t(locale, 'calendar_integrations_refresh'),
                  icon: Icons.refresh_rounded,
                  size: AppButtonSize.s,
                  loading: busy,
                  onPressed: onRefresh,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: connection?.status == 'error'
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
          ),
          if (connected) ...[
            const SizedBox(height: 4),
            Text(
              formatLastSync(connection?.lastSyncAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              t(locale, 'calendar_integrations_category_rule_note'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            if (connection!.calendars.isEmpty)
              Text(t(locale, 'calendar_integrations_no_calendars'))
            else
              for (final calendar in connection!.calendars)
                _CalendarSourceTile(
                  calendar: calendar,
                  categories: categories,
                  busy: busy,
                  onChanged: (changed) =>
                      onCalendarChanged(connection!, changed),
                ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton.secondary(
                  label: t(locale, 'calendar_integrations_sync_now'),
                  icon: Icons.sync_rounded,
                  size: AppButtonSize.s,
                  loading: busy,
                  onPressed: onSync,
                ),
                AppButton.ghost(
                  label: t(locale, 'calendar_integrations_disconnect'),
                  icon: Icons.link_off_rounded,
                  size: AppButtonSize.s,
                  onPressed: busy ? null : onDisconnect,
                ),
              ],
            ),
            if (connection!.lastError != null) ...[
              const SizedBox(height: 10),
              Text(
                connection!.lastError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CalendarSourceTile extends StatelessWidget {
  const _CalendarSourceTile({
    required this.calendar,
    required this.categories,
    required this.busy,
    required this.onChanged,
  });

  final CalendarSourceConfig calendar;
  final List<({String id, String path})> categories;
  final bool busy;
  final ValueChanged<CalendarSourceConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    final selectedFallback = categories.any(
      (entry) => entry.id == calendar.fallbackCategoryId,
    )
        ? calendar.fallbackCategoryId
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(calendar.name.isEmpty ? calendar.id : calendar.name),
            subtitle: calendar.primary
                ? Text(t(locale, 'calendar_integrations_primary_calendar'))
                : null,
            value: calendar.enabled,
            onChanged: busy
                ? null
                : (value) => onChanged(calendar.copyWith(enabled: value)),
          ),
          if (calendar.enabled)
            DropdownButtonFormField<String?>(
              value: selectedFallback,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t(
                  locale,
                  'calendar_integrations_fallback_category',
                ),
                helperText: t(
                  locale,
                  'calendar_integrations_fallback_category_hint',
                ),
              ),
              items: <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    t(locale, 'calendar_integrations_no_fallback'),
                  ),
                ),
                for (final entry in categories)
                  DropdownMenuItem<String?>(
                    value: entry.id,
                    child: Text(
                      entry.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (value) => onChanged(
                        calendar.copyWith(
                          fallbackCategoryId: value,
                          clearFallbackCategory: value == null,
                        ),
                      ),
            ),
        ],
      ),
    );
  }
}
