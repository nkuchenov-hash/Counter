import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal category matching runs before calendar fallback', () {
    final hook = File(
      'pb_hooks/calendar_integrations.pb.js',
    ).readAsStringSync();
    final resolverStart = hook.indexOf(
      'function __calendarResolveAutoCategory',
    );
    final resolverEnd = hook.indexOf(
      'function __calendarWallDay',
      resolverStart,
    );
    final resolver = hook.substring(resolverStart, resolverEnd);

    expect(resolver, contains('__calendarCategoryScore'));
    expect(resolver.indexOf('if (best) return best.id;'), greaterThan(0));
    expect(
      resolver.indexOf('if (best) return best.id;'),
      lessThan(resolver.indexOf('fallbackId = String')),
    );
    expect(hook, contains('"ts": "technical"'));
  });

  test('provider resync has stable external identity and dedupe index', () {
    final hook = File(
      'pb_hooks/calendar_integrations.pb.js',
    ).readAsStringSync();
    final migration = File(
      'pb_migrations/1785960000_calendar_integrations.js',
    ).readAsStringSync();

    expect(hook, contains('function __calendarFindExistingPlan'));
    expect(hook, contains('external_occurrence_key'));
    expect(hook, contains('function __calendarCleanupStale'));
    expect(migration, contains('idx_plans_external_unique'));
    expect(
      migration,
      contains(
        'user_id, external_provider, external_account_id, external_calendar_id, external_event_id, external_occurrence_key',
      ),
    );
  });

  test('settings are in-app and sync refreshes the normal planning stream', () {
    final account = File(
      'lib/features/profile/settings/account_settings_section.dart',
    ).readAsStringSync();
    final service = File(
      'lib/data/calendar_integrations/calendar_integration_service.dart',
    ).readAsStringSync();
    final ui = File(
      'lib/features/profile/calendar_integrations/calendar_integrations_section.dart',
    ).readAsStringSync();

    expect(account, contains('CalendarIntegrationsSection'));
    expect(ui, contains('calendar_integrations_fallback_category'));
    expect(ui, contains('allCategoryIdPathPairs'));
    expect(service, contains('calendarIntegrationConnect'));
    expect(service, contains('notifyPlanningRefresh'));
    expect(service, isNot(contains('Price Reporter')));
    expect(service, isNot(contains('LAREDO')));
  });
}
