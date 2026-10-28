/// Feature safety gate: the collaboration backend and two-account tests must
/// pass before exposing shares in production. No network or UI work while off.
/// Enable on staging builds via --dart-define=LIFEOS_SHARED_PLANS=true.
const bool kSharedPlansEnabled = bool.fromEnvironment(
  'LIFEOS_SHARED_PLANS',
  defaultValue: false,
);
