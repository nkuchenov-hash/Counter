part of '../database_service.dart';

extension CategoryDefaultTimeExtension on DatabaseService {
  static final RegExp _defaultPlanTimePattern = RegExp(
    r'^([01]\d|2[0-3]):([0-5]\d)$',
  );

  String? sanitizeDefaultPlanTime(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return null;
    final m = _defaultPlanTimePattern.firstMatch(s);
    if (m == null) return null;
    return '${m.group(1)}:${m.group(2)}';
  }

  /// `null` = use active profile timezone. Non-null = fixed IANA id.
  String? sanitizeDefaultPlanTimezone(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty || s.toLowerCase() == 'profile') return null;
    if (tz_cat.categoryDefaultTimezoneOptionForIana(s) != null) {
      return s;
    }
    try {
      tz.getLocation(s);
      return s;
    } catch (_) {
      return null;
    }
  }

  bool usesProfileDefaultPlanTimezone(String? stored) =>
      sanitizeDefaultPlanTimezone(stored) == null;

  String shortLabelForDefaultPlanTimezone(String? storedIana) {
    if (usesProfileDefaultPlanTimezone(storedIana)) {
      return profileTimezoneShortLabel();
    }
    return tz_cat.shortLabelForCategoryDefaultTimezoneIana(storedIana);
  }

  String formatDefaultPlanTimeWithTimezoneLabel(
    String hhmm,
    String? storedTimezoneIana,
  ) {
    final tzLabel = shortLabelForDefaultPlanTimezone(storedTimezoneIana);
    return tzLabel.isEmpty ? hhmm : '$hhmm · $tzLabel';
  }

  ({String? hhmm, String? timezoneIana, int? sourceCategoryId})?
  effectiveDefaultPlanScheduleForCategory(int categoryId) {
    final path = categoryPathFromRootToLocalId(categoryId);
    final ids = path.isEmpty ? <int>[categoryId] : path.reversed.toList();
    for (final id in ids) {
      final rule = getCategoryRuleById(id);
      final own = sanitizeDefaultPlanTime(rule?.defaultPlanTime);
      if (own != null) {
        return (
          hhmm: own,
          timezoneIana: sanitizeDefaultPlanTimezone(rule?.defaultPlanTimezone),
          sourceCategoryId: id,
        );
      }
    }
    return null;
  }

  String? effectiveDefaultPlanTimeForCategory(int categoryId) {
    return effectiveDefaultPlanScheduleForCategory(categoryId)?.hhmm;
  }

  String? effectiveDefaultPlanTimezoneForCategory(int categoryId) {
    return effectiveDefaultPlanScheduleForCategory(categoryId)?.timezoneIana;
  }

  DateTime wallUtcForCategoryDefaultWall({
    required DateTime wallDay,
    required int hour,
    required int minute,
    String? timezoneIana,
  }) {
    final wall = DateTime(wallDay.year, wallDay.month, wallDay.day, hour, minute);
    final iana = sanitizeDefaultPlanTimezone(timezoneIana);
    if (iana == null) {
      return _profileUtcFromWall(wall).toUtc();
    }
    return wall_clock.wallClockToUtcForIanaId(wall, iana);
  }

  DateTime? wallDateTimeForCategoryDefaultPlanTime(
    int categoryId,
    DateTime wallDay,
  ) {
    final schedule = effectiveDefaultPlanScheduleForCategory(categoryId);
    if (schedule?.hhmm == null) return null;
    final h = int.tryParse(schedule!.hhmm!.substring(0, 2));
    final m = int.tryParse(schedule.hhmm!.substring(3, 5));
    if (h == null || m == null) return null;
    return DateTime(wallDay.year, wallDay.month, wallDay.day, h, m);
  }

  static bool isDefaultPlanTimezoneFieldMissingError(String? detail) {
    final d = detail?.toLowerCase() ?? '';
    return d.contains('default_plan_timezone');
  }

  Future<({bool ok, String? errorDetail, bool timezoneFieldMissing})>
  updateCategoryDefaultPlanSchedule(
    int categoryId,
    String? hhmm,
    String? timezoneIana,
  ) async {
    final sanitized = sanitizeDefaultPlanTime(hhmm);
    if (sanitized == null) {
      final existing = getCategoryRuleById(categoryId);
      final clearFields = <String, dynamic>{'default_plan_time': null};
      if (sanitizeDefaultPlanTimezone(existing?.defaultPlanTimezone) != null) {
        clearFields['default_plan_timezone'] = null;
      }
      final clear = await patchCategoryDelta(categoryId, clearFields);
      return (
        ok: clear.ok,
        errorDetail: clear.errorDetail,
        timezoneFieldMissing: isDefaultPlanTimezoneFieldMissingError(
          clear.errorDetail,
        ),
      );
    }
    final tzStored = sanitizeDefaultPlanTimezone(timezoneIana);
    final fields = <String, dynamic>{'default_plan_time': sanitized};
    if (tzStored != null) {
      fields['default_plan_timezone'] = tzStored;
    } else {
      final existing = getCategoryRuleById(categoryId)?.defaultPlanTimezone;
      if (sanitizeDefaultPlanTimezone(existing) != null) {
        fields['default_plan_timezone'] = null;
      }
    }
    final result = await patchCategoryDelta(categoryId, fields);
    return (
      ok: result.ok,
      errorDetail: result.errorDetail,
      timezoneFieldMissing: isDefaultPlanTimezoneFieldMissingError(
        result.errorDetail,
      ),
    );
  }

  Future<({bool ok, String? errorDetail})> updateCategoryDefaultPlanTime(
    int categoryId,
    String? hhmm,
  ) {
    return updateCategoryDefaultPlanSchedule(
      categoryId,
      hhmm,
      null,
    ).then(
      (r) => (ok: r.ok, errorDetail: r.errorDetail),
    );
  }
}
