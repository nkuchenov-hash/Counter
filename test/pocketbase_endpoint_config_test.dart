import 'package:counter/data/pb_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release backend follows the selected build-time origin', () {
    const expected = String.fromEnvironment(
      'POCKETBASE_URL',
      defaultValue: 'https://217-114-0-201.sslip.io',
    );
    expect(kPocketBaseProductionUrl, expected);

    final uri = Uri.parse(kPocketBaseProductionUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, isNotEmpty);
    expect(uri.path, isEmpty);
    expect(uri.query, isEmpty);
    expect(uri.fragment, isEmpty);
  });

  test('non-Android local test uses the configured production origin', () {
    // This test runs in the Flutter VM, not in the Android emulator.
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      expect(resolvePocketBaseUrl(), kPocketBaseProductionUrl);
    }
  });
}
