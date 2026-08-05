from pathlib import Path

path = Path('.github/scripts/strengthen_live_sync_receipts.py')
text = path.read_text(encoding='utf-8')

old_success = '''    text = replace_once(
        text,
        "      await _cancelPendingPlanMutationsForBusinessId(clientPlanId);\\n"
        "      await offlineSync.refreshPendingCount();\\n",
        "      await _acknowledgePlanMutation(writeAheadReceipt);\\n",
        'ack exact create receipt on success',
    )
'''
new_success = '''    text = replace_once(
        text,
        "      _allPlansUserCacheFetchedAt = DateTime.now();\\n"
        "      await _cancelPendingPlanMutationsForBusinessId(clientPlanId);\\n"
        "      await offlineSync.refreshPendingCount();\\n",
        "      _allPlansUserCacheFetchedAt = DateTime.now();\\n"
        "      await _acknowledgePlanMutation(writeAheadReceipt);\\n",
        'ack exact create receipt on success',
    )
'''
if text.count(old_success) != 1:
    raise SystemExit(
        f'expected one create-success target, found {text.count(old_success)}'
    )
text = text.replace(old_success, new_success, 1)

old_marker = '''        "  test('write-ahead create is durable and duplicate staging coalesces', () async {",
'''
new_marker = '''        "  test(\\n"
        "    'write-ahead create is durable and duplicate staging coalesces',\\n",
'''
if text.count(old_marker) != 1:
    raise SystemExit(f'expected one test marker, found {text.count(old_marker)}')
text = text.replace(old_marker, new_marker, 1)

old_test_close = '''    expect(await PlanMutationOutbox.acknowledge(prefs, secondUpdate), isTrue);
    expect(await PlanMutationOutbox.load(prefs), isEmpty);
  });"""
'''
new_test_close = '''    expect(await PlanMutationOutbox.acknowledge(prefs, secondUpdate), isTrue);
    expect(await PlanMutationOutbox.load(prefs), isEmpty);
  },
  );"""
'''
if text.count(old_test_close) != 1:
    raise SystemExit(
        f'expected one first-test close target, found {text.count(old_test_close)}'
    )
text = text.replace(old_test_close, new_test_close, 1)

old_expect = '''        "    expect(outbox, contains('await _cancelPendingPlanMutationsForBusinessId(businessId)'));\\n",
        "    expect(outbox, contains('await _acknowledgePlanMutation(writeAheadReceipt)'));\\n"
        "    expect(outbox, isNot(contains('await _pbTagRecordIdsFromTags(tags);')));\\n",
'''
new_expect = '''        "    expect(\\n"
        "      outbox,\\n"
        "      contains('await _cancelPendingPlanMutationsForBusinessId(businessId)'),\\n"
        "    );\\n",
        "    expect(\\n"
        "      outbox,\\n"
        "      contains('await _acknowledgePlanMutation(writeAheadReceipt)'),\\n"
        "    );\\n"
        "    expect(\\n"
        "      outbox,\\n"
        "      isNot(contains('await _pbTagRecordIdsFromTags(tags);')),\\n"
        "    );\\n",
'''
if text.count(old_expect) != 1:
    raise SystemExit(f'expected one test-expect target, found {text.count(old_expect)}')
text = text.replace(old_expect, new_expect, 1)

path.write_text(text, encoding='utf-8')
print('receipt hardening script repaired')
