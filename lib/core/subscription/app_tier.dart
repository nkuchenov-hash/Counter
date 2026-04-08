import 'package:flutter/foundation.dart';

/// Global monetization tier (Free vs Pro). Replace with server-backed profile flag when ready.
///
/// Default **true** in development so Pro UI can be exercised without a paywall.
final ValueNotifier<bool> appIsProUser = ValueNotifier<bool>(true);
