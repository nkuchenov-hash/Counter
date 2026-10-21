import 'package:counter/data/ai/viktor_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Viktor account-cloud preferences vs browser quota', () {
    test('cloud-connected web must never write SharedPreferences', () {
      expect(shouldPersistViktorLocalPreferences(
          isWeb: true, hasCloudConnection: true), isFalse);
    });
    test('native app can retain optional device preferences', () {
      expect(shouldPersistViktorLocalPreferences(
          isWeb: false, hasCloudConnection: true), isTrue);
    });
    test('legacy offline web preferences remain a best-effort fallback', () {
      expect(shouldPersistViktorLocalPreferences(
          isWeb: true, hasCloudConnection: false), isTrue);
    });
  });
}
