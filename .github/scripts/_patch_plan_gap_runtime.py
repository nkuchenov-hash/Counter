from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


source_path = Path("lib/data/plans/plan_time_cascade_helpers.dart")
source = source_path.read_text(encoding="utf-8")

source = replace_once(
    source,
    "const String _keyPlanAutoPlacementMode = 'plan_auto_placement_mode';\n",
    "const String _keyPlanAutoPlacementMode = 'plan_auto_placement_mode';\n"
    "const String _keyPlanAutoPlacementGapMigration =\n"
    "    'plan_auto_placement_gap_v2_migrated';\n",
    "migration key",
)

source = replace_once(
    source,
    """  Future<void> loadPlanAutoPlacementMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlanAutoPlacementMode);
    _planAutoPlacementMode = PlanAutoPlacementMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => PlanAutoPlacementMode.nearestFreeSlot,
    );
  }
""",
    """  Future<void> loadPlanAutoPlacementMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlanAutoPlacementMode);
    final gapMigrationDone =
        prefs.getBool(_keyPlanAutoPlacementGapMigration) ?? false;

    // The previous regression made afterLastPlan the default. A device that
    // persisted that value must be returned to smart gap placement once.
    if (!gapMigrationDone &&
        raw == PlanAutoPlacementMode.afterLastPlan.name) {
      _planAutoPlacementMode = PlanAutoPlacementMode.nearestFreeSlot;
      await prefs.setString(
        _keyPlanAutoPlacementMode,
        PlanAutoPlacementMode.nearestFreeSlot.name,
      );
    } else {
      _planAutoPlacementMode = PlanAutoPlacementMode.values.firstWhere(
        (mode) => mode.name == raw,
        orElse: () => PlanAutoPlacementMode.nearestFreeSlot,
      );
    }

    if (!gapMigrationDone) {
      await prefs.setBool(_keyPlanAutoPlacementGapMigration, true);
    }
  }
""",
    "load placement mode migration",
)

source = replace_once(
    source,
    """  bool _samePlanWallDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

""",
    "",
    "obsolete same-day helper",
)

source = replace_once(
    source,
    """        final profileNow =
            currentWall ?? applyUserOffset(DatabaseService.getPlanetaryNow());
        final earliestStart =
            _samePlanWallDay(profileNow, wallDay) &&
                profileNow.isAfter(windowStart)
            ? profileNow
            : windowStart;
        startWall = _firstAvailablePlanWallStart(
          earliestStartWall: earliestStart,
          durationMin: durationMin,
          existingDayPlans: existingDayPlans,
        );
""",
    """        startWall = _firstAvailablePlanWallStart(
          earliestStartWall: windowStart,
          durationMin: durationMin,
          existingDayPlans: existingDayPlans,
        );
""",
    "today earliest-gap search",
)

source_path.write_text(source, encoding="utf-8")

test_path = Path("test/auto_plan_nearest_free_slot_test.dart")
test = test_path.read_text(encoding="utf-8")

test = replace_once(
    test,
    """    expect(schedule.startWall, DateTime(2026, 7, 24, 10, 5));
    expect(schedule.endWall, DateTime(2026, 7, 24, 10, 35));
  });

  test('uses the current free gap when duration fits', () {
""",
    """    expect(schedule.startWall, DateTime(2026, 7, 24, 8));
    expect(schedule.endWall, DateTime(2026, 7, 24, 8, 30));
  });

  test('uses the earliest free gap even when current time is later', () {
""",
    "default expected gap and test name",
)

test = replace_once(
    test,
    """    expect(schedule.startWall, DateTime(2026, 7, 24, 10, 5));
    expect(schedule.endWall, DateTime(2026, 7, 24, 10, 35));
  });

  test('skips a gap that is too short', () {
""",
    """    expect(schedule.startWall, DateTime(2026, 7, 24, 8));
    expect(schedule.endWall, DateTime(2026, 7, 24, 8, 30));
  });

  test('skips a gap that is too short', () {
""",
    "current-time gap expected result",
)

test = replace_once(
    test,
    """      existingDayPlans: [
        _plan('a', DateTime(2026, 7, 24, 11), DateTime(2026, 7, 24, 12)),
      ],
      timelineDayStartHour: 8,
      currentWall: DateTime(2026, 7, 24, 10, 45),
""",
    """      existingDayPlans: [
        _plan(
          'early',
          DateTime(2026, 7, 24, 8),
          DateTime(2026, 7, 24, 10, 45),
        ),
        _plan('a', DateTime(2026, 7, 24, 11), DateTime(2026, 7, 24, 12)),
      ],
      timelineDayStartHour: 8,
      currentWall: DateTime(2026, 7, 24, 10, 45),
""",
    "too-short gap fixture",
)

anchor = "  test('after-last mode preserves the previous rule', () async {"
migration_test = """  test('migrates stale persisted after-last default exactly once', () async {
    SharedPreferences.setMockInitialValues({
      'plan_auto_placement_mode': 'afterLastPlan',
    });

    await DatabaseService.instance.loadPlanAutoPlacementMode();
    expect(
      DatabaseService.instance.planAutoPlacementMode,
      PlanAutoPlacementMode.nearestFreeSlot,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('plan_auto_placement_mode'),
      PlanAutoPlacementMode.nearestFreeSlot.name,
    );
    expect(prefs.getBool('plan_auto_placement_gap_v2_migrated'), isTrue);

    await DatabaseService.instance.setPlanAutoPlacementMode(
      PlanAutoPlacementMode.afterLastPlan,
    );
    await DatabaseService.instance.loadPlanAutoPlacementMode();
    expect(
      DatabaseService.instance.planAutoPlacementMode,
      PlanAutoPlacementMode.afterLastPlan,
    );
  });

"""
if anchor not in test:
    raise SystemExit("migration test anchor not found")
if migration_test not in test:
    test = test.replace(anchor, migration_test + anchor, 1)

test_path.write_text(test, encoding="utf-8")
