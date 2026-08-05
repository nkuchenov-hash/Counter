from pathlib import Path

path = Path('.github/scripts/apply_live_sync_fix.py')
text = path.read_text(encoding='utf-8')
old = """    brace = text.find('{', start)
    if brace < 0:
        raise RuntimeError(f'opening brace not found: {marker}')
"""
new = """    async_body = text.find(') async {', start)
    sync_body = text.find(') {', start)
    candidates = [p for p in (async_body, sync_body) if p >= 0]
    if not candidates:
        raise RuntimeError(f'function body not found: {marker}')
    body_marker = min(candidates)
    brace = text.find('{', body_marker)
"""
if text.count(old) != 1:
    raise SystemExit(f'parser repair expected one match, found {text.count(old)}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('live sync patch parser repaired')
