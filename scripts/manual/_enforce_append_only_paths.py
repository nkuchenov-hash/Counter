#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path: str, body: str) -> None:
    (ROOT / path).write_text(body.rstrip() + "\n", encoding="utf-8", newline="\n")


migration_path = "pb_migrations/1787076000_durable_paths.js"
migration = read(migration_path)
old = '      updateRule: null,\n      deleteRule: "user_id = @request.auth.id",'
new = '      updateRule: null,\n      deleteRule: null,'
if old not in migration:
    raise SystemExit("path_revisions update/delete rule anchor missing")
migration = migration.replace(old, new, 1)
write(migration_path, migration)

service_path = "lib/data/paths/path_service.dart"
service = read(service_path)
delete_method = """

  Future<void> deleteOwnedPathRevision(String revisionRecordId) async {
    await ensurePocketBaseReady();
    _pathOwnerIdOrThrow();
    final id = revisionRecordId.trim();
    if (id.isEmpty) return;
    await _pb.collection(PbCollections.pathRevisions).delete(id);
  }
"""
if delete_method not in service:
    raise SystemExit("deleteOwnedPathRevision anchor missing")
service = service.replace(delete_method, "")
write(service_path, service)

repo_path = "lib/data/paths/path_repository.dart"
repo = read(repo_path)
cleanup_block = """    } catch (_) {
      final revisionRecordId = (revision?['id'] ?? '').toString().trim();
      if (revisionRecordId.isNotEmpty) {
        try {
          await _database.deleteOwnedPathRevision(revisionRecordId);
        } catch (_) {
          // Orphan revisions are not executable because no Path points to them.
        }
      }
      return null;
    }
"""
if cleanup_block not in repo:
    raise SystemExit("createPath revision cleanup anchor missing")
repo = repo.replace(
    cleanup_block,
    """    } catch (_) {
      // Revisions are immutable audit history. An unreferenced revision is
      // non-executable because only `paths.active_revision_link` activates it.
      return null;
    }
""",
    1,
)
cleanup_block_2 = """    } catch (_) {
      final revisionRecordId = (revision?['id'] ?? '').toString().trim();
      if (revisionRecordId.isNotEmpty) {
        try {
          await _database.deleteOwnedPathRevision(revisionRecordId);
        } catch (_) {
          // Safe to leave: only the relation in `paths` grants active status.
        }
      }
      return null;
    }
"""
if cleanup_block_2 not in repo:
    raise SystemExit("saveActivePath revision cleanup anchor missing")
repo = repo.replace(
    cleanup_block_2,
    """    } catch (_) {
      // Failed pointer switches leave immutable, unreferenced audit revisions.
      // They cannot execute because the Path relation still points elsewhere.
      return null;
    }
""",
    1,
)
write(repo_path, repo)

manifest_path = "docs/POCKETBASE_MANIFEST.md"
manifest = read(manifest_path)
manifest = manifest.replace(
    "**Immutability:** client API has no update rule for `path_revisions`. Edit = create next revision, then switch `paths.active_revision_link`. If pointer update fails, the unreferenced revision is non-executable and may be deleted safely.",
    "**Immutability:** client API has neither update nor delete rules for `path_revisions`. Edit = create next revision, then switch `paths.active_revision_link`. If pointer update fails, the unreferenced revision remains immutable audit history and is non-executable.",
)
manifest = manifest.replace(
    "- `path_revisions` are immutable through client update rules.",
    "- `path_revisions` are append-only through the client API: update and delete are both closed.",
)
write(manifest_path, manifest)

print("append_only_paths: applied")
