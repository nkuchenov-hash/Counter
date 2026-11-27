import 'package:counter/data/pb_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only explicit auth rejection clears a cached session', () {
    expect(isPocketBaseSessionRejected(401), isTrue);
    for (final status in [0, 200, 400, 403, 404, 408, 425, 429, 500, 502, 503, 504]) {
      expect(isPocketBaseSessionRejected(status), isFalse, reason: 'HTTP $status');
    }
  });
}
