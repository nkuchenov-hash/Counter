from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]

def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding='utf-8')

def ensure_section(file_name: str, marker: str, section: str) -> None:
    path = ROOT / file_name
    text = path.read_text(encoding='utf-8')
    if marker in text:
        start = text.index(marker)
        end = text.find('\n## ', start + len(marker))
        if end < 0:
            end = len(text)
        text = text[:start] + section.strip() + '\n\n' + text[end:].lstrip('\n')
    else:
        text = text.rstrip() + '\n\n' + section.strip() + '\n'
    path.write_text(text, encoding='utf-8')

app_structure = ROOT / 'docs/APP_STRUCTURE.md'
text = app_structure.read_text(encoding='utf-8')
marker = '### 3.2.P People — Settings-owned personal relationship domain'
block = '''### 3.2.P People — Settings-owned personal relationship domain

People is an on-demand Settings feature. External address books stay in a hidden source index and never become visible People merely because a contact exists in a provider.

| Path | Role |
| :--- | :--- |
| `lib/data/people/people_models.dart` | Person, Circle, source-contact and integration domain types |
| `lib/data/people/people_service.dart` | On-demand PocketBase CRUD, photo upload, source-index review/link operations, device/Telegram import and bounded birthday reminder reconcile |
| `lib/data/people/people_device_contacts_bridge.dart` | Explicit user-triggered Android/iOS address-book bridge; no startup scan |
| `lib/data/people/people_integration_service.dart` | Client for server-owned Google/Microsoft/VK/Facebook People source connections and sync |
| `lib/features/settings/people/people_settings_page.dart` | Stable export for Settings → Account → People |
| `lib/features/settings/people/people_settings_page_impl.dart` | People / Circles / Sources page composition and Person/Circle list state |
| `lib/features/settings/people/people_avatar.dart` | Person/source avatar renderer with uploaded-photo and source-avatar fallback |
| `lib/features/settings/people/people_person_editor.dart` | Person editor: photo, contact data, relationship, birthday/reminders, circles and notes |
| `lib/features/settings/people/people_sources_section.dart` | Provider cards, sync/import controls and explicit Add / Link / Ignore / Block review flow |
| `lib/features/settings/people/people_strings.dart` | Feature-local EN/RU copy for the People settings surface |

**People source law:** provider records have explicit review, linked, ignored, and blocked states; only an explicit Add/Link action creates or connects a visible Person. Suppression survives later source syncs. Circles are many-to-many and are not task Categories.

'''
if marker in text:
    start = text.index(marker)
    end = text.find('\n## ', start)
    if end < 0:
        end = len(text)
    text = text[:start] + block + text[end:].lstrip('\n')
else:
    anchor = '\n## 4.'
    if anchor not in text:
        raise SystemExit('APP_STRUCTURE root anchor not found')
    text = text.replace(anchor, '\n' + block + anchor.lstrip('\n'), 1)
app_structure.write_text(text, encoding='utf-8')

ensure_section('docs/DATA_MAP.md', '## People domain (2026-09-03)', '''
## People domain (2026-09-03)

People is a separate personal-relationship domain and does not reuse plan Categories.

### `people`
- PocketBase system `id`, owner `user_id`, stable business `person_id`.
- `display_name`, `primary_email`, `primary_phone`, photo/source-avatar, relationship status, birthday/reminder settings, Circles, notes and archive state.

### `people_circles`
Owner-scoped stable circles. One Person may belong to multiple Circles; Circles are independent of task Categories.

### `people_source_contacts`
Hidden provider index with durable review/linked/ignored/blocked state. A source row becomes visible only after explicit Add/Link.

### `people_integrations`
Server-only OAuth/session rows for Google Contacts, Microsoft, VK and Facebook. Tokens stay server-side.
''')

ensure_section('docs/POCKETBASE_MANIFEST.md', '## People collections (2026-09-03)', '''
## People collections (2026-09-03)

Collections: `people`, `people_circles`, `people_source_contacts`, `people_integrations`.

- User-facing People collections are owner-scoped to `profiles.id`; `people_integrations` is server-only.
- External sync writes the hidden source index and never auto-creates visible People.
- Device contacts are imported only after explicit user action and OS permission.
- Google Contacts/Microsoft/VK/Facebook use server-owned integration routes under `/api/people-integrations/`.
- Telegram supports explicit export import; no fake bot/OAuth contact sync is presented.
''')

ensure_section('docs/UX_CONTRACT.md', '## People / source hygiene contract', '''
## People / source hygiene contract

- Entry point: Settings → Account → People; People is not a primary app tab.
- Sections: People, Circles, Sources.
- Person supports photo, email, phone, relationship, optional-year birthday, reminders, multiple Circles and notes.
- Sources are a hidden review index, never the visible People list.
- Explicit source actions: Add, Link, Ignore, Block. Ignore/Block survives later source syncs.
- Device contacts sync only after user action and OS permission; no startup address-book scan.
- Plan reminder reconciliation must not cancel People birthday reminders.
''')

normal_guard = '''name: Architecture Guard

on:
  pull_request:
    branches:
      - main
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: architecture-guard-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  strict-structure:
    name: strict-structure
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run strict architecture guard
        run: pwsh -NoProfile -NonInteractive -File ./scripts/audit/architecture_guard.ps1 -Strict

      - name: Check governing documentation parity
        run: python scripts/audit/documentation_parity.py

      - name: Check repository hygiene and structure growth
        env:
          STRUCTURE_GROWTH_BASE: ${{ github.event.pull_request.base.sha || github.event.before }}
        run: python scripts/audit/repository_hygiene.py

      - name: Check PocketBase schema parity
        run: python scripts/audit/pocketbase_schema_contract.py

      - name: Check deployment ordering contract
        run: python scripts/audit/deployment_contract.py

      - name: Check all PocketBase JavaScript syntax
        shell: bash
        run: |
          mapfile -d '' files < <(find pb_hooks pb_migrations -type f -name '*.js' -print0 | sort -z)
          if (( ${{#files[@]}} == 0 )); then
            echo 'No PocketBase JavaScript files found.' >&2
            exit 1
          fi
          for file in "${{files[@]}}"; do node --check "$file"; done

      - name: Check for whitespace errors
        run: |
          if [ "${{{{ github.event_name }}}}" = "pull_request" ]; then
            git diff --check "${{{{ github.event.pull_request.base.sha }}}}...HEAD"
          else
            git fetch --no-tags --prune origin main
            git diff --check "origin/main...HEAD"
          fi
'''
# Fix escaped shell/GitHub braces from Python literal.
normal_guard = normal_guard.replace('${{#files[@]}}', '${#files[@]}').replace('${{files[@]}}', '${files[@]}').replace('${{{{ github.event_name }}}}', '${{ github.event_name }}').replace('${{{{ github.event.pull_request.base.sha }}}}', '${{ github.event.pull_request.base.sha }}')
write('.github/workflows/architecture-guard.yml', normal_guard)

for rel in ['.github/workflows/people-main-sync.yml', 'scripts/manual/finalize_people_main.py']:
    target = ROOT / rel
    if target.exists():
        target.unlink()

subprocess.run(['python', 'scripts/manual/generate_app_structure_detailed.py'], cwd=ROOT, check=True)
