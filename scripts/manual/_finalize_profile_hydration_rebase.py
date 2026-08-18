from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
structure = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure.read_text(encoding='utf-8')

shell_row = '| `app/shell/shared/profile_hydration_status_bar.dart` | Compatibility re-export → `features/profile/profile_hydration_status_bar.dart`; shell does not own Profile hydration UI |'
lines = doc.splitlines()
for index, line in enumerate(lines):
    if line.startswith('| `app/shell/shared/profile_hydration_status_bar.dart` |'):
        lines[index] = shell_row
        break
else:
    raise RuntimeError('profile hydration shell row not found')

feature_row = '| `features/profile/profile_hydration_status_bar.dart` | Profile-owned hydration error/retry status UI |'
if feature_row not in lines:
    shell_index = lines.index(shell_row)
    lines.insert(shell_index + 1, feature_row)

doc = '\n'.join(lines) + ('\n' if doc.endswith('\n') else '')
structure.write_text(doc, encoding='utf-8')

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Profile hydration UI ownership [engineering]\n\n- Moved `ProfileHydrationStatusBar` implementation into `features/profile/`.\n- Shell/shared and old `features/shared/` paths are compatibility re-exports only.\n- Hydration error/retry behavior is unchanged; Profile now owns its own status UI.\n\n'''
if not text.startswith('## 2026-08-18 — Profile hydration UI ownership [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')
