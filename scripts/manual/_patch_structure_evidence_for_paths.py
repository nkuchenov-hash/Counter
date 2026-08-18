#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
path = root / 'scripts/manual/structure_evidence_index.py'
text = path.read_text(encoding='utf-8-sig')

text = text.replace(
    r'installer|pb_hooks|\.github|\.cursor)',
    r'installer|pb_hooks|pb_migrations|\.github|\.cursor)',
)
text = text.replace(
    '    if p.startswith("pb_hooks/"):\n        return "PocketBase backend", "PocketBase backend"',
    '    if p.startswith("pb_migrations/"):\n        return "PocketBase migrations", "миграции PocketBase"\n'
    '    if p.startswith("pb_hooks/"):\n        return "PocketBase backend", "PocketBase backend"',
)
text = text.replace(
    '    if p.startswith("pb_hooks/"):\n        return "PocketBase backend"',
    '    if p.startswith("pb_migrations/"):\n        return "PocketBase migration"\n'
    '    if p.startswith("pb_hooks/"):\n        return "PocketBase backend"',
)
anchor = '''        # --- PocketBase ---\n        elif path.startswith("pb_hooks/"):\n'''
replacement = '''        # --- PocketBase migrations ---\n        elif path.startswith("pb_migrations/"):\n            role = "PocketBase migration"\n            evidence_en.append(\n                "Versioned PocketBase schema/data migration; applied by PocketBase before "\n                "client code that depends on the schema (see `docs/DEPLOY.md`)."\n            )\n            evidence_ru.append(\n                "Версионированная миграция схемы/данных PocketBase; применяется до "\n                "клиента, который зависит от этой схемы (см. `docs/DEPLOY.md`)."\n            )\n            necessity = "PROVEN_REQUIRED"\n            confidence = "HIGH"\n            deletion_en = "Production schema history becomes incomplete or a required data migration is lost."\n            deletion_ru = "История production-схемы станет неполной или пропадёт нужная миграция данных."\n\n        # --- PocketBase ---\n        elif path.startswith("pb_hooks/"):\n'''
if anchor not in text:
    raise SystemExit('PocketBase evidence anchor missing')
text = text.replace(anchor, replacement)
path.write_text(text.rstrip() + '\n', encoding='utf-8', newline='\n')
print('structure_evidence_paths_patch: applied')
