from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# DESIGN_SYSTEM: canonical sheet implementation moved into ActivityDetailSheet.
p = ROOT / 'docs/DESIGN_SYSTEM.md'
text = p.read_text(encoding='utf-8')
old = '- Current canonical primary edit-sheet host: `showAppEditSheet` in `lib/core/widgets/app_edit_sheet.dart`.'
new = '- Current canonical primary edit-sheet host: `showAppEditSheet` in `lib/features/shared/activity_detail_sheet.dart`.'
if old not in text:
    raise RuntimeError('Design System edit-sheet path anchor missing')
text = text.replace(old, new, 1)
p.write_text(text, encoding='utf-8')

# DEPLOY: retired Firebase/root cleanup scripts are not part of the live deploy path.
p = ROOT / 'docs/DEPLOY.md'
text = p.read_text(encoding='utf-8')
old = '''## Legacy scripts

- `Archive/root_cleanup_backup/f.ps1` — commit + push only (no analyze/build)
- `lib/deploy.ps1` — Firebase hosting (not used for GitHub Pages)

---

'''
if old not in text:
    raise RuntimeError('DEPLOY legacy scripts block missing')
text = text.replace(old, '', 1)
p.write_text(text, encoding='utf-8')

# Generated build output paths are valid documentation references even though
# they are intentionally absent from git. Keep the exception list explicit.
p = ROOT / 'scripts/audit/documentation_parity.py'
text = p.read_text(encoding='utf-8')
anchor = '''GENERATED_PATH_EXEMPTIONS = {
    "lib/core/env/env.dart",  # generated/gitignored from environment setup
}
'''
replacement = '''GENERATED_PATH_EXEMPTIONS = {
    "lib/core/env/env.dart",  # generated/gitignored from environment setup
}
GENERATED_OUTPUT_PREFIXES = (
    "build/",
    "android/build/",
    "ios/Pods/",
    "installer/windows/output/",
)
'''
if anchor not in text:
    raise RuntimeError('documentation parity generated-exemption anchor missing')
text = text.replace(anchor, replacement, 1)
old = '''                if ref is None or ref in GENERATED_PATH_EXEMPTIONS:
                    continue
                if not (ROOT / ref).exists():
'''
new = '''                if ref is None or ref in GENERATED_PATH_EXEMPTIONS:
                    continue
                if any(ref.startswith(prefix) for prefix in GENERATED_OUTPUT_PREFIXES):
                    continue
                if not (ROOT / ref).exists():
'''
if old not in text:
    raise RuntimeError('documentation parity reference check anchor missing')
text = text.replace(old, new, 1)
p.write_text(text, encoding='utf-8')
