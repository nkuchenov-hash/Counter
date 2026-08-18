import 'package:counter/data/database_service.dart';
import 'package:counter/data/paths/compatibility/path_governance_service.dart';
import 'package:counter/data/plans/daily_routine_service.dart';

/// Planning-owned startup baseline.
///
/// The shell asks Planning to prepare its runtime baseline; it does not know
/// about compatibility-era Paths migrations. The cleanup remains isolated
/// behind [runLegacyPathPlannerCleanupV7] until old generated Path rows are
/// fully retired.
final class PlannerStartupService {
  PlannerStartupService._();

  static final PlannerStartupService instance = PlannerStartupService._();

  Future<void>? _inFlight;

  Future<void> ensureBaseline() {
    final active = _inFlight;
    if (active != null) return active;
    final run = _ensureBaseline();
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  Future<void> _ensureBaseline() async {
    final db = DatabaseService.instance;
    await db.refreshCategoryRulesFromServer();
    await ensureDailyRoutineV6();
    await runLegacyPathPlannerCleanupV7();
  }
}
