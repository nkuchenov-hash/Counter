import 'package:counter/shared/time/timezone_quick_preferences.dart';
import 'package:counter/shared/time/wall_clock.dart' as wall_clock;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tz_data.initializeTimeZones();
  });

  test('quick favorites and automatic mode are scoped per profile', () async {
    final initial = await TimezoneQuickPreferenceStore.load(
      'one', currentTimezone: 'Moscow');
    expect(initial.automatic, false);
    expect(initial.favorites, ['Moscow']);

    await TimezoneQuickPreferenceStore.setAutomatic('one', true);
    await TimezoneQuickPreferenceStore.setFavorites(
      'one', ['Moscow', 'New York']);
    final one = await TimezoneQuickPreferenceStore.load(
      'one', currentTimezone: 'Moscow');
    final two = await TimezoneQuickPreferenceStore.load(
      'two', currentTimezone: 'London');
    expect(one.automatic, true);
    expect(one.favorites, ['Moscow', 'New York']);
    expect(two.automatic, false);
    expect(two.favorites, ['London']);
  });

  test('legacy Moscow and New York identifiers become distinct favorites', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lifeos.timezone.quick.v1.legacy-aliases.favorites': <String>[
        'GMT+3', 'America/New_York',
      ],
    });
    final selected = await TimezoneQuickPreferenceStore.load(
      'legacy-aliases', currentTimezone: 'Moscow',
    );
    expect(selected.favorites, <String>['Moscow', 'New York']);
  });

  test('rapid multi-select writes preserve both Moscow and New York', () async {
    final first = TimezoneQuickPreferenceStore.setFavorites(
      'rapid-selection', <String>['Moscow'],
    );
    final second = TimezoneQuickPreferenceStore.setFavorites(
      'rapid-selection', <String>['Moscow', 'New York'],
    );
    await Future.wait(<Future<void>>[first, second]);
    final selected = await TimezoneQuickPreferenceStore.load(
      'rapid-selection', currentTimezone: 'Moscow',
    );
    expect(selected.favorites, <String>['Moscow', 'New York']);
  });

  test('09:00 New York projects to Moscow with DST, not 09:00 Moscow', () {
    final winterUtc = wall_clock.wallClockToUtcForIanaId(
      DateTime(2026, 11, 19, 9), 'America/New_York',
    );
    final summerUtc = wall_clock.wallClockToUtcForIanaId(
      DateTime(2027, 6, 19, 9), 'America/New_York',
    );
    expect(winterUtc, DateTime.utc(2026, 11, 19, 14));
    expect(summerUtc, DateTime.utc(2027, 6, 19, 13));
    final winterMoscow = wall_clock.toWallClockForLabel(
      winterUtc, 3, 'Moscow',
    );
    final summerMoscow = wall_clock.toWallClockForLabel(
      summerUtc, 3, 'Moscow',
    );
    expect(winterMoscow.hour, 17);
    expect(summerMoscow.hour, 16);
    expect(winterMoscow.day, 19);
    expect(summerMoscow.day, 19);
  });

  test('manual mode never overwrites the profile from the OS', () async {
    var writes = 0;
    final ok = await TimezoneQuickPreferenceStore.reconcileAutomatic(
      profileId: 'manual-preference',
      currentTimezone: 'Moscow',
      saveTimezone: (zone) async {
        writes++;
        return true;
      },
    );
    expect(ok, true);
    expect(writes, 0);
  });

  test('browser favorites use IndexedDB and survive old prefs reset', () async {
    if (!kIsWeb) return;
    const owner = 'timezone-idb-moscow-new-york-regression-v2';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lifeos.timezone.quick.v1.$owner.favorites': <String>['Moscow'],
      'lifeos.timezone.quick.v1.$owner.automatic': true,
    });
    // Browser migration preserves preexisting choices and auto setting.
    final old = await TimezoneQuickPreferenceStore.load(
      owner, currentTimezone: 'Moscow');
    expect(old.favorites, <String>['Moscow']);

    await TimezoneQuickPreferenceStore.setFavorites(
      owner, <String>['Moscow', 'New York'],
    );
    await TimezoneQuickPreferenceStore.setAutomatic(owner, false);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final reloaded = await TimezoneQuickPreferenceStore.load(
      owner, currentTimezone: 'Moscow');
    expect(reloaded.favorites, <String>['Moscow', 'New York']);
    expect(reloaded.automatic, false);
  });

  test('system IANA zone outside quick presets follows DST', () {
    final winter = wall_clock.toWallClockForLabel(
      DateTime.utc(2026, 1, 15, 12), 0, 'Europe/Berlin');
    final summer = wall_clock.toWallClockForLabel(
      DateTime.utc(2026, 7, 15, 12), 0, 'Europe/Berlin');
    expect(winter.hour, 13);
    expect(summer.hour, 14);
  });
}
