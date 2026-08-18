from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / 'scripts/manual/generate_app_structure_detailed.py'
text = p.read_text(encoding='utf-8')
old = '    body = "\\n".join(lines)\n'
new = '    body = "\\n".join(lines).rstrip() + "\\n"\n'
if old not in text:
    raise RuntimeError('detailed generator body join anchor missing')
p.write_text(text.replace(old, new, 1), encoding='utf-8')
