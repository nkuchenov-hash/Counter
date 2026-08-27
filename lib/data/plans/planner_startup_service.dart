import 'package:counter/data/database_service.dart';

/// Planning-owned startup baseline.
///
/// Startup may refresh Planning data, but it must never create plans, routines,
/// habits, templates, or other user commitments. Plan creation requires an
/// explicit user action in the application.
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
  }
}
