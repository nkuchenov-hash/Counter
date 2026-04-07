import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Host detection via Android [MainActivity] MethodChannel (`FEATURE_WATCH`).
class WearPlatform {
  static const _channel = MethodChannel('counter/wear');

  static Future<bool> isWearHost() async {
    if (kIsWeb) return false;
    try {
      final v = await _channel.invokeMethod<bool>('isWear');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// [Configuration.isScreenRound] from the Activity (Wear round devices).
  static Future<bool> isRoundDisplay() async {
    if (kIsWeb) return false;
    try {
      final v = await _channel.invokeMethod<bool>('isRound');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }
}
