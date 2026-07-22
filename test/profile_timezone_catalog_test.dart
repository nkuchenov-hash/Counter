import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'package:counter/features/settings/timezone_settings.dart' as tz_settings;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  group('profile_timezone_catalog', () {
    test('picker labels use current July DST labels', () {
      final july = DateTime.utc(2026, 7, 2, 12);

      expect(
        formatProfileTimezonePickerLabel(
          kProfileTimezoneCatalog[0],
          atUtc: july,
        ),
        'UTC · Fixed · UTC+0',
      );
      expect(
        formatProfileTimezonePickerLabel(
          kProfileTimezoneCatalog[1],
          atUtc: july,
        ),
        'London · LON · BST · UTC+1',
      );
      expect(
        formatProfileTimezonePickerLabel(
          kProfileTimezoneCatalog[2],
          atUtc: july,
        ),
        'Moscow · MSK · UTC+3',
      );
      expect(
        formatProfileTimezonePickerLabel(
          kProfileTimezoneCatalog[3],
          atUtc: july,
        ),
        'Dubai · DXB · UTC+4',
      );
      expect(
        formatProfileTimezonePickerLabel(
          kProfileTimezoneCatalog[4],
          atUtc: july,
        ),
        'New York · NY · EDT · UTC\u22124',
      );
    });

    test('London and New York winter labels use standard time', () {
      final winter = DateTime.utc(2026, 1, 15, 12);

      expect(
        formatProfileTimezonePickerLabel(
          kProfileTimezoneCatalog[1],
          atUtc: winter,
        ),
        'London · LON · GMT · UTC+0',
      );
      expect(
        formatProfileTimezonePickerLabel(
          kProfileTimezoneCatalog[4],
          atUtc: winter,
        ),
        'New York · NY · EST · UTC\u22125',
      );
    });

    test('Moscow and Dubai remain fixed across seasons', () {
      final july = DateTime.utc(2026, 7, 2, 12);
      final winter = DateTime.utc(2026, 1, 15, 12);

      expect(
        formatProfileTimezoneSecondaryLine(
          kProfileTimezoneCatalog[2],
          atUtc: july,
        ),
        'UTC+3',
      );
      expect(
        formatProfileTimezoneSecondaryLine(
          kProfileTimezoneCatalog[2],
          atUtc: winter,
        ),
        'UTC+3',
      );
      expect(
        formatProfileTimezoneSecondaryLine(
          kProfileTimezoneCatalog[3],
          atUtc: july,
        ),
        'UTC+4',
      );
      expect(
        formatProfileTimezoneSecondaryLine(
          kProfileTimezoneCatalog[3],
          atUtc: winter,
        ),
        'UTC+4',
      );
    });

    test('catalog aligns with profile timezone values and icons', () {
      expect(tz_settings.kProfileTimezoneCatalog.map((e) => e.profileValue), [
        'UTC',
        'London',
        'Moscow',
        'Dubai',
        'New York',
      ]);
      expect(kProfileTimezoneCatalog[0].ianaId, 'Etc/UTC');
      expect(kProfileTimezoneCatalog[1].ianaId, 'Europe/London');
      expect(kProfileTimezoneCatalog[4].ianaId, 'America/New_York');
    });

    test('legacy GMT+3 resolves to Moscow catalog entry', () {
      final entry = catalogEntryForStoredTimezone('GMT+3');
      expect(entry?.profileValue, 'Moscow');
      expect(entry?.shortLabel, 'MSK');
    });

    test('profileTimezoneValuesMatch keeps UTC separate from London', () {
      expect(profileTimezoneValuesMatch('Moscow', 'GMT+3'), isTrue);
      expect(profileTimezoneValuesMatch('UTC', 'London'), isFalse);
      expect(
        catalogEntryForStoredTimezone('London (UTC+0)')?.profileValue,
        'London',
      );
      expect(catalogEntryForStoredTimezone('UTC+0')?.profileValue, 'UTC');
    });

    test('filterProfileTimezoneCatalog searches city, code, and IANA id', () {
      final ny = filterProfileTimezoneCatalog('ny');
      expect(ny.map((e) => e.profileValue), contains('New York'));

      final msk = filterProfileTimezoneCatalog('msk');
      expect(msk.single.profileValue, 'Moscow');

      final london = filterProfileTimezoneCatalog('Europe/London');
      expect(london.single.profileValue, 'London');
    });

    test('offset helpers use current IANA offsets', () {
      final july = DateTime.utc(2026, 7, 2, 12);
      final winter = DateTime.utc(2026, 1, 15, 12);

      expect(currentOffsetHoursForProfileTimezone('UTC', atUtc: july), 0);
      expect(currentOffsetHoursForProfileTimezone('London', atUtc: july), 1);
      expect(currentOffsetHoursForProfileTimezone('London', atUtc: winter), 0);
      expect(currentOffsetHoursForProfileTimezone('New York', atUtc: july), -4);
      expect(
        currentOffsetHoursForProfileTimezone('New York', atUtc: winter),
        -5,
      );
      expect(currentOffsetHoursForProfileTimezone('Moscow', atUtc: july), 3);
      expect(currentOffsetHoursForProfileTimezone('Dubai', atUtc: july), 4);
    });

    test('legacy offsetForLabel delegates to catalog offsets', () {
      expect(tz_settings.offsetForLabel('Moscow'), 3);
      expect(tz_settings.offsetForLabel('GMT+3'), 3);
    });
  });
}
