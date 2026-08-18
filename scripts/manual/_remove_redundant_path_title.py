#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def rw(rel: str, transform):
    path = ROOT / rel
    text = path.read_text(encoding="utf-8-sig")
    text = transform(text)
    path.write_text(text.rstrip() + "\n", encoding="utf-8", newline="\n")


def service(text: str) -> str:
    text = text.replace("    required String title,\n", "", 1)
    text = text.replace("        'title': title.trim(),\n", "", 1)
    text = text.replace("    required String title,\n", "", 1)
    text = text.replace("        'title': title.trim(),\n", "", 1)
    return text


def repository(text: str) -> str:
    text = text.replace("        title: category.name,\n", "", 1)
    text = text.replace("        title: current.category.name,\n", "", 1)
    return text


def migration(text: str) -> str:
    text = text.replace('        { name: "title", type: "text", required: true, max: 300 },\n', "", 1)
    text = text.replace('    path.set("title", root.getString("title") || "Path")\n', "", 1)
    return text


def manifest(text: str) -> str:
    text = text.replace("| `title` | text | Project display title snapshot. |\n", "")
    return text

rw("lib/data/paths/path_service.dart", service)
rw("lib/data/paths/path_repository.dart", repository)
rw("pb_migrations/1787076000_durable_paths.js", migration)
rw("docs/POCKETBASE_MANIFEST.md", manifest)
print("path_title_ssot: applied")
