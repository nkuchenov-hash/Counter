from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "scripts/manual/structure_guide_data.py"
text = path.read_text(encoding="utf-8")

anchor = """    merged = dict(data)
    if k in EXACT_FOLDER_RU:
"""
replacement = """    merged = dict(data)
    # Synthesized/inherited folder guides may carry EN text in *_ru fields.
    # Reject those values before adaptation instead of treating them as curated RU.
    for ru_key in (
        "what_ru",
        "why_ru",
        "inside_ru",
        "affects_ru",
        "when_ru",
        "delete_ru",
    ):
        current = merged.get(ru_key, "")
        if current and not ru_field_ok(current, min_cyrillic=4):
            merged[ru_key] = ""
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
