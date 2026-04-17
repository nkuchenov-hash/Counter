// ---------------------------------------------------------------------------
// Barrel: re-exports [AuthView]. Prefer `import '.../auth_view.dart'` in new code.
// ---------------------------------------------------------------------------

import 'package:counter/features/auth/auth_view.dart';

export 'auth_view.dart';

/// Back-compat: shell may still reference [AuthScreen] (same widget as [AuthView]).
typedef AuthScreen = AuthView;
