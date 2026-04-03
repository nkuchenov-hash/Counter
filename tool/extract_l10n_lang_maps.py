"""One-off: extract en/ru maps from lib/l10n/dictionary.dart into lib/l10n/langs/."""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
text = (root / "lib/l10n/dictionary.dart").read_text(encoding="utf-8")

m_en = re.search(r"'en':\s*\{([\s\S]*?)\n\s*\},\s*\n\s*'ru':", text)
m_ru = re.search(r"'ru':\s*\{([\s\S]*?)\n\s*\},\s*\n\};", text)
if not m_en or not m_ru:
    raise SystemExit("Could not parse en/ru maps from dictionary.dart")

lang_dir = root / "lib" / "l10n" / "langs"
lang_dir.mkdir(parents=True, exist_ok=True)

for name, body, const in (
    ("en", m_en.group(1).strip(), "kEnL10n"),
    ("ru", m_ru.group(1).strip(), "kRuL10n"),
):
    out = (
        f"// App strings ({name.upper()}).\n"
        "library;\n\n"
        f"const Map<String, String> {const} = {{\n{body}\n}};\n"
    )
    (lang_dir / f"{name}.dart").write_text(out, encoding="utf-8")

print("Wrote", lang_dir / "en.dart", lang_dir / "ru.dart")
