import 'package:counter/data/pb_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android and Web production use the same restored PocketBase', () {
    expect(kPocketBaseProductionUrl, kPocketBaseRecoveredWebUrl);
    expect(kPocketBaseProductionUrl, 'https://137-22-146-109.sslip.io');
    final uri = Uri.parse(kPocketBaseProductionUrl);
    expect(uri.scheme, 'https');
    expect(uri.path, isEmpty);
    expect(uri.hasPort, isFalse);
  });
}
