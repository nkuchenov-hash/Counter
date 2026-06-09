"""Parse lib/l10n/langs/en.dart into list of (key, value)."""
import re
from pathlib import Path


def parse_map_body(body: str) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    i = 0
    n = len(body)

    def skip_space() -> None:
        nonlocal i
        while i < n and body[i] in " \t\n\r":
            i += 1

    def read_single_quoted() -> str:
        nonlocal i
        if i >= n or body[i] != "'":
            raise ValueError(f"expected ' at {i}")
        i += 1
        buf: list[str] = []
        while i < n:
            c = body[i]
            if c == "\\":
                i += 1
                if i >= n:
                    raise ValueError("escape EOF")
                buf.append(body[i])
                i += 1
                continue
            if c == "'":
                i += 1
                break
            buf.append(c)
            i += 1
        return "".join(buf)

    def read_double_quoted() -> str:
        nonlocal i
        if i >= n or body[i] != '"':
            raise ValueError(f'expected " at {i}')
        i += 1
        buf: list[str] = []
        while i < n:
            c = body[i]
            if c == "\\":
                i += 1
                if i >= n:
                    raise ValueError("escape EOF")
                buf.append(body[i])
                i += 1
                continue
            if c == '"':
                i += 1
                break
            buf.append(c)
            i += 1
        return "".join(buf)

    while i < n:
        skip_space()
        if i >= n:
            break
        key = read_single_quoted()
        skip_space()
        if i >= n or body[i] != ":":
            raise ValueError(f"expected : after key {key!r} at {i}")
        i += 1
        skip_space()
        if i >= n:
            raise ValueError(f"EOF after key {key!r}")
        if body[i] == "'":
            value = read_single_quoted()
        elif body[i] == '"':
            value = read_double_quoted()
        else:
            raise ValueError(f"bad value start for {key!r}: {body[i : i + 20]!r}")
        pairs.append((key, value))
        skip_space()
        if i < n and body[i] == ",":
            i += 1
    return pairs


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    text = (root / "lib/l10n/langs/en.dart").read_text(encoding="utf-8")
    m = re.search(r"kEnL10n = \{([\s\S]*)\};", text)
    if not m:
        raise SystemExit("parse fail")
    pairs = parse_map_body(m.group(1))
    print("count", len(pairs))
    import json

    out = root / "tool" / "_en_l10n_pairs.json"
    out.write_text(
        json.dumps(pairs, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print("wrote", out)


if __name__ == "__main__":
    main()
