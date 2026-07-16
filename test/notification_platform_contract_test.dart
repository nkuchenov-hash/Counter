import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android registers scheduled notification receivers and boot restore',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(manifest, contains('ScheduledNotificationReceiver'));
      expect(manifest, contains('ScheduledNotificationBootReceiver'));
      expect(manifest, contains('android.intent.action.MY_PACKAGE_REPLACED'));
    },
  );

  test('Android release keeps the configured notification icon', () {
    final keep = File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
    expect(keep, contains('@mipmap/ic_launcher'));
  });
}
