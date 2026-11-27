import 'package:counter/data/database_service.dart';
import 'package:counter/features/shared/edit_sheet/category_edit_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// The category edit resolver must not access any Brain state. Explicit IDs
/// survive stale category caches and optimistic category creation.
class _NoBrainAccess implements DatabaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Unexpected Brain access: ${invocation.memberName}');
  }
}

void main() {
  test('explicit category resolution does not inspect the Brain', () {
    final db = _NoBrainAccess();
    expect(resolveEditFieldCategoryId(db: db, categoryId: 42), 42);
    expect(resolveEditFieldCategoryId(db: db, categoryId: -1), -1);
  });

  test('explicit category id survives stale and empty picker data', () {
    expect(
      resolveEditFieldCategoryIdValues(
        categoryId: 42,
        existsInTree: false,
        knownPairIds: const [1, 2],
      ),
      42,
    );
  });
}
