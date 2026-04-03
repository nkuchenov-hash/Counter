"""Fill empty or short locales in tool/l10n_bundle.json (e.g. it, es)."""
from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fetch_translators_bundle import (
    LANG_TO_BING,
    OUT_PATH,
    PAIRS_PATH,
    load_cache,
    save_cache,
    translate,
)

def main() -> None:
    pairs: list[list[str]] = json.loads(PAIRS_PATH.read_text(encoding="utf-8"))
    keys = [p[0] for p in pairs]
    en_vals = [p[1] for p in pairs]
    by_en: dict[str, list[int]] = defaultdict(list)
    for i, v in enumerate(en_vals):
        by_en[v].append(i)

    bundle = json.loads(OUT_PATH.read_text(encoding="utf-8"))
    cache = load_cache()

    for lang in LANG_TO_BING:
        n = len(bundle.get(lang) or {})
        if n >= len(keys):
            continue
        print("filling", lang, "had", n, flush=True)
        bundle[lang] = {}
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
    print("done", {k: len(v) for k, v in bundle.items()}, flush=True)


if __name__ == "__main__":
    main()
