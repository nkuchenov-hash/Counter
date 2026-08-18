import 'package:counter/data/database_service.dart';
import 'package:counter/data/plans/daily_routine_service.dart';

/// Planning-owned startup baseline.
///
/// Startup prepares Planning data only. Paths migrations are server-side
/// PocketBase migrations and Path → Planner projection is explicit through
/// `PathPlannerBridge`; neither concern is allowed on app/shell startup.
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
  }
}
