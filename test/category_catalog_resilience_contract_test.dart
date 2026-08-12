import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category bootstrap cannot erase a known catalog on transient empty read', () {
    final source = File(
      'lib/data/categories/category_cache_helpers.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('A passive read is not deletion evidence.'),
      reason: 'PocketBase HTTP 200 + [] must not be treated as category deletion.',
    );
    expect(
      source,
      contains('if (cached != null && cached.isNotEmpty)'),
      reason: 'A non-empty category cache must win over a transient empty read.',
    );
    expect(
      source,
      contains('if (rows.isEmpty) return;'),
      reason: 'Passive category sync must never persist an empty catalog over good cache.',
    );
    expect(
      source,
      contains('_categoryCacheOwnerAliases()'),
      reason: 'Category cache recovery must search compatible legacy/auth owner aliases.',
    );
    expect(
      source,
      contains('_scheduleAppOpenSyncRetry();'),
      reason: 'Transient empty catalog reads must schedule recovery instead of clearing UI.',
    );
  });
}
