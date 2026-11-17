import 'package:counter/shared/time/timezone_quick_preferences.dart';
import 'package:counter/shared/time/wall_clock.dart' as wall_clock;
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

  test('system IANA zone outside quick presets follows DST', () {
    final winter = wall_clock.toWallClockForLabel(
      DateTime.utc(2026, 1, 15, 12), 0, 'Europe/Berlin');
    final summer = wall_clock.toWallClockForLabel(
      DateTime.utc(2026, 7, 15, 12), 0, 'Europe/Berlin');
    expect(winter.hour, 13);
    expect(summer.hour, 14);
  });
}
