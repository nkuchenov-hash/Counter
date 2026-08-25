/// <reference path="../pb_data/types.d.ts" />

// One-time ETNIKA Path correction. Functions deliberately live at top level:
// PocketBase callbacks execute after hook-file evaluation, so callback targets
// must not be trapped inside a local IIFE scope.

function etnikaHomepageList(app, collection, filter, params) {
  return app.findRecordsByFilter(collection, filter || "", "id", 0, 0, params || {})
}

function etnikaHomepageStage(id, title, done, actions) {
  return {
    type: "stage",
    id: id,
    text: title,
    definitionOfDone: done,
    isDone: false,
    actions: actions.map(function (a, index) {
      return {
        id: id + "-a" + String(index + 1),
        text: a[0],
        result: a[1],
        minutes: a[2],
        track: a[3],
        isDone: false,
      }
    }),
  }
}

function etnikaHomepageStages() {
  return [
    etnikaHomepageStage("h01", "Аудит текущей страницы: карта desktop и mobile", "Есть полный список всех текущих white-блоков, их роли и mobile-поведения.", [
      ["Перечислить все desktop-блоки сверху вниз", "Полная desktop-карта", 20, "analysis"],
      ["Сопоставить mobile-версию каждого блока", "Полная mobile-карта", 20, "analysis"],
      ["Для каждого блока записать функцию, сообщение и CTA", "У каждого блока понятна роль", 20, "analysis"],
    ]),
    etnikaHomepageStage("h02", "Scope, зависимости и безопасный rollback", "Зафиксировано, что сохраняем, какие интеграции нельзя сломать и как откатить изменения.", [
      ["Разметить блоки keep / rework / move / merge / remove", "Нет блока без решения", 20, "governance"],
      ["Зафиксировать forms, links, anchors, analytics, SEO и custom code", "Есть список технических зависимостей", 20, "analysis"],
      ["Зафиксировать scope и rollback baseline текущей Tilda-страницы", "Полный rebuild исключён, откат определён", 20, "governance"],
    ]),
    etnikaHomepageStage("h03", "Типографика: аудит и выбор шрифтов", "Выбран Tilda-совместимый font stack на основе проблем текущей страницы.", [
      ["Провести аудит текущих шрифтов, размеров, весов и line-height", "Список типографических проблем", 30, "design"],
      ["Выбрать и проверить финальный font stack", "Рабочая система шрифтов утверждена", 30, "design"],
    ]),
    etnikaHomepageStage("h04", "Типографика: шкалы, интервалы и интерактивные элементы", "Готовы desktop/mobile type scale, line-height, text width, spacing rhythm и правила CTA.", [
      ["Задать desktop и mobile type scale", "H1/H2/H3/body/caption определены", 20, "design"],
      ["Задать line-height, max text width и вертикальный rhythm", "Правила читаемости определены", 20, "design"],
      ["Задать типографику кнопок, ссылок и подписей и проверить на реальном блоке", "Система откалибрована", 20, "design"],
    ]),
    etnikaHomepageStage("h05", "Сообщение страницы и минимальная перестройка структуры", "Есть first-screen message, основной CTA и окончательный порядок существующих блоков.", [
      ["Сформулировать, что посетитель должен понять за первые 5–10 секунд", "Hero-message определён", 20, "content"],
      ["Определить основной CTA и найти дубли/провалы текущего сценария", "Главное действие и проблемы ясны", 20, "analysis"],
      ["Зафиксировать минимальные move/merge/split и финальный порядок блоков", "Есть новая карта страницы", 20, "design"],
    ]),
    etnikaHomepageStage("h06", "Redesign-spec: header и hero", "Header и первый экран полностью описаны до реализации на desktop и mobile.", [
      ["Спроектировать header/navigation на базе текущего блока", "Header-spec готов", 30, "design"],
      ["Спроектировать hero: композиция, текст, CTA и visual hierarchy", "Hero-spec готов", 30, "design"],
    ]),
    etnikaHomepageStage("h07", "Redesign-spec: первая половина основных white-блоков", "Первая половина смысловых блоков имеет отдельное решение по композиции и типографике.", [
      ["Разобрать и переработать первую группу блоков по audit map", "Первая группа имеет redesign-spec", 30, "design"],
      ["Проверить переходы, CTA и визуальный rhythm первой группы", "Первая группа собрана в связный сценарий", 30, "design"],
    ]),
    etnikaHomepageStage("h08", "Redesign-spec: вторая половина и trust/proof блоки", "Оставшиеся смысловые и доказательные блоки имеют отдельные redesign-решения.", [
      ["Разобрать и переработать вторую группу блоков по audit map", "Вторая группа имеет redesign-spec", 30, "design"],
      ["Довести benefits/cases/trust/proof до единой системы", "Доказательная часть страницы согласована", 30, "design"],
    ]),
    etnikaHomepageStage("h09", "Redesign-spec: CTA, формы, контакты и footer", "Все конверсионные и завершающие блоки спроектированы без потери текущих отправок и ссылок.", [
      ["Спроектировать CTA/contact/footer в новой системе", "Конец страницы согласован", 20, "design"],
      ["Переработать формы визуально без изменения рабочих направлений отправки", "Form-spec готов", 20, "design"],
      ["Сверить spec со всей audit map и закрыть пропущенные блоки", "Слепых зон нет", 20, "quality"],
    ]),
    etnikaHomepageStage("h10", "Tilda desktop: header, hero и новая типографика", "Первый экран desktop реализован в существующей Tilda-странице и использует новую систему.", [
      ["Переработать header/navigation в рабочей копии Tilda", "Header реализован", 30, "implementation"],
      ["Переработать hero и применить новую типографику", "Hero реализован", 30, "implementation"],
    ]),
    etnikaHomepageStage("h11", "Tilda desktop: первая половина white-блоков", "Первая половина страницы реализована по согласованным specs.", [
      ["Переделать первую часть white-блоков", "Первая часть реализована", 30, "implementation"],
      ["Довести контейнеры, сетку и вертикальный rhythm первой части", "Композиция первой части цельная", 30, "implementation"],
    ]),
    etnikaHomepageStage("h12", "Tilda desktop: вторая половина white-блоков", "Вторая половина страницы реализована по согласованным specs.", [
      ["Переделать вторую часть white-блоков", "Вторая часть реализована", 30, "implementation"],
      ["Довести trust/proof/CTA/footer блоки", "Конец страницы реализован", 30, "implementation"],
    ]),
    etnikaHomepageStage("h13", "Desktop consistency и сохранение интеграций", "Desktop выглядит как одна система, а все интерактивные элементы продолжают работать.", [
      ["Убрать остатки старых шрифтов, случайных размеров и интервалов", "Desktop consistency закрыт", 20, "quality"],
      ["Проверить buttons, links, anchors и формы", "Интерактивные элементы работают", 20, "quality"],
      ["Проверить analytics/custom code/SEO-зависимости после перестройки", "Технические зависимости сохранены", 20, "quality"],
    ]),
    etnikaHomepageStage("h14", "Mobile: header, hero и первая половина страницы", "Первый экран и первая половина имеют намеренную mobile-композицию, а не уменьшенный desktop.", [
      ["Адаптировать header и hero", "Mobile first screen готов", 20, "implementation"],
      ["Адаптировать первую половину изменённых блоков", "Первая половина mobile готова", 20, "implementation"],
      ["Проверить mobile type scale, spacing и tap targets первой части", "Первая часть удобна на телефоне", 20, "quality"],
    ]),
    etnikaHomepageStage("h15", "Mobile: вторая половина, формы и breakpoints", "Вся mobile-страница устойчива на разных ширинах и без overflow/keyboard проблем.", [
      ["Адаптировать вторую половину и footer", "Вторая половина mobile готова", 20, "implementation"],
      ["Проверить forms/CTA/keyboard/overflow", "Мобильные формы и CTA работают", 20, "quality"],
      ["Проверить несколько ширин и breakpoint-переходы", "Layout устойчив", 20, "quality"],
    ]),
    etnikaHomepageStage("h16", "Контент, media, performance и accessibility polish", "Тексты и изображения финализированы, тяжёлые assets устранены, базовая доступность проверена.", [
      ["Сделать финальный copy pass и убрать дубли/лишний текст", "Copy финализирован", 20, "content"],
      ["Оптимизировать изображения/media и проверить loading", "Нет неоправданно тяжёлых assets", 20, "performance"],
      ["Проверить contrast, alt/labels, keyboard/focus и читаемость", "Базовая accessibility закрыта", 20, "quality"],
    ]),
    etnikaHomepageStage("h17", "Финальный QA, публикация и live-проверка", "Production-страница опубликована, P0/P1 дефекты закрыты, формы/ссылки/analytics/SEO проверены после публикации.", [
      ["Провести desktop/tablet/mobile QA и закрыть P0/P1", "Release candidate готов", 20, "quality"],
      ["Опубликовать обновлённую страницу в Tilda", "Новая версия live", 20, "release"],
      ["Сделать live smoke test: forms/links/analytics/SEO/основные ширины", "Production проверен", 20, "release"],
    ]),
  ]
}

function etnikaHomepageRoot(app) {
  const roots = etnikaHomepageList(
    app,
    "categories",
    "name = {:name} && is_archived = false",
    { name: "ЭТНИКА" },
  )
  if (roots.length !== 1) {
    throw new Error("expected exactly one active ETNIKA category, got " + String(roots.length))
  }
  const root = roots[0]
  const owner = root.getString("user_id")
  if (!owner) throw new Error("ETNIKA owner is empty")
  return { root: root, owner: owner }
}

function etnikaHomepageDeleteObsolete(app) {
  const info = etnikaHomepageRoot(app)
  const root = info.root
  const owner = info.owner

  // Path deletion is independent of replacement creation. Retain immutable
  // revisions as audit history; without a paths row they are non-executable.
  const rootPaths = etnikaHomepageList(
    app,
    "paths",
    "user_id = {:owner} && category_link = {:category}",
    { owner: owner, category: root.id },
  )
  for (const path of rootPaths) app.delete(path)

  // Remove only the premature week Plans from the discarded draft.
  for (let day = 25; day <= 31; day++) {
    const planId = "etnika-homepage-redesign-2026-08-" + String(day).padStart(2, "0")
    const rows = etnikaHomepageList(
      app,
      "plans",
      "user_id = {:owner} && plan_id = {:plan}",
      { owner: owner, plan: planId },
    )
    for (const row of rows) app.delete(row)
  }
}

function etnikaHomepageEnsureChild(app, root, owner) {
  const childName = "Обновление основной страницы сайта"
  const businessId = "etnika_homepage_update_20260825"
  const categoryCollection = app.findCollectionByNameOrId("categories")

  // Reuse the named category even if a previous failed attempt left it under a
  // wrong parent. The result must be exactly ETNIKA -> homepage update.
  let candidates = etnikaHomepageList(
    app,
    "categories",
    "user_id = {:owner} && name = {:name}",
    { owner: owner, name: childName },
  )
  if (candidates.length > 1) {
    throw new Error("multiple ETNIKA homepage categories named " + childName)
  }

  let child = candidates.length === 1 ? candidates[0] : null
  if (!child) {
    const byBusinessId = etnikaHomepageList(
      app,
      "categories",
      "user_id = {:owner} && category_id = {:category}",
      { owner: owner, category: businessId },
    )
    if (byBusinessId.length > 1) throw new Error("duplicate ETNIKA homepage business id")
    if (byBusinessId.length === 1) child = byBusinessId[0]
  }

  if (!child) {
    const siblings = etnikaHomepageList(
      app,
      "categories",
      "user_id = {:owner} && parent_id = {:parent}",
      { owner: owner, parent: root.id },
    )
    let nextOrder = 0
    for (const sibling of siblings) {
      nextOrder = Math.max(nextOrder, sibling.getInt("order") + 1)
    }

    child = new Record(categoryCollection)
    child.set("user_id", owner)
    child.set("category_id", businessId)
    child.set("normalized_id", businessId)
    child.set("name", childName)
    child.set("parent_id", root.id)
    child.set("order", nextOrder)
    child.set("is_archived", false)
    const color = root.getInt("color_value")
    const icon = root.getInt("icon_code_point")
    if (color) child.set("color_value", color)
    if (icon) child.set("icon_code_point", icon)
    app.save(child)
    return child
  }

  let changed = false
  if (child.getString("name") !== childName) {
    child.set("name", childName)
    changed = true
  }
  if (child.getString("parent_id") !== root.id) {
    child.set("parent_id", root.id)
    changed = true
  }
  if (child.getBool("is_archived")) {
    child.set("is_archived", false)
    changed = true
  }
  if (!child.getString("category_id")) {
    child.set("category_id", businessId)
    changed = true
  }
  if (!child.getString("normalized_id")) {
    child.set("normalized_id", child.getString("category_id") || businessId)
    changed = true
  }
  if (changed) app.save(child)
  return child
}

function etnikaHomepageCreateReviewedPath(app) {
  const info = etnikaHomepageRoot(app)
  const root = info.root
  const owner = info.owner
  const pathId = "etnika-homepage-redesign-hourly-20260824"
  const revisionId = pathId + "-v1"

  const child = etnikaHomepageEnsureChild(app, root, owner)

  // If the reviewed Path already exists, become inert forever. Later manual
  // revisions belong to the user and must never be overwritten by this hook.
  const existingTarget = etnikaHomepageList(
    app,
    "paths",
    "user_id = {:owner} && path_id = {:path}",
    { owner: owner, path: pathId },
  )
  if (existingTarget.length === 1) return
  if (existingTarget.length > 1) throw new Error("duplicate reviewed ETNIKA Path ids")

  // Remove any other unapproved Path attached to this specific child category.
  const childPaths = etnikaHomepageList(
    app,
    "paths",
    "user_id = {:owner} && category_link = {:category}",
    { owner: owner, category: child.id },
  )
  for (const path of childPaths) app.delete(path)

  // Clean only stale revisions from prior failed attempts of this exact Path id.
  const staleRevisions = etnikaHomepageList(
    app,
    "path_revisions",
    "user_id = {:owner} && path_id = {:path}",
    { owner: owner, path: pathId },
  )
  for (const revision of staleRevisions) app.delete(revision)

  const revisionCollection = app.findCollectionByNameOrId("path_revisions")
  const pathCollection = app.findCollectionByNameOrId("paths")

  const revision = new Record(revisionCollection)
  revision.set("user_id", owner)
  revision.set("path_id", pathId)
  revision.set("revision_id", revisionId)
  revision.set("version", 1)
  revision.set("lifecycle", "published")
  revision.set(
    "goal",
    "Переработать существующую главную страницу ЭТНИКА в Tilda без полного пересоздания сайта: сохранить текущую основу и рабочие интеграции, обновить типографику и композицию, последовательно переделать каждый white-блок, адаптировать desktop/mobile, провести QA и опубликовать обновлённую production-страницу.",
  )
  revision.set("content", { stages: etnikaHomepageStages() })
  revision.set("source", "system")
  revision.set("parent_revision_id", "")
  app.save(revision)

  const path = new Record(pathCollection)
  path.set("user_id", owner)
  path.set("path_id", pathId)
  path.set("category_link", child.id)
  path.set("active_revision_link", revision.id)
  path.set("archived", false)
  app.save(path)
}

function etnikaHomepageRun(app) {
  try {
    etnikaHomepageDeleteObsolete(app)
    console.log("[ETNIKA_HOMEPAGE_PATH_ONCE] delete_ok")
  } catch (error) {
    console.log("[ETNIKA_HOMEPAGE_PATH_ONCE] delete_error: " + String(error))
  }

  try {
    etnikaHomepageCreateReviewedPath(app)
    console.log("[ETNIKA_HOMEPAGE_PATH_ONCE] ok")
  } catch (error) {
    console.log("[ETNIKA_HOMEPAGE_PATH_ONCE] create_error: " + String(error))
  }
}

onBootstrap(function (event) {
  event.next()
  etnikaHomepageRun(event.app)
})

cronAdd("lifeos_etnika_homepage_path_once_v2", "* * * * *", function () {
  etnikaHomepageRun($app)
})
