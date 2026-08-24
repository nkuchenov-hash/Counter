/// <reference path="../pb_data/types.d.ts" />

// One-time data correction for the ETNIKA homepage redesign Path.
// It deliberately creates/updates the Path only. Planning rows are not created
// until the user reviews and explicitly approves the Path structure.
function applyEtnikaHomepageHourlyPathOnce(app) {
  const categories = app.findCollectionByNameOrId("categories")
  const profiles = app.findCollectionByNameOrId("profiles")
  const plans = app.findCollectionByNameOrId("plans")
  const paths = app.findCollectionByNameOrId("paths")
  const revisions = app.findCollectionByNameOrId("path_revisions")

  const norm = (v) => String(v || "").trim().toLocaleLowerCase()
  const allCategories = app.findRecordsByFilter(categories, "", "id", 0, 0)
  const etnikaCandidates = allCategories.filter((r) =>
    norm(r.getString("name")) === "этника" && !r.getBool("is_archived")
  )
  const pathsFor = (categoryId) => app.findRecordsByFilter(
    paths,
    "category_link = {:category}",
    "id",
    0,
    0,
    { category: categoryId },
  )
  const withPaths = etnikaCandidates.filter((r) => pathsFor(r.id).length > 0)
  let etnika = null
  if (withPaths.length === 1) etnika = withPaths[0]
  else if (withPaths.length === 0 && etnikaCandidates.length === 1) etnika = etnikaCandidates[0]
  else return

  const ownerId = etnika.getString("user_id")
  if (!ownerId) return
  try { app.findRecordById(profiles, ownerId) } catch (_) { return }

  const childName = "Обновление основной страницы сайта"
  const pathId = "etnika-homepage-redesign-20260824"
  const desiredRevisionId = `${pathId}-hour-blocks-v1`

  // Idempotency marker. Once this exact reviewed-candidate revision exists, the
  // hook never overwrites later manual revisions and never touches future Plans.
  const existingDesired = app.findRecordsByFilter(
    revisions,
    "user_id = {:owner} && path_id = {:path} && revision_id = {:revision}",
    "id",
    1,
    0,
    { owner: ownerId, path: pathId, revision: desiredRevisionId },
  )
  if (existingDesired.length > 0) return

  // Remove only the premature week Plans created by the previous draft. These
  // identifiers are unique to that draft and must not exist before approval.
  for (let d = 25; d <= 31; d++) {
    const planId = `etnika-homepage-redesign-2026-08-${String(d).padStart(2, "0")}`
    for (const row of app.findRecordsByFilter(
      plans,
      "user_id = {:owner} && plan_id = {:plan}",
      "id",
      0,
      0,
      { owner: ownerId, plan: planId },
    )) app.delete(row)
  }

  const childMatches = allCategories.filter((r) =>
    r.getString("user_id") === ownerId &&
    r.getString("parent_id") === etnika.id &&
    norm(r.getString("name")) === norm(childName)
  )
  if (childMatches.length > 1) return

  let child = childMatches.length === 1 ? childMatches[0] : null
  if (child == null) {
    const used = new Set(allCategories.map((r) => r.getString("category_id")).filter(Boolean))
    let businessId = "etnika_homepage_redesign_20260824"
    let suffix = 2
    while (used.has(businessId)) businessId = `etnika_homepage_redesign_20260824_${suffix++}`
    const siblings = allCategories.filter((r) =>
      r.getString("user_id") === ownerId && r.getString("parent_id") === etnika.id
    )
    let nextOrder = 0
    for (const sibling of siblings) {
      const n = Number(sibling.getRaw("order"))
      if (Number.isFinite(n)) nextOrder = Math.max(nextOrder, Math.trunc(n) + 1)
    }
    child = new Record(categories)
    child.set("user_id", ownerId)
    child.set("category_id", businessId)
    child.set("name", childName)
    child.set("normalized_id", businessId)
    child.set("parent_id", etnika.id)
    child.set("order", nextOrder)
    child.set("is_archived", false)
    const color = Number(etnika.getRaw("color_value"))
    const icon = Number(etnika.getRaw("icon_code_point"))
    if (Number.isFinite(color) && color) child.set("color_value", Math.trunc(color))
    if (Number.isFinite(icon) && icon) child.set("icon_code_point", Math.trunc(icon))
    app.save(child)
  } else if (child.getBool("is_archived")) {
    child.set("is_archived", false)
    app.save(child)
  }

  // The old root ETNIKA Path is not the project Path anymore. Keep the project
  // represented by the dedicated child category only.
  for (const oldPath of pathsFor(etnika.id).filter((r) => r.getString("user_id") === ownerId)) {
    const oldId = oldPath.getString("path_id")
    app.delete(oldPath)
    if (!oldId) continue
    for (const rev of app.findRecordsByFilter(
      revisions,
      "user_id = {:owner} && path_id = {:path}",
      "id",
      0,
      0,
      { owner: ownerId, path: oldId },
    )) app.delete(rev)
  }

  let pathRows = pathsFor(child.id).filter((r) => r.getString("user_id") === ownerId)
  let path = pathRows.find((r) => r.getString("path_id") === pathId) || null
  for (const other of pathRows) {
    if (path != null && other.id === path.id) continue
    const oldId = other.getString("path_id")
    app.delete(other)
    if (!oldId) continue
    for (const rev of app.findRecordsByFilter(
      revisions,
      "user_id = {:owner} && path_id = {:path}",
      "id",
      0,
      0,
      { owner: ownerId, path: oldId },
    )) app.delete(rev)
  }

  const goal = "Переработать существующую главную страницу ЭТНИКА в Tilda без полного пересоздания сайта: сохранить текущую основу и рабочие интеграции, обновить типографику и композицию, последовательно переделать каждый white-блок, адаптировать desktop/mobile, провести QA и опубликовать обновлённую production-страницу."

  const makeStage = (id, text, definitionOfDone, actions) => ({
    type: "stage",
    id,
    text,
    definitionOfDone,
    isDone: false,
    actions: actions.map((a, index) => ({
      id: `${id}-a${index + 1}`,
      text: a[0],
      result: a[1],
      minutes: a[2],
      track: a[3],
      isDone: false,
    })),
  })

  // Every stage is exactly one focused 60-minute work block. Individual
  // actions stay within the Path execution contract (1..30 minutes).
  const stages = [
    makeStage("h01", "Аудит текущей страницы: карта desktop и mobile", "Есть полный нумерованный список всех текущих white-блоков и их mobile-поведения.", [
      ["Перечислить все desktop-блоки сверху вниз", "Полная desktop-карта", 20, "analysis"],
      ["Сопоставить mobile-версию каждого блока", "Полная mobile-карта", 20, "analysis"],
      ["Для каждого блока записать функцию, сообщение и CTA", "У каждого блока понятна роль", 20, "analysis"],
    ]),
    makeStage("h02", "Scope, зависимости и безопасный rollback", "Зафиксировано, что сохраняем, какие интеграции нельзя сломать и как откатить изменения.", [
      ["Разметить блоки keep / rework / move / merge / remove", "Нет блока без решения", 20, "governance"],
      ["Зафиксировать forms, links, anchors, analytics, SEO и custom code", "Есть список технических зависимостей", 20, "analysis"],
      ["Подтвердить scope и rollback baseline текущей Tilda-страницы", "Полный rebuild исключён, откат определён", 20, "governance"],
    ]),
    makeStage("h03", "Типографика: аудит и выбор шрифтов", "Выбран Tilda-совместимый font stack на основе проблем текущей страницы.", [
      ["Провести аудит текущих шрифтов, размеров, весов и line-height", "Список типографических проблем", 30, "design"],
      ["Выбрать и проверить финальный font stack", "Рабочая пара/семейство шрифтов утверждены", 30, "design"],
    ]),
    makeStage("h04", "Типографика: шкалы, интервалы и интерактивные элементы", "Готовы desktop/mobile type scale, line-height, text width, spacing rhythm и правила CTA.", [
      ["Задать desktop и mobile type scale", "H1/H2/H3/body/caption определены", 20, "design"],
      ["Задать line-height, max text width и вертикальный rhythm", "Правила читаемости определены", 20, "design"],
      ["Задать типографику кнопок, ссылок и подписей и проверить на реальном блоке", "Система откалибрована", 20, "design"],
    ]),
    makeStage("h05", "Сообщение страницы и минимальная перестройка структуры", "Есть first-screen message, основной CTA и окончательный порядок существующих блоков.", [
      ["Сформулировать, что посетитель должен понять за первые 5–10 секунд", "Hero-message определён", 20, "content"],
      ["Определить основной CTA и найти дубли/провалы текущего сценария", "Главное действие и проблемы ясны", 20, "analysis"],
      ["Зафиксировать минимальные move/merge/split и финальный порядок блоков", "Есть новая карта страницы", 20, "design"],
    ]),
    makeStage("h06", "Redesign-spec: header и hero", "Header и первый экран полностью описаны до реализации на desktop и mobile.", [
      ["Спроектировать header/navigation на базе текущего блока", "Header-spec готов", 30, "design"],
      ["Спроектировать hero: композиция, текст, CTA, visual hierarchy", "Hero-spec готов", 30, "design"],
    ]),
    makeStage("h07", "Redesign-spec: первая половина основных white-блоков", "Первая половина смысловых блоков имеет отдельное решение по композиции и типографике.", [
      ["Разобрать и переработать первую группу блоков по audit map", "Первая группа имеет redesign-spec", 30, "design"],
      ["Проверить переходы, CTA и визуальный rhythm первой группы", "Первая группа собрана в связный сценарий", 30, "design"],
    ]),
    makeStage("h08", "Redesign-spec: вторая половина и trust/proof блоки", "Оставшиеся смысловые и доказательные блоки имеют отдельные redesign-решения.", [
      ["Разобрать и переработать вторую группу блоков по audit map", "Вторая группа имеет redesign-spec", 30, "design"],
      ["Довести benefits/cases/trust/proof до единой системы", "Доказательная часть страницы согласована", 30, "design"],
    ]),
    makeStage("h09", "Redesign-spec: CTA, формы, контакты и footer", "Все конверсионные и завершающие блоки спроектированы без потери текущих отправок и ссылок.", [
      ["Спроектировать CTA/contact/footer в новой системе", "Конец страницы согласован", 20, "design"],
      ["Переработать формы визуально без изменения рабочих направлений отправки", "Form-spec готов", 20, "design"],
      ["Сверить spec со всей audit map и закрыть пропущенные блоки", "Слепых зон нет", 20, "quality"],
    ]),
    makeStage("h10", "Tilda desktop: header, hero и новая типографика", "Первый экран desktop реализован в существующей Tilda-странице и использует новую систему.", [
      ["Переработать header/navigation в рабочей копии Tilda", "Header реализован", 30, "implementation"],
      ["Переработать hero и применить новую типографику", "Hero реализован", 30, "implementation"],
    ]),
    makeStage("h11", "Tilda desktop: первая половина white-блоков", "Первая половина страницы реализована по согласованным specs.", [
      ["Переделать первую часть white-блоков", "Первая часть реализована", 30, "implementation"],
      ["Довести контейнеры, сетку и вертикальный rhythm первой части", "Композиция первой части цельная", 30, "implementation"],
    ]),
    makeStage("h12", "Tilda desktop: вторая половина white-блоков", "Вторая половина страницы реализована по согласованным specs.", [
      ["Переделать вторую часть white-блоков", "Вторая часть реализована", 30, "implementation"],
      ["Довести trust/proof/CTA/footer блоки", "Конец страницы реализован", 30, "implementation"],
    ]),
    makeStage("h13", "Desktop consistency и сохранение интеграций", "Desktop выглядит как одна система, а все интерактивные элементы продолжают работать.", [
      ["Убрать остатки старых шрифтов, случайных размеров и интервалов", "Desktop consistency закрыт", 20, "quality"],
      ["Проверить buttons, links, anchors и формы", "Интерактивные элементы работают", 20, "quality"],
      ["Проверить analytics/custom code/SEO-зависимости после перестройки", "Технические зависимости сохранены", 20, "quality"],
    ]),
    makeStage("h14", "Mobile: header, hero и первая половина страницы", "Первый экран и первая половина имеют намеренную mobile-композицию, а не уменьшенный desktop.", [
      ["Адаптировать header и hero", "Mobile first screen готов", 20, "implementation"],
      ["Адаптировать первую половину изменённых блоков", "Первая половина mobile готова", 20, "implementation"],
      ["Проверить mobile type scale, spacing и tap targets первой части", "Первая часть удобна на телефоне", 20, "quality"],
    ]),
    makeStage("h15", "Mobile: вторая половина, формы и breakpoints", "Вся mobile-страница устойчива на разных ширинах и без overflow/keyboard проблем.", [
      ["Адаптировать вторую половину и footer", "Вторая половина mobile готова", 20, "implementation"],
      ["Проверить forms/CTA/keyboard/overflow", "Мобильные формы и CTA работают", 20, "quality"],
      ["Проверить несколько ширин и breakpoint-переходы", "Layout устойчив", 20, "quality"],
    ]),
    makeStage("h16", "Контент, media, performance и accessibility polish", "Тексты и изображения финализированы, тяжёлые assets устранены, базовая доступность проверена.", [
      ["Сделать финальный copy pass и убрать дубли/лишний текст", "Copy финализирован", 20, "content"],
      ["Оптимизировать изображения/media и проверить loading", "Нет неоправданно тяжёлых assets", 20, "performance"],
      ["Проверить contrast, alt/labels, keyboard/focus и читаемость", "Базовая accessibility закрыта", 20, "quality"],
    ]),
    makeStage("h17", "Финальный QA, публикация и live-проверка", "Production-страница опубликована, P0/P1 дефекты закрыты, формы/ссылки/analytics/SEO проверены после публикации.", [
      ["Провести desktop/tablet/mobile QA и закрыть P0/P1", "Release candidate готов", 20, "quality"],
      ["Опубликовать обновлённую страницу в Tilda", "Новая версия live", 20, "release"],
      ["Сделать live smoke test: forms/links/analytics/SEO/основные ширины", "Production проверен", 20, "release"],
    ]),
  ]

  const existingRevisions = app.findRecordsByFilter(
    revisions,
    "user_id = {:owner} && path_id = {:path}",
    "version",
    0,
    0,
    { owner: ownerId, path: pathId },
  )
  let maxVersion = 0
  for (const r of existingRevisions) {
    const v = Number(r.getRaw("version"))
    if (Number.isFinite(v)) maxVersion = Math.max(maxVersion, Math.trunc(v))
  }

  const revision = new Record(revisions)
  revision.set("user_id", ownerId)
  revision.set("path_id", pathId)
  revision.set("revision_id", desiredRevisionId)
  revision.set("version", maxVersion + 1)
  revision.set("lifecycle", "published")
  revision.set("goal", goal)
  revision.set("content", { stages })
  revision.set("source", "system")
  revision.set("parent_revision_id", "")
  app.save(revision)

  if (path == null) {
    path = new Record(paths)
    path.set("user_id", ownerId)
    path.set("path_id", pathId)
    path.set("category_link", child.id)
    path.set("archived", false)
  }
  path.set("active_revision_link", revision.id)
  app.save(path)
}

cronAdd("lifeos_etnika_homepage_hour_blocks_once", "* * * * *", function() {
  try {
    applyEtnikaHomepageHourlyPathOnce($app)
  } catch (error) {
    console.log("[ETNIKA_HOMEPAGE_HOUR_BLOCKS_ONCE] " + String(error))
  }
})
