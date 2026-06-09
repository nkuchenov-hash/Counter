"""Translate unique EN UI strings via translators (Bing). Writes tool/l10n_bundle.json.

Run:  python tool/fetch_translators_bundle.py
Env: PYTHONUTF8=1 recommended on Windows.
"""
from __future__ import annotations

import json
import time
from collections import defaultdict
from pathlib import Path

import translators as ts

ROOT = Path(__file__).resolve().parent.parent
PAIRS_PATH = ROOT / "tool" / "_en_l10n_pairs.json"
OUT_PATH = ROOT / "tool" / "l10n_bundle.json"
CACHE_PATH = ROOT / "tool" / "_translators_cache.json"

# Bing target language codes used by translators
LANG_TO_BING: dict[str, str] = {
    "zh": "zh-Hans",
    "ko": "ko",
    "ar": "ar",
    "de": "de",
    "fr": "fr",
    "it": "it",
    "es": "es",
}

DELAY = 0.25
ENGINE = "bing"


def load_cache() -> dict[str, str]:
    if CACHE_PATH.is_file():
        return json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    return {}


def save_cache(c: dict[str, str]) -> None:
    CACHE_PATH.write_text(json.dumps(c, ensure_ascii=False, indent=2), encoding="utf-8")


def translate(lang: str, text: str, cache: dict[str, str]) -> str:
    tgt = LANG_TO_BING[lang]
    ck = f"{lang}||{text}"
    if ck in cache:
        return cache[ck]
    try:
        out = ts.translate_text(
            text,
            translator=ENGINE,
            from_language="en",
            to_language=tgt,
        )
    except Exception:
        out = text
    if not isinstance(out, str):
        out = str(text)
    out = out.strip()
    if out.startswith("[") and "ترجمة" in out:
        out = text
    if "[翻译]" in out or "[译]" in out:
        out = text
    cache[ck] = out
    time.sleep(DELAY)
    return out


def main() -> None:
    pairs: list[list[str]] = json.loads(PAIRS_PATH.read_text(encoding="utf-8"))
    keys = [p[0] for p in pairs]
    en_vals = [p[1] for p in pairs]
    by_en: dict[str, list[int]] = defaultdict(list)
    for i, v in enumerate(en_vals):
        by_en[v].append(i)

    cache = load_cache()
    bundle: dict[str, dict[str, str]] = {x: {} for x in LANG_TO_BING}

    for lang in LANG_TO_BING:
        for en_text, idxs in by_en.items():
            tr = translate(lang, en_text, cache)
            for i in idxs:
                bundle[lang][keys[i]] = tr
        save_cache(cache)
        tmp = OUT_PATH.with_suffix(".tmp")
        tmp.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(OUT_PATH)

    key_to_en = {k: v for k, v in pairs}
    hint = key_to_en["hint_voice_example"]
    for lang in bundle:
        bundle[lang]["hint_voice_example"] = hint
        for hk in ("app_title", "auth_headline", "auth_biometric_reason"):
            v = bundle[lang].get(hk, "")
            if isinstance(v, str) and v.strip().upper() == "LIFE OS":
                bundle[lang][hk] = "Life OS"

    tmp = OUT_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(OUT_PATH)
    save_cache(cache)


if __name__ == "__main__":
    main()
