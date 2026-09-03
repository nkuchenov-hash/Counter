import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin bridge over the OS address book. It is invoked only from People →
/// Sources after an explicit user action; app startup never scans contacts.
class PeopleDeviceContactsBridge {
  PeopleDeviceContactsBridge._();

  static final PeopleDeviceContactsBridge instance =
      PeopleDeviceContactsBridge._();

  static const MethodChannel _channel = MethodChannel('counter/people_contacts');

  bool get supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<List<Map<String, dynamic>>> readContacts() async {
    if (!supported) return const <Map<String, dynamic>>[];

    var status = await Permission.contacts.status;
    if (!status.isGranted) status = await Permission.contacts.request();
    if (!status.isGranted) {
      throw StateError('contacts_permission_denied');
    }

    final raw = await _channel.invokeMethod<List<dynamic>>('readContacts');
    if (raw == null) return const <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
}
