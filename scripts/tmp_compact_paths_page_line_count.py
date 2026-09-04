from pathlib import Path

p = Path('lib/features/paths/paths_page.dart')
text = p.read_text(encoding='utf-8')
old = """      child: SafeArea(\n        top: false,\n        bottom: false,\n        child: Column("""
new = """      child: SafeArea(\n        bottom: false,\n        child: Column("""
if text.count(old) != 1:
    raise SystemExit('SafeArea block not found exactly once')
text = text.replace(old, new, 1)
old = """      padding: EdgeInsets.fromLTRB(\n        20,\n        MediaQuery.paddingOf(context).top,\n        12,\n        12,\n      ),"""
new = """      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),"""
if text.count(old) != 1:
    raise SystemExit('Header padding block not found exactly once')
text = text.replace(old, new, 1)
p.write_text(text, encoding='utf-8')
