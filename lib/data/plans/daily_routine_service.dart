/// Legacy compatibility tombstone for the removed LIFE OS daily-routine seed.
///
/// Historical builds created six recurring plans automatically (morning
/// routine, breakfast, exercise, lunch, dinner and bed preparation). Automatic
/// creation is no longer permitted. This symbol intentionally remains as a
/// no-op so any stale internal caller cannot recreate those plans.
///
/// Any future routine/template feature must be a separate user-initiated flow
/// with explicit in-app confirmation before plan creation.
@Deprecated('Automatic daily-routine seeding is permanently disabled.')
Future<void> ensureDailyRoutineV6() async {}
