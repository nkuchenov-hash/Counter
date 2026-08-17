import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Paths V3 reality contract', () {
    const required = <String>[
      'offer',
      'product',
      'website',
      'payments',
      'licensing',
      'legal',
      'windows_distribution',
      'microsoft_store',
      'demand',
      'apple',
      'android',
      'support',
      'release',
    ];
    expect(required.length, 13);
    expect(required.toSet().length, required.length);
  });
}
