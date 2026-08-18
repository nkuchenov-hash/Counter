from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "scripts/manual/structure_guide_data.py"
text = path.read_text(encoding="utf-8")

anchor = """    merged = dict(data)
    if k in EXACT_FOLDER_RU:
"""
replacement = """    merged = dict(data)
    # Synthesized/inherited guides can carry copied EN prose in *_ru fields.
    # `_folder_ru_auto` already owns path-aware Russian fallbacks; normalize to
    # those before curated/adapted values are considered.
    auto_ru = _folder_ru_auto(k, merged)
    for ru_key in (
        "what_ru",
        "why_ru",
        "inside_ru",
        "affects_ru",
        "when_ru",
        "delete_ru",
        "related_ru",
    ):
        current = merged.get(ru_key, "")
        current_ok = bool(current) and (
            ru_key == "related_ru" or ru_field_ok(current, min_cyrillic=4)
        )
        if not current_ok and auto_ru.get(ru_key):
            merged[ru_key] = auto_ru[ru_key]
    if k in EXACT_FOLDER_RU:
"""
if anchor not in text:
    raise RuntimeError("ensure_folder_ru merge anchor not found")
text = text.replace(anchor, replacement, 1)

old_inline = """        if inline and not has_banned_filler(inline) and not inline.startswith("NEEDS HUMAN"):
            merged[suffix] = inline
"""
new_inline = """        if (
            inline
            and not has_banned_filler(inline)
            and not inline.startswith("NEEDS HUMAN")
            and (suffix == "related_ru" or ru_field_ok(inline, min_cyrillic=4))
        ):
            merged[suffix] = inline
"""
if old_inline not in text:
    raise RuntimeError("ensure_folder_ru inline anchor not found")
text = text.replace(old_inline, new_inline, 1)
path.write_text(text, encoding="utf-8")
