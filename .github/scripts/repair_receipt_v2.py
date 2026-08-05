from pathlib import Path

path = Path('.github/scripts/apply_receipt_hardening_v2.py')
text = path.read_text(encoding='utf-8')

old = '''    text = read(path)
    text = replace_once(
        text,
        "bool _planMutationOutboxFlushInFlight = false;\\n",
        "bool _planMutationOutboxFlushInFlight = false;\\n"
        "final Map<String, int> _pendingPlanMutationRevisionByBusinessId =\\n"
        "    <String, int>{{}};\\n",
        'pending revision map',
    )
    write(path, text)

'''
if text.count(old) != 1:
    raise SystemExit(f'helper map block: expected 1, found {text.count(old)}')
text = text.replace(old, '', 1)

marker = '''def patch_plan_service() -> None:
    path = 'lib/data/plan_service.dart'
    text = read(path)
'''
replacement = '''def patch_plan_service() -> None:
    path = 'lib/data/plan_service.dart'
    text = read(path)
    text = replace_once(
        text,
        "bool _planMutationOutboxFlushInFlight = false;\\n",
        "bool _planMutationOutboxFlushInFlight = false;\\n"
        "final Map<String, int> _pendingPlanMutationRevisionByBusinessId =\\n"
        "    <String, int>{{}};\\n",
        'pending revision map',
    )
'''
if text.count(marker) != 1:
    raise SystemExit(f'plan service marker: expected 1, found {text.count(marker)}')
text = text.replace(marker, replacement, 1)
path.write_text(text, encoding='utf-8')
print('receipt v2 insertion point repaired')
