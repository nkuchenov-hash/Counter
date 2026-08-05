from pathlib import Path

path = Path('.github/scripts/apply_live_sync_fix.py')
text = path.read_text(encoding='utf-8')

old_parser = """    brace = text.find('{', start)
    if brace < 0:
        raise RuntimeError(f'opening brace not found: {marker}')
"""
new_parser = """    async_body = text.find(') async {', start)
    sync_body = text.find(') {', start)
    candidates = [p for p in (async_body, sync_body) if p >= 0]
    if not candidates:
        raise RuntimeError(f'function body not found: {marker}')
    body_marker = min(candidates)
    brace = text.find('{', body_marker)
"""
if text.count(old_parser) != 1:
    raise SystemExit(
        f'parser repair expected one match, found {text.count(old_parser)}'
    )
text = text.replace(old_parser, new_parser, 1)

old_replace = """def replace_once(text: str, old: str, new: str, *, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)
"""
new_replace = """def replace_once(text: str, old: str, new: str, *, label: str) -> str:
    count = text.count(old)
    if label == 'create nonretriable clears write-ahead' and count == 2:
        index = text.rfind(old)
        return text[:index] + new + text[index + len(old):]
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)
"""
if text.count(old_replace) != 1:
    raise SystemExit(
        f'replace helper repair expected one match, found {text.count(old_replace)}'
    )
text = text.replace(old_replace, new_replace, 1)

path.write_text(text, encoding='utf-8')
print('live sync patch parser repaired')
