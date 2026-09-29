from pathlib import Path

p = Path('test/auto_plan_nearest_free_slot_test.dart')
text = p.read_text(encoding='utf-8')
anchor = "\n}\n"
if not text.endswith(anchor):
    raise SystemExit('auto plan test final brace not found')
addition = r'''

  test('copyWith can invalidate stale UTC when wall schedule changes', () {
    final task = PlanningTask(
      id: 0,
      planRowId: 'plan-utc-move',
      title: 'Plan',
      categoryId: 1,
      dateKey: '2026-09-29',
      startTime: DateTime(2026, 9, 29, 10),
      endDateTime: DateTime(2026, 9, 29, 10, 30),
      startUtcInstant: DateTime.utc(2026, 9, 29, 14),
      endUtcInstant: DateTime.utc(2026, 9, 29, 14, 30),
    );

    final moved = task.copyWith(
      startTime: DateTime(2026, 9, 29, 12),
      endDateTime: DateTime(2026, 9, 29, 12, 30),
      clearStartUtc: true,
      clearEndUtc: true,
    );

    expect(moved.startTime, DateTime(2026, 9, 29, 12));
    expect(moved.startUtcInstant, isNull);
    expect(moved.endUtcInstant, isNull);
  });

  test('collision-resolved create does not retain pre-collision UTC instant', () {
    final incoming = PlanningTask(
      id: 0,
      planRowId: 'incoming-utc',
      title: 'Incoming',
      categoryId: 1,
      dateKey: '2026-09-29',
      startTime: DateTime(2026, 9, 29, 10),
      endDateTime: DateTime(2026, 9, 29, 10, 30),
      startUtcInstant: DateTime.utc(2026, 9, 29, 14),
      endUtcInstant: DateTime.utc(2026, 9, 29, 14, 30),
    );
    final occupied = PlanningTask(
      id: 0,
      planRowId: 'occupied-utc',
      title: 'Occupied',
      categoryId: 1,
      dateKey: '2026-09-29',
      startTime: DateTime(2026, 9, 29, 10),
      endDateTime: DateTime(2026, 9, 29, 11),
    );

    final resolved = DatabaseService.instance.resolvePlanningCreateCollision(
      task: incoming,
      wallDay: DateTime(2026, 9, 29),
      existingDayPlans: [occupied],
    ).task;

    expect(resolved.startTime, DateTime(2026, 9, 29, 11));
    expect(resolved.startUtcInstant, isNull);
    expect(resolved.endUtcInstant, isNull);
  });
'''
if "copyWith can invalidate stale UTC when wall schedule changes" not in text:
    text = text[:-2] + addition + "\n}\n"
p.write_text(text, encoding='utf-8')

Path('test/plan_wall_utc_mutation_test.dart').unlink(missing_ok=True)
