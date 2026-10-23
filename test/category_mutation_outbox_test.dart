import 'package:counter/data/local_sync/category_mutation_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('rapid category edits coalesce and old ACK cannot erase latest', () async {
    final prefs = await SharedPreferences.getInstance();
    const owner = 'profile12345678';
    const categoryId = 'category1234567';

    await CategoryMutationOutbox.enqueue(prefs,
        owner: owner,
        pocketBaseId: categoryId,
        fields: <String, dynamic>{'color_value': 0xFF969696, 'order': 3});
    final first = await CategoryMutationOutbox.load(prefs, owner);
    expect(first, hasLength(1));
    final oldRevision = first.single['revision'] as int;

    await CategoryMutationOutbox.enqueue(prefs,
        owner: owner,
        pocketBaseId: categoryId,
        fields: <String, dynamic>{'color_value': 0xFF606060});
    final latest = await CategoryMutationOutbox.load(prefs, owner);
    expect(latest, hasLength(1));
    expect((latest.single['fields'] as Map)['color_value'], 0xFF606060);
    expect((latest.single['fields'] as Map)['order'], 3);

    expect(await CategoryMutationOutbox.acknowledge(prefs,
      owner: owner, pocketBaseId: categoryId, revision: oldRevision), false);
    expect(await CategoryMutationOutbox.load(prefs, owner), hasLength(1));

    expect(await CategoryMutationOutbox.acknowledge(prefs,
      owner: owner, pocketBaseId: categoryId,
      revision: latest.single['revision'] as int), true);
    expect(await CategoryMutationOutbox.load(prefs, owner), isEmpty);
  });

  test('category mutations are isolated by owner and survive reload', () async {
    final prefs = await SharedPreferences.getInstance();
    await CategoryMutationOutbox.enqueue(prefs,
        owner: 'owner-a',
        pocketBaseId: 'category1234567',
        fields: <String, dynamic>{'icon_code_point': 58333});
    expect(await CategoryMutationOutbox.load(prefs, 'owner-b'), isEmpty);
    final restored = await CategoryMutationOutbox.load(prefs, 'owner-a');
    expect(restored.single['pocketBaseId'], 'category1234567');
    expect((restored.single['fields'] as Map)['icon_code_point'], 58333);
  });
}
