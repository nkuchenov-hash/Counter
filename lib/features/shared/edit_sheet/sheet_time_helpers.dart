import 'package:intl/intl.dart';import 'package:counter/l10n/dictionary.dart';import 'package:counter/data/database_service.dart';// --- Time helpers (Planetary: UTC + profile offset). Used by sheets. ---
/// Calendar date for UI (localized month/day per [currentLocale]).
String formatDate(DateTime date) =>
    DateFormat.yMMMd(currentLocale.value).format(date);
String formatTimeOfDay(DateTime dt) =>
    DateFormat.Hm(currentLocale.value).format(dt);
DateTime utcToDisplay(DateTime utc) =>
    DatabaseService.instance.applyUserOffset(utc);
DateTime displayToUtc(DateTime displayNaive) =>
    DatabaseService.instance.displayTimeToUtc(displayNaive);
DateTime displayNow() =>
    DatabaseService.instance.applyUserOffset(DatabaseService.getPlanetaryNow());
