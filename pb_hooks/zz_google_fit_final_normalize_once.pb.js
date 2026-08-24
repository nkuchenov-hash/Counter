/// <reference path="../pb_data/types.d.ts" />

function applyEtnikaHomepageRedesignOnce(app) {
  const categories = app.findCollectionByNameOrId("categories")
  const profiles = app.findCollectionByNameOrId("profiles")
  const plans = app.findCollectionByNameOrId("plans")
  const paths = app.findCollectionByNameOrId("paths")
  const revisions = app.findCollectionByNameOrId("path_revisions")
  const norm = (v) => String(v || "").trim().toLocaleLowerCase()
  const num = (r, f, d = 0) => {
    const n = Number(r.getRaw(f))
    return Number.isFinite(n) ? n : d
  }
  const allCategories = app.findRecordsByFilter(categories, "", "id", 0, 0)
  const etnikaCandidates = allCategories.filter((r) =>
    norm(r.getString("name")) === "этника" && !r.getBool("is_archived")
  )
  const pathsFor = (categoryId) => app.findRecordsByFilter(
    paths, "category_link = {:category}", "id", 0, 0, { category: categoryId },
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
  const revisionId = `${pathId}-v1`
  const weekIds = Array.from({ length: 7 }, (_, i) =>
    `etnika-homepage-redesign-2026-08-${String(i + 25).padStart(2, "0")}`
  )
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
    for (const sibling of siblings) nextOrder = Math.max(nextOrder, Math.trunc(num(sibling, "order")) + 1)
    child = new Record(categories)
    child.set("user_id", ownerId)
    child.set("category_id", businessId)
    child.set("name", childName)
    child.set("normalized_id", businessId)
    child.set("parent_id", etnika.id)
    child.set("order", nextOrder)
    child.set("is_archived", false)
    const color = Math.trunc(num(etnika, "color_value"))
    const icon = Math.trunc(num(etnika, "icon_code_point"))
    if (color) child.set("color_value", color)
    if (icon) child.set("icon_code_point", icon)
    app.save(child)
  } else if (child.getBool("is_archived")) {
    child.set("is_archived", false)
    app.save(child)
  }

  const completePath = pathsFor(child.id).filter((r) =>
    r.getString("user_id") === ownerId && r.getString("path_id") === pathId && !r.getBool("archived")
  )
  let completePlans = 0
  for (const planId of weekIds) {
    completePlans += app.findRecordsByFilter(
      plans, "user_id = {:owner} && plan_id = {:plan}", "id", 1, 0,
      { owner: ownerId, plan: planId },
    ).length
  }
  const rootPathsBefore = pathsFor(etnika.id).filter((r) => r.getString("user_id") === ownerId)
  if (completePath.length === 1 && completePlans === 7 && rootPathsBefore.length === 0) return

  for (const oldPath of pathsFor(child.id).filter((r) => r.getString("user_id") === ownerId)) {
    const oldId = oldPath.getString("path_id")
    app.delete(oldPath)
    if (!oldId) continue
    for (const rev of app.findRecordsByFilter(
      revisions, "user_id = {:owner} && path_id = {:path}", "id", 0, 0,
      { owner: ownerId, path: oldId },
    )) app.delete(rev)
  }

  const goal = "Переработать существующую главную страницу ЭТНИКА в Tilda, сохранив текущую основу и рабочие интеграции: обновить типографику, композицию и каждый существующий white-блок, слегка перестроить последовательность блоков, адаптировать desktop/mobile, провести QA и опубликовать обновлённую production-страницу без полного пересоздания сайта."
  const makeActions = (stageId, rows) => rows.map((r, i) => ({
    id: `${stageId}-a${i + 1}`,
    text: r[0],
    result: r[1],
    minutes: r[2],
    track: r[3],
    isDone: false,
  }))
  const makeStage = (id, text, done, rows) => ({
    type: "stage", id, text, definitionOfDone: done, isDone: false,
    actions: makeActions(id, rows),
  })
  const stages = [
    makeStage("s1", "Текущая главная страница разобрана и зафиксирована без потери рабочей основы", "Есть полная карта desktop/mobile всех white-блоков, решения keep/rework/move/merge/remove и список технических зависимостей, которые нужно сохранить.", [
      ["Зафиксировать desktop и перечислить все white-блоки сверху вниз", "Полный нумерованный список desktop-блоков", 20, "analysis"],
      ["Зафиксировать mobile тех же блоков", "Для каждого блока отмечено mobile-поведение", 20, "analysis"],
      ["Для каждого блока записать функцию, сообщение и CTA", "У каждого блока есть роль в пользовательском пути", 30, "analysis"],
      ["Отметить каждый блок keep / rework / move / merge / remove", "Нет блока без решения", 25, "analysis"],
      ["Собрать формы, кнопки, ссылки, якоря и направления отправки", "Есть checklist интерактивных элементов", 25, "analysis"],
      ["Зафиксировать analytics, SEO/meta, custom code и Tilda-зависимости", "Критичные зависимости перечислены", 30, "analysis"],
      ["Зафиксировать scope: переделываем текущую Tilda-страницу, не строим сайт заново", "Миграция платформы и полный rebuild исключены", 15, "governance"],
    ]),
    makeStage("s2", "Новая типографика и визуальные правила готовы для всех текущих блоков", "Выбраны Tilda-совместимые шрифты, desktop/mobile type scale, line-height, text width, spacing rhythm и правила CTA; система проверена на реальных блоках.", [
      ["Провести аудит текущих шрифтов, размеров, весов и line-height", "Список типографических проблем", 25, "design"],
      ["Выбрать финальный font stack для текущей Tilda", "Утверждены рабочие шрифты", 30, "design"],
      ["Задать desktop type scale H1/H2/H3/body/caption/button", "Единая desktop-иерархия", 25, "design"],
      ["Задать отдельный mobile type scale", "Единая mobile-иерархия", 25, "design"],
      ["Определить line-height, ширины текста и вертикальный rhythm", "Есть правила читаемости и интервалов", 20, "design"],
      ["Определить типографику CTA, кнопок, ссылок и подписей", "Интерактивная типографика согласована", 20, "design"],
      ["Проверить систему на hero и одном контентном блоке", "Типографика откалибрована на реальной странице", 30, "design"],
    ]),
    makeStage("s3", "Сообщение страницы и минимальная перестройка структуры согласованы", "Зафиксированы first-screen message, CTA, окончательный порядок существующих/переработанных блоков и список copy, который остаётся или меняется.", [
      ["Сформулировать, что посетитель должен понять за первые 5–10 секунд", "Есть ясная задача hero", 20, "content"],
      ["Зафиксировать основной CTA и роль вторичных CTA", "Главное действие пользователя определено", 20, "content"],
      ["Найти дубли, провалы и слабые переходы текущей структуры", "Есть список структурных проблем", 25, "analysis"],
      ["Предложить минимальные move / merge / split текущих блоков", "Получен эволюционный новый порядок", 30, "design"],
      ["Зафиксировать финальную последовательность и функцию каждого блока", "Есть карта будущей страницы", 25, "governance"],
      ["Отметить copy, который остаётся, сокращается или переписывается", "Нет текста без решения", 20, "content"],
    ]),
    makeStage("s4", "Для каждого блока существует конкретное redesign-решение", "Header, hero, смысловые блоки, proof/trust, CTA/forms, footer и остаточные блоки имеют отдельный redesign spec с desktop/mobile намерением.", [
      ["Сделать redesign spec header и навигации", "Header описан до реализации", 25, "design"],
      ["Сделать redesign spec hero на базе текущего первого экрана", "Hero описан до реализации", 30, "design"],
      ["Сделать redesign spec основных value/service блоков", "Основные блоки имеют решения", 30, "design"],
      ["Сделать redesign spec proof/cases/benefits/trust блоков", "Доказательные блоки имеют решения", 30, "design"],
      ["Сделать redesign spec CTA/forms/contact с сохранением отправок", "Формы и CTA не теряют интеграции", 30, "design"],
      ["Сделать redesign spec footer", "Footer приведён к новой системе", 20, "design"],
      ["Пройти audit map и закрыть все оставшиеся блоки", "Нет пропущенного блока", 30, "quality"],
    ]),
    makeStage("s5", "Desktop-версия текущей Tilda-страницы полностью переделана на white-блоках", "Все согласованные desktop-блоки используют новую типографику, сетку и композицию; формы, ссылки и интеграции сохранены; старых случайных стилей не осталось.", [
      ["Создать/подтвердить безопасную рабочую копию и rollback baseline", "Исходная live-версия защищена", 15, "implementation"],
      ["Переработать header и hero в Tilda", "Первый экран desktop реализован", 30, "implementation"],
      ["Переработать первую половину white-блоков", "Первая половина обновлена", 30, "implementation"],
      ["Переработать вторую половину white-блоков", "Вторая половина обновлена", 30, "implementation"],
      ["Нормализовать контейнеры, сетку и вертикальный rhythm", "Страница стала цельной композицией", 30, "implementation"],
      ["Восстановить и проверить buttons/links/forms/anchors/integrations", "Рабочие действия сохранены", 30, "implementation"],
      ["Сделать desktop consistency sweep", "Нет остатков старых шрифтов и стилей", 30, "quality"],
    ]),
    makeStage("s6", "Каждый изменённый блок имеет намеренную mobile-версию", "Hero/header, обе половины страницы, формы и CTA адаптированы для телефона, проверены несколько ширин и устранены overflow/spacing/tap-target проблемы.", [
      ["Определить mobile-композицию каждого изменённого блока", "Mobile не является простым уменьшением desktop", 25, "design"],
      ["Адаптировать header и hero", "Первый экран удобен на телефоне", 30, "implementation"],
      ["Адаптировать первую половину white-блоков", "Первая половина корректна на mobile", 30, "implementation"],
      ["Адаптировать вторую половину white-блоков", "Вторая половина корректна на mobile", 30, "implementation"],
      ["Проверить type scale, интервалы и tap targets", "Текст и управление удобны", 25, "quality"],
      ["Проверить forms, CTA, overflow и клавиатурные сценарии", "Мобильные формы работают без layout-проблем", 25, "quality"],
      ["Проверить несколько ширин и breakpoint-переходы", "Layout устойчив на типовых телефонах", 30, "quality"],
    ]),
    makeStage("s7", "Контент и медиа доведены до финального состояния", "Во всех блоках финальный copy, изображения оптимизированы и кадрированы, графика единообразна, placeholders/дубли удалены, базовая accessibility добавлена где возможно.", [
      ["Сделать финальный copy pass по всем блокам", "Нет временных текстов", 30, "content"],
      ["Проверить crop, качество и вес изображений", "Медиа выглядит правильно и не перегружает страницу", 30, "content"],
      ["Унифицировать иконки, графику и акценты", "Графика принадлежит одной системе", 20, "design"],
      ["Удалить placeholders, дубли и устаревшие элементы", "Лишний контент удалён", 20, "quality"],
      ["Проверить alt text и базовую accessibility в рамках Tilda", "Ключевые элементы имеют базовую доступность", 20, "quality"],
    ]),
    makeStage("s8", "Страница прошла технический и визуальный QA", "Links/buttons/anchors, forms, analytics, SEO/meta, загрузка и desktop/tablet/mobile проверены; все P0/P1 устранены до публикации.", [
      ["Проверить все links, buttons, navigation и anchors", "Нет broken actions", 20, "qa"],
      ["Отправить тесты через все forms и проверить интеграции", "Формы доставляют данные правильно", 30, "qa"],
      ["Проверить analytics, targets и tracking", "Ключевой tracking сохранён", 20, "qa"],
      ["Проверить title, description и SEO/meta", "SEO-настройки не потеряны", 20, "qa"],
      ["Проверить загрузку fonts/images и общий page weight", "Нет очевидной performance-регрессии", 25, "qa"],
      ["Сделать desktop/tablet/mobile regression sweep", "Основные размеры стабильны", 30, "qa"],
      ["Собрать issue list и закрыть P0/P1", "Нет блокирующих дефектов", 30, "qa"],
    ]),
    makeStage("s9", "Обновлённая главная ЭТНИКА опубликована и проверена в production", "Сохранён rollback, новая Tilda-страница опубликована, live desktop/mobile/forms/analytics проверены, production-only дефекты исправлены, цель Path подтверждена.", [
      ["Сохранить финальный rollback baseline старой live-страницы", "Есть путь отката", 15, "release"],
      ["Опубликовать обновлённую главную в Tilda", "Новая версия live", 15, "release"],
      ["Провести live desktop smoke test", "Production desktop подтверждён", 20, "release"],
      ["Провести live mobile smoke test", "Production mobile подтверждён", 20, "release"],
      ["Отправить live тестовую форму и проверить contact flow", "Production form работает end-to-end", 20, "release"],
      ["Проверить live analytics и основные CTA", "Tracking и CTA работают", 15, "release"],
      ["Исправить production-only дефекты", "Нет известных live P0/P1", 30, "release"],
      ["Сверить результат с целью Path и закрыть остаток", "Path завершён без слепых зон", 15, "governance"],
    ]),
  ]

  const revision = new Record(revisions)
  revision.set("user_id", ownerId)
  revision.set("path_id", pathId)
  revision.set("revision_id", revisionId)
  revision.set("version", 1)
  revision.set("lifecycle", "published")
  revision.set("goal", goal)
  revision.set("content", { stages })
  revision.set("source", "manual")
  revision.set("parent_revision_id", "")
  app.save(revision)

  const path = new Record(paths)
  path.set("user_id", ownerId)
  path.set("path_id", pathId)
  path.set("category_link", child.id)
  path.set("active_revision_link", revision.id)
  path.set("archived", false)
  app.save(path)

  const week = [
    ["2026-08-25", weekIds[0], "ЭТНИКА — главная: аудит текущей страницы", 90, "Path stages 1 + start of 2", ["Зафиксировать desktop/mobile и список всех white-блоков", "Для каждого блока отметить цель, проблему и CTA", "Отметить keep/rework/move/merge/remove", "Зафиксировать forms/links/analytics/SEO/Tilda-зависимости"]],
    ["2026-08-26", weekIds[1], "ЭТНИКА — главная: новая типографика и визуальные правила", 90, "Path stage 2", ["Провести аудит текущих шрифтов и текстовой иерархии", "Выбрать финальный font stack для Tilda", "Зафиксировать type scale desktop/mobile и spacing rhythm", "Проверить систему на hero и контентном блоке"]],
    ["2026-08-27", weekIds[2], "ЭТНИКА — главная: структура, сообщение и hero", 90, "Path stages 3–4", ["Зафиксировать сообщение hero и основной CTA", "Минимально перестроить порядок текущих блоков", "Зафиксировать финальную последовательность блоков", "Сделать redesign spec header + hero"]],
    ["2026-08-28", weekIds[3], "ЭТНИКА — главная: редизайн desktop-блоков · часть 1", 120, "Path stages 4–5", ["Подтвердить рабочую копию/rollback baseline", "Применить новую типографику к header/hero", "Переработать первую половину white-блоков", "Нормализовать сетку и вертикальный rhythm"]],
    ["2026-08-29", weekIds[4], "ЭТНИКА — главная: редизайн desktop-блоков · часть 2", 120, "Path stage 5 + content prep", ["Переработать оставшиеся white-блоки", "Довести CTA/forms/contact/footer", "Проверить links/forms/anchors/integrations", "Убрать остатки старых desktop-стилей"]],
    ["2026-08-30", weekIds[5], "ЭТНИКА — главная: мобильная адаптация", 120, "Path stage 6", ["Адаптировать header/hero и mobile type scale", "Адаптировать все изменённые white-блоки", "Проверить CTA/forms/tap targets/overflow", "Проверить несколько mobile widths"]],
    ["2026-08-31", weekIds[6], "ЭТНИКА — главная: финал, QA и публикация", 120, "Path stages 7–9", ["Финальный copy/media pass", "Проверить links/forms/analytics/SEO/loading", "Сделать desktop/tablet/mobile QA и закрыть P0/P1", "Опубликовать в Tilda и сделать live smoke tests"]],
  ]

  const profile = app.findRecordById(profiles, ownerId)
  const offset = num(profile, "timezone_offset", 0)
  const profileTz = norm(profile.getString("preferred_timezone"))
  const childTime = child.getString("default_plan_time")
  const rootTime = etnika.getString("default_plan_time")
  const categoryTime = childTime || rootTime
  const categoryTz = norm(childTime ? child.getString("default_plan_timezone") : etnika.getString("default_plan_timezone"))
  const parseClock = (value) => {
    const m = String(value || "").trim().match(/^(\d{1,2}):(\d{2})$/)
    if (!m) return null
    const h = Number(m[1]), min = Number(m[2])
    return h >= 0 && h <= 23 && min >= 0 && min <= 59 ? { h, min } : null
  }
  const categoryClock = parseClock(categoryTime)
  const useCategoryClock = categoryClock && (!categoryTz || categoryTz === "profile" || categoryTz === profileTz)
  const preferred = useCategoryClock ? categoryClock : { h: 10, min: 0 }
  const wallUtc = (dateKey, h, min) => {
    const p = dateKey.split("-").map(Number)
    return new Date(Date.UTC(p[0], p[1] - 1, p[2], h, min) - offset * 3600000)
  }
  const dayBounds = (dateKey) => {
    const start = wallUtc(dateKey, 0, 0)
    return { start, end: new Date(start.getTime() + 86400000) }
  }
  const dayPlans = (dateKey) => {
    const b = dayBounds(dateKey)
    return app.findRecordsByFilter(
      plans,
      "user_id = {:owner} && start_time >= {:start} && start_time < {:end}",
      "start_time", 0, 0,
      { owner: ownerId, start: b.start.toISOString(), end: b.end.toISOString() },
    )
  }
  const freeStart = (dateKey, minutes, existing) => {
    const b = dayBounds(dateKey), duration = minutes * 60000
    const intervals = []
    for (const r of existing) {
      const a = new Date(r.getString("start_time"))
      if (!Number.isFinite(a.getTime())) continue
      let z = r.getString("end_time") ? new Date(r.getString("end_time")) : new Date(a.getTime() + 1800000)
      if (!Number.isFinite(z.getTime()) || z <= a) z = new Date(a.getTime() + 1800000)
      intervals.push({ a, z })
    }
    const fits = (candidate) => {
      const end = new Date(candidate.getTime() + duration)
      return end <= b.end && !intervals.some((x) => candidate < x.z && x.a < end)
    }
    let candidate = wallUtc(dateKey, preferred.h, preferred.min)
    while (candidate.getTime() + duration <= b.end.getTime()) {
      if (fits(candidate)) return candidate
      candidate = new Date(candidate.getTime() + 300000)
    }
    candidate = new Date(b.start)
    const preferredStart = wallUtc(dateKey, preferred.h, preferred.min)
    while (candidate < preferredStart) {
      if (fits(candidate)) return candidate
      candidate = new Date(candidate.getTime() + 300000)
    }
    return preferredStart
  }

  for (const item of week) {
    const dateKey = item[0], planId = item[1], title = item[2], minutes = item[3], refs = item[4], checklist = item[5]
    for (const old of app.findRecordsByFilter(
      plans, "user_id = {:owner} && plan_id = {:plan}", "id", 0, 0,
      { owner: ownerId, plan: planId },
    )) app.delete(old)
    const existing = dayPlans(dateKey)
    let maxOrder = -1
    for (const r of existing) maxOrder = Math.max(maxOrder, Math.trunc(num(r, "order")))
    const start = freeStart(dateKey, minutes, existing)
    const end = new Date(start.getTime() + minutes * 60000)
    const plan = new Record(plans)
    plan.set("user_id", ownerId)
    plan.set("plan_id", planId)
    plan.set("category_id", child.id)
    plan.set("title", title)
    plan.set("is_done", false)
    plan.set("start_time", start.toISOString())
    plan.set("end_time", end.toISOString())
    plan.set("initial_date_key", dateKey)
    plan.set("is_postponed", false)
    plan.set("order", maxOrder + 1)
    plan.set("checklist", checklist.map((text, i) => ({ id: `${planId}-check-${i + 1}`, text, isDone: false })))
    plan.set("notes_plain", `Подпроект: ЭТНИКА → ${childName}. ${refs}. Рабочий блок: ${minutes} минут.`)
    app.save(plan)
  }

  for (const oldPath of pathsFor(etnika.id).filter((r) => r.getString("user_id") === ownerId)) {
    const oldId = oldPath.getString("path_id")
    app.delete(oldPath)
    if (!oldId) continue
    for (const rev of app.findRecordsByFilter(
      revisions, "user_id = {:owner} && path_id = {:path}", "id", 0, 0,
      { owner: ownerId, path: oldId },
    )) app.delete(rev)
  }
}

cronAdd("lifeos_etnika_homepage_redesign_once", "* * * * *", function() {
  try {
    applyEtnikaHomepageRedesignOnce($app)
  } catch (error) {
    console.log("[ETNIKA_HOMEPAGE_PATH_ONCE] " + String(error))
  }
})
