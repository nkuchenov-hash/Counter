import 'package:counter/services/morning_start_preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('morning prompt is enabled by default for existing users', () async {
    expect(await MorningStartPreference.isEnabled('profile-1'), isTrue);
  });

  test('disabled morning prompt survives subsequent reads', () async {
    await MorningStartPreference.setEnabled('profile-1', false);
    expect(await MorningStartPreference.isEnabled('profile-1'), isFalse);

    await MorningStartPreference.setEnabled('profile-1', true);
    expect(await MorningStartPreference.isEnabled('profile-1'), isTrue);
  });

  test('preference stays isolated between profiles', () async {
    await MorningStartPreference.setEnabled('profile-1', false);
    expect(await MorningStartPreference.isEnabled('profile-2'), isTrue);
    expect(await MorningStartPreference.isEnabled('profile-1'), isFalse);
  });
}
