/// <reference path="../pb_data/types.d.ts" />

// One-time production correction for the ETNIKA homepage redesign Path.
// The Path is stored in PocketBase only; no Planner rows are created before
// explicit user approval. The correction is idempotent and becomes inert after
// the new child Path exists and the obsolete root ETNIKA Path is gone.
(function () {
  const ROOT_NAME = "этника"
  const CHILD_NAME = "Обновление основной страницы сайта"
  const PATH_ID = "etnika-homepage-redesign-hourly-20260824"
  const REVISION_ID = PATH_ID + "-v1"

  function norm(value) {
    return String(value || "").trim().toLocaleLowerCase()
  }

  function list(app, collection, filter, params) {
    return app.findRecordsByFilter(collection, filter || "", "id", 0, 0, params || {})
  }

  function deletePathAndRevisions(app, pathRow) {
    if (!pathRow) return
    const owner = pathRow.getString("user_id")
    const pathId = pathRow.getString("path_id")
    app.delete(pathRow)
    if (!owner || !pathId) return
    for (const rev of list(
      app,
      "path_revisions",
      "user_id = {:owner} && path_id = {:path}",
      { owner: owner, path: pathId },
    )) {
      app.delete(rev)
    }
  }

  function stage(id, title, done, actions) {
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

  function stages() {
    return [
      stage("h01", "Аудит текущей страницы: карта desktop и mobile", "Есть полный список всех текущих white-блоков, их роли и mobile-поведения.", [
        ["Перечислить все desktop-блоки сверху вниз", "Полная desktop-карта", 20, "analysis"],
        ["Сопоставить mobile-версию каждого блока", "Полная mobile-карта", 20, "analysis"],
        ["Для каждого блока записать функцию, сообщение и CTA", "У каждого блока понятна роль", 20, "analysis"],
      ]),
      stage("h02", "Scope, зависимости и безопасный rollback", "Зафиксировано, что сохраняем, какие интеграции нельзя сломать и как откатить изменения.", [
        ["Разметить блоки keep / rework / move / merge / remove", "Нет блока без решения", 20, "governance"],
        ["Зафиксировать forms, links, anchors, analytics, SEO и custom code", "Есть список технических зависимостей", 20, "analysis"],
        ["Зафиксировать scope и rollback baseline текущей Tilda-страницы", "Полный rebuild исключён, откат определён", 20, "governance"],
      ]),
      stage("h03", "Типографика: аудит и выбор шрифтов", "Выбран Tilda-совместимый font stack на основе проблем текущей страницы.", [
        ["Провести аудит текущих шрифтов, размеров, весов и line-height", "Список типографических проблем", 30, "design"],
        ["Выбрать и проверить финальный font stack", "Рабочая система шрифтов утверждена", 30, "design"],
      ]),
      stage("h04", "Типографика: шкалы, интервалы и интерактивные элементы", "Готовы desktop/mobile type scale, line-height, text width, spacing rhythm и правила CTA.", [
        ["Задать desktop и mobile type scale", "H1/H2/H3/body/caption определены", 20, "design"],
        ["Задать line-height, max text width и вертикальный rhythm", "Правила читаемости определены", 20, "design"],
        ["Задать типографику кнопок, ссылок и подписей и проверить на реальном блоке", "Система откалибрована", 20, "design"],
      ]),
      stage("h05", "Сообщение страницы и минимальная перестройка структуры", "Есть first-screen message, основной CTA и окончательный порядок существующих блоков.", [
        ["Сформулировать, что посетитель должен понять за первые 5–10 секунд", "Hero-message определён", 20, "content"],
        ["Определить основной CTA и найти дубли/провалы текущего сценария", "Главное действие и проблемы ясны", 20, "analysis"],
        ["Зафиксировать минимальные move/merge/split и финальный порядок блоков", "Есть новая карта страницы", 20, "design"],
      ]),
      stage("h06", "Redesign-spec: header и hero", "Header и первый экран полностью описаны до реализации на desktop и mobile.", [
        ["Спроектировать header/navigation на базе текущего блока", "Header-spec готов", 30, "design"],
        ["Спроектировать hero: композиция, текст, CTA и visual hierarchy", "Hero-spec готов", 30, "design"],
      ]),
      stage("h07", "Redesign-spec: первая половина основных white-блоков", "Первая половина смысловых блоков имеет отдельное решение по композиции и типографике.", [
        ["Разобрать и переработать первую группу блоков по audit map", "Первая группа имеет redesign-spec", 30, "design"],
        ["Проверить переходы, CTA и визуальный rhythm первой группы", "Первая группа собрана в связный сценарий", 30, "design"],
      ]),
      stage("h08", "Redesign-spec: вторая половина и trust/proof блоки", "Оставшиеся смысловые и доказательные блоки имеют отдельные redesign-решения.", [
        ["Разобрать и переработать вторую группу блоков по audit map", "Вторая группа имеет redesign-spec", 30, "design"],
        ["Довести benefits/cases/trust/proof до единой системы", "Доказательная часть страницы согласована", 30, "design"],
      ]),
      stage("h09", "Redesign-spec: CTA, формы, контакты и footer", "Все конверсионные и завершающие блоки спроектированы без потери текущих отправок и ссылок.", [
        ["Спроектировать CTA/contact/footer в новой системе", "Конец страницы согласован", 20, "design"],
        ["Переработать формы визуально без изменения рабочих направлений отправки", "Form-spec готов", 20, "design"],
        ["Сверить spec со всей audit map и закрыть пропущенные блоки", "Слепых зон нет", 20, "quality"],
      ]),
      stage("h10", "Tilda desktop: header, hero и новая типографика", "Первый экран desktop реализован в существующей Tilda-странице и использует новую систему.", [
        ["Переработать header/navigation в рабочей копии Tilda", "Header реализован", 30, "implementation"],
        ["Переработать hero и применить новую типографику", "Hero реализован", 30, "implementation"],
      ]),
      stage("h11", "Tilda desktop: первая половина white-блоков", "Первая половина страницы реализована по согласованным specs.", [
        ["Переделать первую часть white-блоков", "Первая часть реализована", 30, "implementation"],
        ["Довести контейнеры, сетку и вертикальный rhythm первой части", "Композиция первой части цельная", 30, "implementation"],
      ]),
      stage("h12", "Tilda desktop: вторая половина white-блоков", "Вторая половина страницы реализована по согласованным specs.", [
        ["Переделать вторую часть white-блоков", "Вторая часть реализована", 30, "implementation"],
        ["Довести trust/proof/CTA/footer блоки", "Конец страницы реализован", 30, "implementation"],
      ]),
      stage("h13", "Desktop consistency и сохранение интеграций", "Desktop выглядит как одна система, а все интерактивные элементы продолжают работать.", [
        ["Убрать остатки старых шрифтов, случайных размеров и интервалов", "Desktop consistency закрыт", 20, "quality"],
        ["Проверить buttons, links, anchors и формы", "Интерактивные элементы работают", 20, "quality"],
        ["Проверить analytics/custom code/SEO-зависимости после перестройки", "Технические зависимости сохранены", 20, "quality"],
      ]),
      stage("h14", "Mobile: header, hero и первая половина страницы", "Первый экран и первая половина имеют намеренную mobile-композицию, а не уменьшенный desktop.", [
        ["Адаптировать header и hero", "Mobile first screen готов", 20, "implementation"],
        ["Адаптировать первую половину изменённых блоков", "Первая половина mobile готова", 20, "implementation"],
        ["Проверить mobile type scale, spacing и tap targets первой части", "Первая часть удобна на телефоне", 20, "quality"],
      ]),
      stage("h15", "Mobile: вторая половина, формы и breakpoints", "Вся mobile-страница устойчива на разных ширинах и без overflow/keyboard проблем.", [
        ["Адаптировать вторую половину и footer", "Вторая половина mobile готова", 20, "implementation"],
        ["Проверить forms/CTA/keyboard/overflow", "Мобильные формы и CTA работают", 20, "quality"],
        ["Проверить несколько ширин и breakpoint-переходы", "Layout устойчив", 20, "quality"],
      ]),
      stage("h16", "Контент, media, performance и accessibility polish", "Тексты и изображения финализированы, тяжёлые assets устранены, базовая доступность проверена.", [
        ["Сделать финальный copy pass и убрать дубли/лишний текст", "Copy финализирован", 20, "content"],
        ["Оптимизировать изображения/media и проверить loading", "Нет неоправданно тяжёлых assets", 20, "performance"],
        ["Проверить contrast, alt/labels, keyboard/focus и читаемость", "Базовая accessibility закрыта", 20, "quality"],
      ]),
      stage("h17", "Финальный QA, публикация и live-проверка", "Production-страница опубликована, P0/P1 дефекты закрыты, формы/ссылки/analytics/SEO проверены после публикации.", [
        ["Провести desktop/tablet/mobile QA и закрыть P0/P1", "Release candidate готов", 20, "quality"],
        ["Опубликовать обновлённую страницу в Tilda", "Новая версия live", 20, "release"],
        ["Сделать live smoke test: forms/links/analytics/SEO/основные ширины", "Production проверен", 20, "release"],
      ]),
    ]
  }

  function apply(app) {
    const categoryCollection = app.findCollectionByNameOrId("categories")
    const revisionCollection = app.findCollectionByNameOrId("path_revisions")
    const pathCollection = app.findCollectionByNameOrId("paths")

    const activeCategories = list(app, "categories", "is_archived = false")
    const roots = activeCategories.filter(function (row) {
      return norm(row.getString("name")) === ROOT_NAME
    })
    if (roots.length !== 1) {
      throw new Error("expected exactly one active ETNIKA category, got " + String(roots.length))
    }

    const root = roots[0]
    const owner = root.getString("user_id")
    if (!owner) throw new Error("ETNIKA owner is empty")
    app.findRecordById("profiles", owner)

    const rootPaths = list(
      app,
      "paths",
      "user_id = {:owner} && category_link = {:category}",
      { owner: owner, category: root.id },
    )

    const childCandidates = list(
      app,
      "categories",
      "user_id = {:owner} && parent_id = {:parent}",
      { owner: owner, parent: root.id },
    ).filter(function (row) {
      return norm(row.getString("name")) === norm(CHILD_NAME)
    })
    if (childCandidates.length > 1) {
      throw new Error("multiple ETNIKA homepage child categories")
    }

    let child = childCandidates.length === 1 ? childCandidates[0] : null
    const marker = list(
      app,
      "path_revisions",
      "user_id = {:owner} && path_id = {:path} && revision_id = {:revision}",
      { owner: owner, path: PATH_ID, revision: REVISION_ID },
    )
    const childPathsNow = child
      ? list(
          app,
          "paths",
          "user_id = {:owner} && category_link = {:category} && archived = false",
          { owner: owner, category: child.id },
        )
      : []

    // Once the successful server correction exists, become permanently inert.
    // Later manual Path revisions must never be overwritten by this hook.
    if (marker.length === 1 && childPathsNow.length === 1 && rootPaths.length === 0) {
      return
    }

    // Remove only the premature week Plans produced by the discarded draft.
    for (let d = 25; d <= 31; d++) {
      const planId = "etnika-homepage-redesign-2026-08-" + String(d).padStart(2, "0")
      for (const plan of list(
        app,
        "plans",
        "user_id = {:owner} && plan_id = {:plan}",
        { owner: owner, plan: planId },
      )) {
        app.delete(plan)
      }
    }

    if (!child) {
      const suffix = $security.randomStringWithAlphabet(8, "0123456789abcdefghijklmnopqrstuvwxyz")
      const businessId = "etnika_home_" + suffix
      const siblings = list(
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
      child.set("name", CHILD_NAME)
      child.set("parent_id", root.id)
      child.set("order", nextOrder)
      child.set("is_archived", false)
      const color = root.getInt("color_value")
      const icon = root.getInt("icon_code_point")
      if (color) child.set("color_value", color)
      if (icon) child.set("icon_code_point", icon)
      app.save(child)
    } else if (child.getBool("is_archived")) {
      child.set("is_archived", false)
      app.save(child)
    }

    // Replace every Path attached to the child because this candidate has not
    // yet been approved by the user and must exactly match the reviewed draft.
    for (const oldChildPath of list(
      app,
      "paths",
      "user_id = {:owner} && category_link = {:category}",
      { owner: owner, category: child.id },
    )) {
      deletePathAndRevisions(app, oldChildPath)
    }
    for (const orphan of list(
      app,
      "path_revisions",
      "user_id = {:owner} && path_id = {:path}",
      { owner: owner, path: PATH_ID },
    )) {
      app.delete(orphan)
    }

    const revision = new Record(revisionCollection)
    revision.set("user_id", owner)
    revision.set("path_id", PATH_ID)
    revision.set("revision_id", REVISION_ID)
    revision.set("version", 1)
    revision.set("lifecycle", "published")
    revision.set(
      "goal",
      "Переработать существующую главную страницу ЭТНИКА в Tilda без полного пересоздания сайта: сохранить текущую основу и рабочие интеграции, обновить типографику и композицию, последовательно переделать каждый white-блок, адаптировать desktop/mobile, провести QA и опубликовать обновлённую production-страницу.",
    )
    revision.set("content", { stages: stages() })
    revision.set("source", "system")
    revision.set("parent_revision_id", "")
    app.save(revision)

    const path = new Record(pathCollection)
    path.set("user_id", owner)
    path.set("path_id", PATH_ID)
    path.set("category_link", child.id)
    path.set("active_revision_link", revision.id)
    path.set("archived", false)
    app.save(path)

    // Only after the replacement Path is durable do we remove the obsolete
    // root ETNIKA Path and all of its immutable revision history.
    for (const oldRootPath of rootPaths) {
      deletePathAndRevisions(app, oldRootPath)
    }
  }

  function run(app) {
    try {
      apply(app)
      console.log("[ETNIKA_HOMEPAGE_PATH_ONCE] ok")
    } catch (error) {
      console.log("[ETNIKA_HOMEPAGE_PATH_ONCE] error: " + String(error))
    }
  }

  onBootstrap(function (event) {
    event.next()
    run(event.app)
  })

  cronAdd("lifeos_etnika_homepage_path_once", "* * * * *", function () {
    run($app)
  })
})()
