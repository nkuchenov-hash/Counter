import 'dart:async';

import 'package:counter/data/records/unfilled_time_gap_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class UnfilledTimeNotificationsSection extends StatefulWidget {
  const UnfilledTimeNotificationsSection({super.key});

  @override
  State<UnfilledTimeNotificationsSection> createState() =>
      _UnfilledTimeNotificationsSectionState();
}

class _UnfilledTimeNotificationsSectionState
    extends State<UnfilledTimeNotificationsSection> {
  @override
  void initState() {
    super.initState();
    unawaited(UnfilledTimeGapService.instance.start());
  }

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    return ValueListenableBuilder<UnfilledTimeGapSettings>(
      valueListenable: UnfilledTimeGapService.instance.settings,
      builder: (context, settings, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(locale, 'unfilled_time_notifications_title'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              t(locale, 'unfilled_time_notifications_subtitle'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(t(locale, 'unfilled_time_notifications_enable')),
              value: settings.notificationsEnabled,
              onChanged: (enabled) => unawaited(
                UnfilledTimeGapService.instance.setNotificationsEnabled(
                  enabled,
                ),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: settings.minimumGapMinutes,
              decoration: InputDecoration(
                labelText: t(locale, 'unfilled_time_min_gap'),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final minutes in const <int>[5, 10, 15, 30])
                  DropdownMenuItem<int>(
                    value: minutes,
                    child: Text(
                      t(
                        locale,
                        'unfilled_time_minutes',
                      ).replaceAll('%s', '$minutes'),
                    ),
                  ),
              ],
              onChanged: (minutes) {
                if (minutes == null) return;
                unawaited(
                  UnfilledTimeGapService.instance.setMinimumGapMinutes(minutes),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: settings.notificationDelayMinutes,
              decoration: InputDecoration(
                labelText: t(locale, 'unfilled_time_delay'),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final minutes in const <int>[0, 15, 30, 60])
                  DropdownMenuItem<int>(
                    value: minutes,
                    child: Text(
                      minutes == 0
                          ? t(locale, 'unfilled_time_delay_immediately')
                          : t(
                              locale,
                              'unfilled_time_minutes',
                            ).replaceAll('%s', '$minutes'),
                    ),
                  ),
              ],
              onChanged: (minutes) {
                if (minutes == null) return;
                unawaited(
                  UnfilledTimeGapService.instance.setNotificationDelayMinutes(
                    minutes,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
