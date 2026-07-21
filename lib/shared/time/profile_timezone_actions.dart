import 'package:counter/data/models.dart';

typedef ProfileTimezoneShortLabelFn = String Function();
typedef SaveProfileTimezoneFn = Future<bool> Function(String timezone);
typedef CurrentUserSettingsFn = UserSettings Function();

/// Profile timezone read/write hooks — wired from `main.dart` after Brain init.
class ProfileTimezoneActions {
  static ProfileTimezoneShortLabelFn? shortLabel;
  static Stream<UserSettings>? settingsStream;
  static CurrentUserSettingsFn? currentSettings;
  static SaveProfileTimezoneFn? saveTimezone;
}
