typedef WallNowFn = DateTime Function();

class AppClock {
  static WallNowFn? wallNow;
  static Stream<void>? timeTicks;
  static String Function()? timezoneShortLabel;
}
