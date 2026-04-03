"""Emit lib/l10n/langs/{zh,ko,ar,de,fr,it,es}.dart from tool/l10n_bundle.json.

Requires: tool/_en_l10n_pairs.json (key order), tool/l10n_bundle.json
Run: python tool/emit_lang_dart_files.py
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAIRS_PATH = ROOT / "tool" / "_en_l10n_pairs.json"
BUNDLE_PATH = ROOT / "tool" / "l10n_bundle.json"
LANGS_DIR = ROOT / "lib" / "l10n" / "langs"

CONST_NAMES = {
    "zh": "kZhL10n",
    "ko": "kKoL10n",
    "ar": "kArL10n",
    "de": "kDeL10n",
    "fr": "kFrL10n",
    "it": "kItL10n",
    "es": "kEsL10n",
}


def escape_sq(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def dart_value_literal(s: str) -> str:
    """Single- or double-quoted Dart string (prefer ', use \" if simpler)."""
    if "'" not in s:
        return f"'{escape_sq(s)}'"
    if '"' not in s:
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return f"'{escape_sq(s)}'"


def emit_map_entry(key: str, val: str, base_indent: str) -> str:
    k_lit = f"'{escape_sq(key)}'"
    v_lit = dart_value_literal(val)
    one = f"{base_indent}{k_lit}: {v_lit},"
    if len(one) <= 96 and "\n" not in val:
        return one + "\n"
    return f"{base_indent}{k_lit}:\n{base_indent}    {v_lit},\n"


def main() -> None:
    pairs: list[list[str]] = json.loads(PAIRS_PATH.read_text(encoding="utf-8"))
    keys = [p[0] for p in pairs]
    bundle: dict[str, dict[str, str]] = json.loads(BUNDLE_PATH.read_text(encoding="utf-8"))

    LANGS_DIR.mkdir(parents=True, exist_ok=True)

    for code, const in CONST_NAMES.items():
        lang_map = bundle.get(code)
        if not lang_map:
            raise SystemExit(f"bundle missing {code}")
        lines = [
            f"// App strings ({code.upper()}). Auto-generated — edit tool chain, not by hand.\n",
            f"const Map<String, String> {const} = {{\n",
        ]
        ind = "    "
        for k in keys:
            v = lang_map.get(k)
            if v is None:
                raise SystemExit(f"{code} missing key {k!r}")
            lines.append(emit_map_entry(k, v, ind))
        lines.append("};\n")
        out = LANGS_DIR / f"{code}.dart"
        out.write_text("".join(lines), encoding="utf-8")
        print("wrote", out, len(keys), "keys")


if __name__ == "__main__":
    main()
