from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
structure = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure.read_text(encoding='utf-8')
old = '| `app/shell/shared/settings_page.dart` | Language/TZ settings page (shell route) |'
new = '| `app/shell/shared/settings_page.dart` | Compatibility re-export → `features/profile/settings/settings_page.dart`; shell does not own Settings UI |'
if new not in doc:
    if old not in doc:
        raise RuntimeError('Settings shell structure row not found')
    doc = doc.replace(old, new, 1)
feature = '| `features/profile/settings/settings_page.dart` | Profile-owned language/timezone Settings page; persists through Profile/DatabaseService APIs |'
if feature not in doc:
    doc = doc.replace(new, new + '\n' + feature, 1)
structure.write_text(doc, encoding='utf-8')
changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Settings feature ownership [engineering]\n\n- `features/profile/settings/settings_page.dart` now owns the real Settings UI.\n- `app/shell/shared/settings_page.dart` is a compatibility re-export only.\n- Language/timezone behavior and persistence are unchanged.\n\n'''
if not text.startswith('## 2026-08-18 — Settings feature ownership [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')
