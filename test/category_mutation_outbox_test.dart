import 'package:counter/core/category_color_palette.dart';
import 'package:counter/data/local_sync/category_mutation_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('edits are durable across load and isolated by owner', () async {
    final prefs = await SharedPreferences.getInstance();
    await CategoryMutationOutbox.enqueue(
      prefs, 'account-a', categoryId: 12, pocketBaseId: 'pb-category12',
      fields: {'color_value': kNordicWork[500]!.toARGB32()},
    );
    final reloaded = await CategoryMutationOutbox.load(prefs, 'account-a');
    expect(reloaded, hasLength(1));
    expect((reloaded.first['fields'] as Map)['color_value'],
        kNordicWork[500]!.toARGB32());
    expect(await CategoryMutationOutbox.load(prefs, 'account-b'), isEmpty);
  });

  test('newer offline color wins over older server acknowledgement', () async {
    final prefs = await SharedPreferences.getInstance();
    await CategoryMutationOutbox.enqueue(
      prefs, 'account-a', categoryId: 12, pocketBaseId: 'pb-category12',
      fields: {'color_value': kNordicWork[600]!.toARGB32()},
    );
    final oldRevision = (await CategoryMutationOutbox.load(
        prefs, 'account-a')).single['revision'] as int;
    await CategoryMutationOutbox.enqueue(
      prefs, 'account-a', categoryId: 12, pocketBaseId: 'pb-category12',
      fields: {'color_value': kNordicPeople[400]!.toARGB32()},
    );
    expect(await CategoryMutationOutbox.acknowledge(
      prefs, 'account-a', categoryId: 12, revision: oldRevision,
    ), isFalse);
    final pending = await CategoryMutationOutbox.load(prefs, 'account-a');
    expect(pending, hasLength(1));
    expect((pending.single['fields'] as Map)['color_value'],
        kNordicPeople[400]!.toARGB32());
    expect(await CategoryMutationOutbox.acknowledge(
      prefs, 'account-a', categoryId: 12,
      revision: pending.single['revision'] as int,
    ), isTrue);
    expect(await CategoryMutationOutbox.load(prefs, 'account-a'), isEmpty);
  });

  test('multiple edits coalesce without losing unrelated fields or categories',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await CategoryMutationOutbox.enqueue(
      prefs, 'account-a', categoryId: 12, pocketBaseId: 'pb-category12',
      fields: {'name': 'Price Reporter'},
    );
    await CategoryMutationOutbox.enqueue(
      prefs, 'account-a', categoryId: 12, pocketBaseId: 'pb-category12',
      fields: {'color_value': kNordicWork[400]!.toARGB32()},
    );
    await CategoryMutationOutbox.enqueue(
      prefs, 'account-a', categoryId: 13, pocketBaseId: 'pb-category13',
      fields: {'icon_code_point': 42},
    );
    final pending = await CategoryMutationOutbox.load(prefs, 'account-a');
    expect(pending, hasLength(2));
    final fields = pending.first['fields'] as Map;
    expect(fields['name'], 'Price Reporter');
    expect(fields['color_value'], kNordicWork[400]!.toARGB32());
    expect((pending.last['fields'] as Map)['icon_code_point'], 42);
  });

  test('neutral grey family is achromatic at every selectable intensity', () {
    for (final level in kCategorySelectableTones) {
      final color = kCategoryNeutral[level]!;
      expect(color.r, color.g);
      expect(color.g, color.b);
    }
    expect(kCategorySelectableTones, [400, 500, 600]);
  });
}
