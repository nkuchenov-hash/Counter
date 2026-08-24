/// <reference path="../pb_data/types.d.ts" />

// Fail PocketBase hook loading early if the canonical Google Fit sleep runtime
// cannot be parsed/required.
require(__hooks + "/google_fit_sleep_runtime.js");

// Explicit user-requested Path deletion. This is deliberately independent from
// creation of any replacement Path: the obsolete root ETNIKA Path must be able
// to disappear even if later redesign bootstrap work fails.
function deleteRequestedEtnikaRootPath(app) {
  const categories = app.findRecordsByFilter(
    "categories",
    "is_archived = false",
    "id",
    0,
    0,
  )
  const roots = categories.filter(function (row) {
    return String(row.getString("name") || "").trim().toLocaleLowerCase() === "этника"
  })
  if (roots.length !== 1) {
    console.log("[ETNIKA_ROOT_PATH_DELETE] skipped: roots=" + String(roots.length))
    return
  }

  const root = roots[0]
  const owner = root.getString("user_id")
  if (!owner) {
    console.log("[ETNIKA_ROOT_PATH_DELETE] skipped: owner missing")
    return
  }

  const paths = app.findRecordsByFilter(
    "paths",
    "user_id = {:owner} && category_link = {:category}",
    "id",
    0,
    0,
    { owner: owner, category: root.id },
  )
  if (paths.length === 0) return

  let deleted = 0
  for (const path of paths) {
    const pathId = path.getString("path_id")
    app.delete(path)
    deleted++

    // Server-side cleanup may remove the now-orphaned immutable history for
    // this specifically requested obsolete Path. Normal client Path deletion
    // keeps revisions as audit history.
    if (pathId) {
      const revisions = app.findRecordsByFilter(
        "path_revisions",
        "user_id = {:owner} && path_id = {:path}",
        "id",
        0,
        0,
        { owner: owner, path: pathId },
      )
      for (const revision of revisions) app.delete(revision)
    }
  }
  console.log("[ETNIKA_ROOT_PATH_DELETE] deleted=" + String(deleted))
}

function runRequestedEtnikaRootPathDelete(app) {
  try {
    deleteRequestedEtnikaRootPath(app)
  } catch (error) {
    console.log("[ETNIKA_ROOT_PATH_DELETE] error: " + String(error))
  }
}

onBootstrap(function (event) {
  event.next()
  runRequestedEtnikaRootPathDelete(event.app)
})

cronAdd("lifeos_requested_etnika_root_path_delete", "* * * * *", function () {
  runRequestedEtnikaRootPathDelete($app)
})
