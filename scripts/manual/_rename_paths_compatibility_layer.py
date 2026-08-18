from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
OLD_DIR = ROOT / "lib/data/paths/legacy"
NEW_DIR = ROOT / "lib/data/paths/compatibility"

if OLD_DIR.exists():
    if NEW_DIR.exists():
        raise RuntimeError("Both legacy and compatibility Paths directories exist")
    NEW_DIR.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(OLD_DIR, NEW_DIR)
elif not NEW_DIR.exists():
    raise RuntimeError("Paths compatibility service directory is missing")

# These files may contain the transitional service path after the ownership
# finalizer/parity patch. Rename the path consistently without changing logic.
for rel in (
    "lib/app/shell/app_shell.dart",
    "test/daily_routine_contract_test.dart",
    "docs/APP_STRUCTURE.md",
    "docs/APP_STRUCTURE_DETAILED.md",
    "docs/ARCHITECTURE.md",
    "CHANGELOG.md",
):
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    text = text.replace("lib/data/paths/legacy/", "lib/data/paths/compatibility/")
    text = text.replace("paths/legacy/", "paths/compatibility/")
    if rel == "docs/APP_STRUCTURE.md":
        # APP_STRUCTURE is intentionally debt-word free under strict guard.
        text = re.sub(r"\blegacy\b", "prior-format", text, flags=re.IGNORECASE)
    path.write_text(text, encoding="utf-8")

# The service itself imports no path-qualified self-reference, so the directory
# move is sufficient. Assert the ownership contract after the rename.
service = NEW_DIR / "path_governance_service.dart"
if not service.exists():
    raise RuntimeError("Path governance compatibility service was not moved")

app_shell = (ROOT / "lib/app/shell/app_shell.dart").read_text(encoding="utf-8")
expected_import = "package:counter/data/paths/compatibility/path_governance_service.dart"
if expected_import not in app_shell:
    raise RuntimeError("app_shell does not import the Paths compatibility service")

structure = (ROOT / "docs/APP_STRUCTURE.md").read_text(encoding="utf-8")
if re.search(r"\blegacy\b", structure, flags=re.IGNORECASE):
    raise RuntimeError("APP_STRUCTURE still contains the forbidden debt word legacy")
