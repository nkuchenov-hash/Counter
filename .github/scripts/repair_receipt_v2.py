from pathlib import Path

path = Path('.github/scripts/apply_receipt_hardening_v2.py')
text = path.read_text(encoding='utf-8')

old_marker = '''        "  test('write-ahead create is durable and duplicate staging coalesces', () async {",
'''
new_marker = '''        "  test(\\n"
        "    'write-ahead create is durable and duplicate staging coalesces',",
'''
if text.count(old_marker) != 1:
    raise SystemExit(f'test marker: expected 1, found {text.count(old_marker)}')
text = text.replace(old_marker, new_marker, 1)

old_replacement_start = '''    replacement = """  test('stale acknowledgement cannot delete a newer plan edit', () async {
'''
new_replacement_start = '''    replacement = """  test(
    'stale acknowledgement cannot delete a newer plan edit',
    () async {
'''
if text.count(old_replacement_start) != 1:
    raise SystemExit(
        f'test replacement start: expected 1, found {text.count(old_replacement_start)}'
    )
text = text.replace(old_replacement_start, new_replacement_start, 1)

old_replacement_end = '''    expect(await PlanMutationOutbox.acknowledge(prefs, latest), isTrue);
    queue = await PlanMutationOutbox.load(prefs);
    expect(queue, isEmpty);
  });"""
'''
new_replacement_end = '''    expect(await PlanMutationOutbox.acknowledge(prefs, latest), isTrue);
    queue = await PlanMutationOutbox.load(prefs);
    expect(queue, isEmpty);
    }"""
'''
if text.count(old_replacement_end) != 1:
    raise SystemExit(
        f'test replacement end: expected 1, found {text.count(old_replacement_end)}'
    )
text = text.replace(old_replacement_end, new_replacement_end, 1)

old_assertion = '''        "    expect(outbox, contains('await _cancelPendingPlanMutationsForBusinessId(businessId)'));\\n",
'''
new_assertion = '''        "    expect(\\n"
        "      outbox,\\n"
        "      contains('await _cancelPendingPlanMutationsForBusinessId(businessId)'),\\n"
        "    );\\n",
'''
if text.count(old_assertion) != 1:
    raise SystemExit(f'test assertion: expected 1, found {text.count(old_assertion)}')
text = text.replace(old_assertion, new_assertion, 1)

path.write_text(text, encoding='utf-8')
print('receipt test patch adapted to formatted test file')
