#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
guard_path = ROOT / "scripts/audit/architecture_guard.ps1"
guard = guard_path.read_text(encoding="utf-8-sig")

old_rules = """    @{ Label = 'data->features'; Path = 'lib/data'; Pattern = \"import 'package:counter/features/\" },
    @{ Label = 'core->features'; Path = 'lib/core'; Pattern = \"import 'package:counter/features/\" },
    @{ Label = 'services->features'; Path = 'lib/services'; Pattern = \"import 'package:counter/features/\" },
"""
new_rules = """    @{ Label = 'data->features'; Path = 'lib/data'; Pattern = \"import 'package:counter/features/\" },
    @{ Label = 'features->pocketbase'; Path = 'lib/features'; Pattern = \"import 'package:pocketbase/\" },
    @{ Label = 'app->pocketbase'; Path = 'lib/app'; Pattern = \"import 'package:pocketbase/\" },
    @{ Label = 'core->pocketbase'; Path = 'lib/core'; Pattern = \"import 'package:pocketbase/\" },
    @{ Label = 'shared->pocketbase'; Path = 'lib/shared'; Pattern = \"import 'package:pocketbase/\" },
    @{ Label = 'services->pocketbase'; Path = 'lib/services'; Pattern = \"import 'package:pocketbase/\" },
    @{ Label = 'core->features'; Path = 'lib/core'; Pattern = \"import 'package:counter/features/\" },
    @{ Label = 'services->features'; Path = 'lib/services'; Pattern = \"import 'package:counter/features/\" },
"""
if old_rules not in guard:
    raise SystemExit("forbidden import rules anchor missing")
guard = guard.replace(old_rules, new_rules, 1)

root_anchor = """# --- 3. Experiment / diag filenames in lib/ ---
"""
layer_gate = """# --- 2b. Fixed top-level owner layers under lib/ ---
$libLayerAllow = @('app', 'core', 'data', 'features', 'l10n', 'services', 'shared')
Get-ChildItem -LiteralPath $libRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($libLayerAllow -notcontains $_.Name) {
        Add-Violation "UNEXPECTED_LIB_LAYER lib/$($_.Name) (allowed owner layers: $($libLayerAllow -join ', '))"
    }
}

"""
if "# --- 2b. Fixed top-level owner layers" not in guard:
    if root_anchor not in guard:
        raise SystemExit("lib layer guard anchor missing")
    guard = guard.replace(root_anchor, layer_gate + root_anchor, 1)

guard_path.write_text(guard.rstrip() + "\n", encoding="utf-8", newline="\n")

architecture_path = ROOT / "docs/ARCHITECTURE.md"
architecture = architecture_path.read_text(encoding="utf-8-sig")
needle = "New features must integrate into the **existing** architecture — not parallel folders, duplicate Brain paths, or feature-local “mini frameworks.” Every new file must have **one clear owner layer**: Entry/Shell, Brain/Data, Core/Foundation, Feature UI, Services, l10n, Platform, Tests, Scripts, or Docs."
replacement = needle + " Under `lib/`, the only top-level owner directories are `app/`, `core/`, `data/`, `features/`, `l10n/`, `services/`, and `shared/`; introducing another top-level runtime layer is an architecture violation, not a convenience." 
if needle not in architecture:
    raise SystemExit("Structure Growth Law anchor missing")
architecture = architecture.replace(needle, replacement, 1)
architecture_path.write_text(architecture.rstrip() + "\n", encoding="utf-8", newline="\n")

print("global_architecture_boundaries: applied")
