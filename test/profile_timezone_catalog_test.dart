import 'package:counter/core/time/profile_timezone_catalog.dart';
import 'package:counter/features/profile/timezone_settings.dart' as tz_settings;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('profile_timezone_catalog', () {
    test('picker labels match UX contract examples', () {
      expect(
        formatProfileTimezonePickerLabel(kProfileTimezoneCatalog[2]),
        'Moscow · MSK · UTC+3',
      );
      expect(
        formatProfileTimezonePickerLabel(kProfileTimezoneCatalog[4]),
        'New York · NY · UTC-5',
      );
      expect(
        formatProfileTimezonePickerLabel(kProfileTimezoneCatalog.first),
        'UTC · UTC+0',
      );
    });

    test('catalog aligns with profile timezone values', () {
      expect(
        tz_settings.kProfileTimezoneCatalog.map((e) => e.profileValue),
        ['UTC', 'London', 'Moscow', 'Dubai', 'New York'],
      );
    });

    test('legacy GMT+3 resolves to Moscow catalog entry', () {
      final entry = catalogEntryForStoredTimezone('GMT+3');
      expect(entry?.profileValue, 'Moscow');
      expect(entry?.shortLabel, 'MSK');
    });

    test('profileTimezoneValuesMatch treats Moscow and GMT+3 as same', () {
      expect(profileTimezoneValuesMatch('Moscow', 'GMT+3'), isTrue);
      expect(profileTimezoneValuesMatch('UTC', 'London'), isFalse);
    });

    test('filterProfileTimezoneCatalog searches city and short label', () {
      final ny = filterProfileTimezoneCatalog('ny');
      expect(ny.map((e) => e.profileValue), contains('New York'));

      final msk = filterProfileTimezoneCatalog('msk');
      expect(msk.single.profileValue, 'Moscow');
    });

    test('offsetForLabel uses catalog offsets', () {
      expect(tz_settings.offsetForLabel('Moscow'), 3);
      expect(tz_settings.offsetForLabel('New York'), -5);
      expect(tz_settings.offsetForLabel('GMT+3'), 3);
    });
  });
}
