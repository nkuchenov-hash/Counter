"""Fetch MyMemory translations for unique EN strings; build tool/l10n_bundle.json.

Run from repo root: python tool/fetch_mymemory_translations.py

Respects MyMemory fair-use: delay between requests, on-disk cache for reruns.
"""
from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAIRS_PATH = ROOT / "tool" / "_en_l10n_pairs.json"
CACHE_PATH = ROOT / "tool" / "_mymemory_cache.json"
OUT_PATH = ROOT / "tool" / "l10n_bundle.json"

# MyMemory langpair targets (second code)
LANG_TARGETS: dict[str, str] = {
    "zh": "zh-CN",
    "ko": "ko",
    "ar": "ar",
    "de": "de",
    "fr": "fr",
    "it": "it",
    "es": "es",
}

DELAY_SEC = 0.35
USER_AGENT = "life-os-l10n-fetch/1.0"


def load_cache() -> dict[str, str]:
    if not CACHE_PATH.is_file():
        return {}
    return json.loads(CACHE_PATH.read_text(encoding="utf-8"))


def save_cache(cache: dict[str, str]) -> None:
    CACHE_PATH.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")


def translate_one(lang: str, text: str, cache: dict[str, str]) -> str:
    tgt = LANG_TARGETS[lang]
    ck = f"{lang}||{text}"
    if ck in cache:
        return cache[ck]
    q = urllib.parse.quote(text[:500])
    url = f"https://api.mymemory.translated.net/get?q={q}&langpair=en|{tgt}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=45) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    out = (data.get("responseData") or {}).get("translatedText") or text
    if isinstance(out, str):
        out = out.strip()
    else:
        out = text
    cache[ck] = out
    time.sleep(DELAY_SEC)
    return out


def main() -> None:
    pairs: list[list[str]] = json.loads(PAIRS_PATH.read_text(encoding="utf-8"))
    keys = [p[0] for p in pairs]
    en_vals = [p[1] for p in pairs]
    idxs_by_en: dict[str, list[int]] = defaultdict(list)
    for i, v in enumerate(en_vals):
        idxs_by_en[v].append(i)

    cache = load_cache()
    bundle: dict[str, dict[str, str]] = {code: {} for code in LANG_TARGETS}

    for lang in LANG_TARGETS:
        print("lang", lang, flush=True)
        for en_text, idx_list in idxs_by_en.items():
            try:
                tr = translate_one(lang, en_text, cache)
            except Exception as e:
                print("ERR", lang, repr(en_text[:50]), e, flush=True)
                tr = en_text
            for i in idx_list:
                bundle[lang][keys[i]] = tr
        save_cache(cache)
        OUT_PATH.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")

    # Keep mixed-lang voice example identical across locales (matches EN source).
    key_to_en = {k: v for k, v in pairs}
    hint_val = key_to_en["hint_voice_example"]
    for lang in bundle:
        bundle[lang]["hint_voice_example"] = hint_val

    OUT_PATH.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")
    print("wrote", OUT_PATH, flush=True)


if __name__ == "__main__":
    main()
