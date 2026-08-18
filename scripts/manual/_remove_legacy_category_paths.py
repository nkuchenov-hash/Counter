#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Categories settings must manage categories only. The old V1 plan-backed Paths
# editor was superseded by the first-class Paths feature and must not retain
# marker parsing, PlanningTask writes, or a second Path UI inside Categories.
page_path = ROOT / "lib/features/settings/categories/category_list_view.dart"
page = page_path.read_text(encoding="utf-8-sig")
marker = "// ---------------------------------------------------------------------------\n// CATEGORY PATHS — living date-free sequence from a project goal to next steps."
idx = page.find(marker)
if idx < 0:
    raise SystemExit("legacy Category Paths section anchor missing")
page = page[:idx].rstrip() + "\n"
page = page.replace(
    "import 'package:counter/core/widgets/app_button.dart';\n",
    "",
)
page_path.write_text(page, encoding="utf-8", newline="\n")

# PathRepository may mention PocketBase in architecture comments; the boundary
# guard must detect actual SDK/import/collection I/O, not prose.
guard_path = ROOT / "scripts/audit/architecture_guard.ps1"
guard = guard_path.read_text(encoding="utf-8-sig")
old = "if ($pathRepositoryBody -match 'PocketBase|\\.collection\\(') {"
new = "if ($pathRepositoryBody -match \"import 'package:pocketbase/|\\.collection\\(\") {"
if old not in guard:
    raise SystemExit("PathRepository direct-I/O guard anchor missing")
guard = guard.replace(old, new, 1)
guard_path.write_text(guard.rstrip() + "\n", encoding="utf-8", newline="\n")

print("legacy_category_paths_cleanup: applied")
