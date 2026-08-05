from pathlib import Path

path = Path('.github/scripts/strengthen_live_sync_receipts.py')
text = path.read_text(encoding='utf-8')
old = '''    text = replace_once(
        text,
        "      await _cancelPendingPlanMutationsForBusinessId(clientPlanId);\\n"
        "      await offlineSync.refreshPendingCount();\\n",
        "      await _acknowledgePlanMutation(writeAheadReceipt);\\n",
        'ack exact create receipt on success',
    )
'''
new = '''    text = replace_once(
        text,
        "      _allPlansUserCacheFetchedAt = DateTime.now();\\n"
        "      await _cancelPendingPlanMutationsForBusinessId(clientPlanId);\\n"
        "      await offlineSync.refreshPendingCount();\\n",
        "      _allPlansUserCacheFetchedAt = DateTime.now();\\n"
        "      await _acknowledgePlanMutation(writeAheadReceipt);\\n",
        'ack exact create receipt on success',
    )
'''
if text.count(old) != 1:
    raise SystemExit(f'expected one receipt-script target, found {text.count(old)}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('receipt hardening script repaired')
