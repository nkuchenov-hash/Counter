/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const categories = app.findCollectionByNameOrId("categories")
  const profiles = app.findCollectionByNameOrId("profiles")
  const plans = app.findCollectionByNameOrId("plans")
  const paths = app.findCollectionByNameOrId("paths")
  const revisions = app.findCollectionByNameOrId("path_revisions")

  const norm = (value) => String(value || "").trim().toLocaleLowerCase()
  const rawNumber = (record, field, fallback = 0) => {
    const n = Number(record.getRaw(field))
    return Number.isFinite(n) ? n : fallback
  }
  const allCategories = app.findRecordsByFilter(
    categories,
    "",
    "id",
    0,
    0,
  )
  const etnikaCandidates = allCategories.filter((record) =>
    norm(record.getString("name")) === "этника" && !record.getBool("is_archived")
  )
  const pathsForCategory = (categoryId) => app.findRecordsByFilter(
    paths,
    "category_link = {:category}",
    "id",
    0,
    0,
    { category: categoryId },
  )
  const candidatesWithPaths = etnikaCandidates.filter((record) =>
    pathsForCategory(record.id).length > 0
  )

  let etnika = null
  if (candidatesWithPaths.length === 1) {
    etnika = candidatesWithPaths[0]
  } else if (candidatesWithPaths.length === 0 && etnikaCandidates.length === 1) {
    etnika = etnikaCandidates[0]
  } else {
    // Safety stop: never mutate ambiguous production data.
    return
  }

  const ownerId = etnika.getString("user_id")
  if (!ownerId) return
  try {
    app.findRecordById(profiles, ownerId)
  } catch (_) {
    return
  }

  const childName = "Обновление основной страницы сайта"
  const childMatches = allCategories.filter((record) =>
    record.getString("user_id") === ownerId &&
    record.getString("parent_id") === etnika.id &&
    norm(record.getString("name")) === norm(childName)
  )
  if (childMatches.length > 1) return

  let child = childMatches.length === 1 ? childMatches[0] : null
  if (child == null) {
    const usedCategoryIds = new Set(
      allCategories.map((record) => record.getString("category_id")).filter(Boolean),
    )
    let businessId = "etnika_homepage_redesign_20260824"
    let suffix = 2
    while (usedCategoryIds.has(businessId)) {
      businessId = `etnika_homepage_redesign_20260824_${suffix++}`
    }

    const siblings = allCategories.filter((record) =>
      record.getString("user_id") === ownerId &&
      record.getString("parent_id") === etnika.id
    )
    let nextOrder = 0
    for (const sibling of siblings) {
      nextOrder = Math.max(nextOrder, Math.trunc(rawNumber(sibling, "order", 0)) + 1)
    }

    child = new Record(categories)
    child.set("user_id", ownerId)
    child.set("category_id", businessId)
    child.set("name", childName)
    child.set("normalized_id", businessId)
    child.set("parent_id", etnika.id)
    child.set("order", nextOrder)
    child.set("is_archived", false)
    const color = Math.trunc(rawNumber(etnika, "color_value", 0))
    const icon = Math.trunc(rawNumber(etnika, "icon_code_point", 0))
    if (color !== 0) child.set("color_value", color)
    if (icon !== 0) child.set("icon_code_point", icon)
    app.save(child)
  } else if (child.getBool("is_archived")) {
    child.set("is_archived", false)
    app.save(child)
  }

  // A clean Path belongs to the subproject, not the root ETNIKA category.
  const existingChildPaths = pathsForCategory(child.id).filter((record) =>
    record.getString("user_id") === ownerId
  )
  for (const path of existingChildPaths) {
    const oldPathId = path.getString("path_id")
    app.delete(path)
    if (oldPathId) {
      const oldRevisions = app.findRecordsByFilter(
        revisions,
        "user_id = {:owner} && path_id = {:path}",
        "id",
        0,
        0,
        { owner: ownerId, path: oldPathId },
      )
      for (const revision of oldRevisions) app.delete(revision)
    }
  }

  const pathId = "etnika-homepage-redesign-20260824"
  const revisionId = `${pathId}-v1`
  const goal = "Переработать существующую главную страницу ЭТНИКА в Tilda, сохранив текущую основу и рабочие интеграции: обновить типографику, композицию и каждый существующий white-блок, слегка перестроить последовательность блоков, адаптировать desktop/mobile, провести QA и опубликовать обновлённую production-страницу без полного пересоздания сайта."

  const action = (id, text, result, minutes, track) => ({
    id,
    text,
    result,
    minutes,
    track,
    isDone: false,
  })
  const stage = (id, text, definitionOfDone, actions) => ({
    type: "stage",
    id,
    text,
    definitionOfDone,
    isDone: false,
    actions,
  })

  const stages = [
    stage(
      "stage-1-baseline",
      "Текущая главная страница разобрана и зафиксирована без потери рабочей основы",
      "Есть полная карта desktop/mobile всех текущих white-блоков, для каждого указан статус keep/rework/move/merge/remove, а формы, ссылки, аналитика, SEO и Tilda-настройки, которые нельзя потерять, перечислены отдельно.",
      [
        action("s1-a1", "Зафиксировать текущий desktop-вариант и перечислить все white-блоки сверху вниз", "Полный нумерованный список desktop-блоков со скриншотами/ссылками на их состояние", 20, "analysis"),
        action("s1-a2", "Зафиксировать текущий mobile-вариант тех же блоков", "Для каждого desktop-блока отмечено его реальное mobile-поведение и отличия", 20, "analysis"),
        action("s1-a3", "Для каждого блока записать его функцию, ключевое сообщение и CTA", "У каждого блока есть понятная роль в пользовательском пути", 30, "analysis"),
        action("s1-a4", "Отметить каждый блок как keep / rework / move / merge / remove", "Нет блока без решения о дальнейшей судьбе", 25, "analysis"),
        action("s1-a5", "Собрать все формы, кнопки, ссылки, якоря и текущие направления отправки", "Есть checklist всех интерактивных элементов, которые должны сохраниться после редизайна", 25, "analysis"),
        action("s1-a6", "Зафиксировать аналитику, SEO/meta, custom code и другие Tilda-зависимости текущей страницы", "Есть список технических зависимостей и интеграций, которые нельзя случайно сломать", 30, "analysis"),
        action("s1-a7", "Зафиксировать scope: переделываем существующую Tilda-страницу, а не строим сайт заново", "В работе исключены миграция платформы и ненужное полное пересоздание страницы", 15, "governance"),
      ],
    ),
    stage(
      "stage-2-typography",
      "Новая типографика и визуальные правила готовы для применения ко всем текущим блокам",
      "Выбран совместимый с текущей Tilda font stack, утверждены desktop/mobile размеры, веса, line-height, ширины текста, spacing rhythm и правила CTA; система проверена минимум на двух реальных блоках.",
      [
        action("s2-a1", "Провести аудит текущих шрифтов, размеров, весов и line-height", "Список типографических несоответствий и устаревших решений", 25, "design"),
        action("s2-a2", "Выбрать финальный font stack, который можно стабильно использовать в текущей Tilda", "Утверждены основной и при необходимости акцентный шрифт без смены платформы", 30, "design"),
        action("s2-a3", "Задать desktop type scale для H1/H2/H3/body/caption/button", "Есть единая desktop-иерархия текста", 25, "design"),
        action("s2-a4", "Задать mobile type scale и минимальные безопасные размеры", "Есть отдельная mobile-иерархия без простого механического уменьшения desktop", 25, "design"),
        action("s2-a5", "Определить line-height, максимальную ширину текста и вертикальный spacing rhythm", "Текстовые блоки имеют единый ритм и читаемую длину строки", 20, "design"),
        action("s2-a6", "Определить типографику CTA, кнопок, ссылок и служебных подписей", "Интерактивная типографика согласована со всей страницей", 20, "design"),
        action("s2-a7", "Применить правила к двум разным существующим блокам и откалибровать систему", "Типографика проверена на реальном hero и контентном блоке, а не только в абстрактной таблице", 30, "design"),
      ],
    ),
    stage(
      "stage-3-structure",
      "Сообщение страницы и минимальная перестройка существующей структуры согласованы",
      "Зафиксированы сообщение первого экрана, основной CTA, окончательный порядок текущих/переработанных блоков, необходимые merge/split/move и список текста, который сохраняется или переписывается.",
      [
        action("s3-a1", "Сформулировать, что посетитель должен понять об ЭТНИКА за первые 5–10 секунд", "Есть одна ясная формулировка задачи первого экрана", 20, "content"),
        action("s3-a2", "Зафиксировать основной CTA и роль вторичных CTA", "Понятно главное действие пользователя и где вторичные действия допустимы", 20, "content"),
        action("s3-a3", "Найти дубли, провалы и слабые переходы между текущими блоками", "Есть конкретный список структурных проблем без требования переписать страницу с нуля", 25, "analysis"),
        action("s3-a4", "Предложить минимальные move / merge / split для существующих блоков", "Получен новый порядок, максимально использующий нынешнюю Tilda-основу", 30, "design"),
        action("s3-a5", "Зафиксировать финальную последовательность блоков и функцию каждого", "Есть окончательная карта будущей страницы от header до footer", 25, "governance"),
        action("s3-a6", "Отметить copy, который остаётся, сокращается или переписывается", "Нет текста без решения о дальнейшей обработке", 20, "content"),
      ],
    ),
    stage(
      "stage-4-block-spec",
      "Для каждого блока существует конкретное redesign-решение и ни один участок страницы не пропущен",
      "Header, hero, основные смысловые блоки, доказательства/доверие, CTA/forms, footer и все остаточные блоки из аудита имеют отдельный redesign spec с desktop/mobile намерением.",
      [
        action("s4-a1", "Сделать redesign spec header и навигации", "Определены структура, типографика, высоты, состояния и mobile-поведение header", 25, "design"),
        action("s4-a2", "Сделать redesign spec hero на базе текущего первого экрана", "Определены композиция hero, message hierarchy, CTA, графика/фон и responsive-поведение", 30, "design"),
        action("s4-a3", "Сделать redesign spec основных value/service блоков", "Каждый основной смысловой блок имеет новую композицию без ненужного полного пересоздания страницы", 30, "design"),
        action("s4-a4", "Сделать redesign spec преимуществ, кейсов, proof и trust-блоков", "Доказательные блоки визуально и логически приведены к единой системе", 30, "design"),
        action("s4-a5", "Сделать redesign spec CTA, forms и contact-блоков с сохранением текущих отправок", "Формы и CTA переработаны визуально без потери интеграций", 30, "design"),
        action("s4-a6", "Сделать redesign spec footer", "Footer соответствует новой типографике и общей композиции", 20, "design"),
        action("s4-a7", "Пройти остаток карты аудита и оформить решения для всех неохваченных блоков", "В audit map нет ни одного блока без redesign/keep/remove решения", 30, "quality"),
      ],
    ),
    stage(
      "stage-5-desktop",
      "Desktop-версия существующей Tilda-страницы полностью переделана на отдельных white-блоках",
      "На безопасной рабочей версии Tilda все согласованные desktop-блоки используют новую типографику, сетку и композицию; старые формы/ссылки/интеграции восстановлены и нет визуально забытых старых участков.",
      [
        action("s5-a1", "Создать или подтвердить безопасную рабочую копию текущей Tilda-страницы и rollback baseline", "Можно переделывать блоки без риска потерять исходную live-версию", 15, "implementation"),
        action("s5-a2", "Переработать header и hero в Tilda по утверждённым правилам", "Первый экран desktop реализован в Tilda", 30, "implementation"),
        action("s5-a3", "Переработать первую половину текущих white-блоков", "Первая половина страницы перенесена на новую визуальную систему", 30, "implementation"),
        action("s5-a4", "Переработать вторую половину текущих white-блоков", "Все оставшиеся основные desktop-блоки обновлены", 30, "implementation"),
        action("s5-a5", "Нормализовать контейнеры, сетку, межблочные расстояния и вертикальный ритм", "Страница воспринимается как единая композиция, а не набор несвязанных блоков", 30, "implementation"),
        action("s5-a6", "Восстановить и проверить кнопки, ссылки, forms, anchors и интеграции после перестройки блоков", "Все исходные рабочие действия пользователя сохранены", 30, "implementation"),
        action("s5-a7", "Сделать desktop consistency sweep и удалить остатки старых шрифтов/стилей", "Нет случайных фрагментов прежней визуальной системы", 30, "quality"),
      ],
    ),
    stage(
      "stage-6-mobile",
      "Каждый изменённый блок имеет намеренно спроектированную mobile-версию",
      "Hero/header, обе половины страницы, формы и CTA адаптированы по отдельным mobile-правилам, проверены распространённые ширины и устранены overflow/spacing/tap-target проблемы.",
      [
        action("s6-a1", "Пройти каждый изменённый блок и определить нужную mobile-композицию", "Есть mobile-решение для каждого блока, а не автоматическое уменьшение desktop", 25, "design"),
        action("s6-a2", "Адаптировать header и hero в Tilda для mobile", "Первый экран удобно читается и управляется на телефоне", 30, "implementation"),
        action("s6-a3", "Адаптировать первую половину white-блоков", "Первая половина страницы корректна на mobile", 30, "implementation"),
        action("s6-a4", "Адаптировать вторую половину white-блоков", "Вторая половина страницы корректна на mobile", 30, "implementation"),
        action("s6-a5", "Проверить mobile type scale, интервалы и tap targets", "Текст читаем, элементы не слишком мелкие, интерактивные зоны удобны", 25, "quality"),
        action("s6-a6", "Проверить forms, CTA, горизонтальный overflow и клавиатурные сценарии", "Мобильные формы и CTA работают без layout-проблем", 25, "quality"),
        action("s6-a7", "Проверить несколько распространённых ширин и исправить breakpoint-проблемы", "Mobile layout устойчив, а не настроен под один телефон", 30, "quality"),
      ],
    ),
    stage(
      "stage-7-content-media",
      "Контент и медиа доведены до финального состояния без временных элементов",
      "Во всех блоках финальный copy, изображения оптимизированы и корректно кадрированы, графика единообразна, placeholders/дубли удалены и добавлена базовая доступность, которую позволяет Tilda.",
      [
        action("s7-a1", "Сделать финальный copy pass по всем блокам", "Заголовки, тексты и CTA согласованы и не содержат временных формулировок", 30, "content"),
        action("s7-a2", "Проверить crop, качество и вес всех изображений", "Медиа выглядит правильно и не перегружает страницу", 30, "content"),
        action("s7-a3", "Унифицировать иконки, декоративную графику и визуальные акценты", "Графические элементы принадлежат одной системе", 20, "design"),
        action("s7-a4", "Удалить placeholder, дубли и устаревшие элементы", "На странице нет временного/лишнего контента", 20, "quality"),
        action("s7-a5", "Добавить/проверить alt text и базовую доступность там, где это позволяет Tilda", "Ключевые изображения и элементы имеют базовую accessibility-разметку", 20, "quality"),
      ],
    ),
    stage(
      "stage-8-qa",
      "Обновлённая страница прошла технический и визуальный QA и готова к публикации",
      "Проверены links/buttons/anchors, forms, analytics, SEO/meta, скорость загрузки, desktop/tablet/mobile; все P0/P1 проблемы устранены до публикации.",
      [
        action("s8-a1", "Проверить все ссылки, кнопки, навигацию и anchors", "Нет broken links, неверных anchors или неработающих CTA", 20, "qa"),
        action("s8-a2", "Отправить тесты через все forms и проверить существующие направления/интеграции", "Каждая форма реально доставляет данные туда же, куда должна", 30, "qa"),
        action("s8-a3", "Проверить analytics, targets и tracking после изменений", "Трекинг ключевых действий сохранён", 20, "qa"),
        action("s8-a4", "Проверить title, description и основные SEO/meta настройки", "Базовая SEO-конфигурация не потеряна при redesign", 20, "qa"),
        action("s8-a5", "Быстро проверить загрузку шрифтов, изображений и общий page weight", "Нет очевидной performance-регрессии от новых шрифтов/медиа", 25, "qa"),
        action("s8-a6", "Сделать regression sweep desktop / tablet / несколько mobile widths", "Страница визуально целостна на основных размерах", 30, "qa"),
        action("s8-a7", "Собрать финальный issue list и закрыть все P0/P1", "Перед публикацией нет критических или заметных блокирующих дефектов", 30, "qa"),
      ],
    ),
    stage(
      "stage-9-production",
      "Обновлённая главная ЭТНИКА опубликована в Tilda и проверена в production",
      "Сохранён rollback baseline, опубликована обновлённая страница, live desktop/mobile/forms/analytics проверены, production-only дефекты исправлены, цель Path подтверждена и все этапы можно отметить выполненными.",
      [
        action("s9-a1", "Сохранить финальный rollback baseline старой live-страницы", "Есть понятный путь возврата к предыдущей версии", 15, "release"),
        action("s9-a2", "Опубликовать обновлённую главную страницу в Tilda", "Новая версия доступна по production URL", 15, "release"),
        action("s9-a3", "Провести live desktop smoke test", "Production desktop соответствует проверенной рабочей версии", 20, "release"),
        action("s9-a4", "Провести live mobile smoke test", "Production mobile не имеет layout-регрессий", 20, "release"),
        action("s9-a5", "Отправить live тестовую форму и проверить полный contact flow", "Production форма и интеграция подтверждены end-to-end", 20, "release"),
        action("s9-a6", "Проверить live analytics и основные CTA", "Production tracking и CTA работают после публикации", 15, "release"),
        action("s9-a7", "Исправить production-only дефекты, если они проявились", "После публикации нет известных production-only P0/P1 проблем", 30, "release"),
        action("s9-a8", "Сверить результат с целью Path и закрыть оставшиеся пункты", "Обновлённая Tilda-страница действительно завершает Path без слепых зон", 15, "governance"),
      ],
    ),
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

  // Create the next seven days as concrete LifeOS plans in the subproject.
  const week = [
    {
      date: "2026-08-25",
      planId: "etnika-homepage-redesign-2026-08-25",
      title: "ЭТНИКА — главная: аудит текущей страницы",
      duration: 90,
      stageRefs: "Path stages 1 + start of 2",
      checklist: [
        "Зафиксировать desktop/mobile и список всех white-блоков",
        "Для каждого блока отметить цель, проблему и CTA",
        "Отметить keep/rework/move/merge/remove",
        "Зафиксировать forms/links/analytics/SEO/Tilda-зависимости",
      ],
    },
    {
      date: "2026-08-26",
      planId: "etnika-homepage-redesign-2026-08-26",
      title: "ЭТНИКА — главная: новая типографика и визуальные правила",
      duration: 90,
      stageRefs: "Path stage 2",
      checklist: [
        "Провести аудит текущих шрифтов и текстовой иерархии",
        "Выбрать финальный font stack для текущей Tilda",
        "Зафиксировать type scale desktop/mobile и spacing rhythm",
        "Проверить систему на hero и одном контентном блоке",
      ],
    },
    {
      date: "2026-08-27",
      planId: "etnika-homepage-redesign-2026-08-27",
      title: "ЭТНИКА — главная: структура, сообщение и hero",
      duration: 90,
      stageRefs: "Path stages 3–4",
      checklist: [
        "Зафиксировать сообщение первого экрана и основной CTA",
        "Найти дубли/провалы и минимально перестроить порядок текущих блоков",
        "Зафиксировать финальную последовательность блоков",
        "Сделать redesign spec header + hero",
      ],
    },
    {
      date: "2026-08-28",
      planId: "etnika-homepage-redesign-2026-08-28",
      title: "ЭТНИКА — главная: редизайн desktop-блоков · часть 1",
      duration: 120,
      stageRefs: "Path stages 4–5",
      checklist: [
        "Подтвердить рабочую копию/rollback baseline в Tilda",
        "Применить новую типографику к header и hero",
        "Переработать первую половину текущих white-блоков",
        "Нормализовать сетку, интервалы и вертикальный ритм",
      ],
    },
    {
      date: "2026-08-29",
      planId: "etnika-homepage-redesign-2026-08-29",
      title: "ЭТНИКА — главная: редизайн desktop-блоков · часть 2",
      duration: 120,
      stageRefs: "Path stage 5 + content prep",
      checklist: [
        "Переработать оставшиеся текущие white-блоки",
        "Довести CTA/forms/contact/footer",
        "Восстановить и проверить links/forms/anchors/integrations",
        "Сделать desktop consistency sweep и убрать остатки старых стилей",
      ],
    },
    {
      date: "2026-08-30",
      planId: "etnika-homepage-redesign-2026-08-30",
      title: "ЭТНИКА — главная: мобильная адаптация",
      duration: 120,
      stageRefs: "Path stage 6",
      checklist: [
        "Адаптировать header/hero и mobile type scale",
        "Адаптировать все изменённые white-блоки",
        "Проверить CTA/forms/tap targets/overflow",
        "Проверить несколько mobile widths и исправить breakpoint-проблемы",
      ],
    },
    {
      date: "2026-08-31",
      planId: "etnika-homepage-redesign-2026-08-31",
      title: "ЭТНИКА — главная: финал, QA и публикация",
      duration: 120,
      stageRefs: "Path stages 7–9",
      checklist: [
        "Сделать финальный copy/media pass и убрать временные элементы",
        "Проверить links/forms/analytics/SEO и загрузку страницы",
        "Провести desktop/tablet/mobile regression sweep и закрыть P0/P1",
        "Опубликовать в Tilda и сделать live desktop/mobile/form smoke test",
      ],
    },
  ]

  const profile = app.findRecordById(profiles, ownerId)
  const timezoneOffsetHours = rawNumber(profile, "timezone_offset", 0)
  const preferredTimezone = norm(profile.getString("preferred_timezone"))
  const childDefault = child.getString("default_plan_time")
  const rootDefault = etnika.getString("default_plan_time")
  const childDefaultTz = norm(child.getString("default_plan_timezone"))
  const rootDefaultTz = norm(etnika.getString("default_plan_timezone"))
  const defaultTime = childDefault || rootDefault
  const defaultTz = childDefault ? childDefaultTz : rootDefaultTz

  const parseClock = (value) => {
    const match = String(value || "").trim().match(/^(\d{1,2}):(\d{2})$/)
    if (!match) return null
    const hour = Number(match[1])
    const minute = Number(match[2])
    if (!Number.isInteger(hour) || !Number.isInteger(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null
    return { hour, minute }
  }
  const defaultClock = parseClock(defaultTime)
  const canUseCategoryClock = defaultClock != null && (
    !defaultTz ||
    defaultTz === "profile" ||
    defaultTz === preferredTimezone
  )
  // No exact clock was requested. Prefer the existing ETNIKA category default;
  // otherwise use a practical 10:00 profile-wall fallback, then move forward
  // around existing plans so the new block does not knowingly overlap them.
  const preferredClock = canUseCategoryClock ? defaultClock : { hour: 10, minute: 0 }

  const wallDateToUtc = (dateKey, hour, minute) => {
    const parts = dateKey.split("-").map(Number)
    return new Date(
      Date.UTC(parts[0], parts[1] - 1, parts[2], hour, minute, 0, 0) -
      timezoneOffsetHours * 60 * 60 * 1000,
    )
  }
  const dayBoundsUtc = (dateKey) => {
    const start = wallDateToUtc(dateKey, 0, 0)
    return { start, end: new Date(start.getTime() + 24 * 60 * 60 * 1000) }
  }
  const existingPlansForDay = (dateKey) => {
    const bounds = dayBoundsUtc(dateKey)
    return app.findRecordsByFilter(
      plans,
      "user_id = {:owner} && start_time >= {:start} && start_time < {:end}",
      "start_time",
      0,
      0,
      {
        owner: ownerId,
        start: bounds.start.toISOString(),
        end: bounds.end.toISOString(),
      },
    )
  }
  const chooseFreeStart = (dateKey, durationMinutes, existing) => {
    const bounds = dayBoundsUtc(dateKey)
    let candidate = wallDateToUtc(dateKey, preferredClock.hour, preferredClock.minute)
    const intervals = []
    for (const record of existing) {
      const startRaw = record.getString("start_time")
      if (!startRaw) continue
      const start = new Date(startRaw)
      if (!Number.isFinite(start.getTime())) continue
      const endRaw = record.getString("end_time")
      let end = endRaw ? new Date(endRaw) : new Date(start.getTime() + 30 * 60 * 1000)
      if (!Number.isFinite(end.getTime()) || end <= start) end = new Date(start.getTime() + 30 * 60 * 1000)
      intervals.push({ start, end })
    }
    intervals.sort((a, b) => a.start - b.start)

    const durationMs = durationMinutes * 60 * 1000
    const fitsAt = (start) => {
      const end = new Date(start.getTime() + durationMs)
      if (end > bounds.end) return false
      return !intervals.some((interval) => start < interval.end && interval.start < end)
    }

    // Search forward in 5-minute increments (same scheduling snap family as LifeOS).
    while (candidate.getTime() + durationMs <= bounds.end.getTime()) {
      if (fitsAt(candidate)) return candidate
      candidate = new Date(candidate.getTime() + 5 * 60 * 1000)
    }
    // If the rest of the day is full, search from the day start up to the preferred time.
    candidate = new Date(bounds.start)
    const preferred = wallDateToUtc(dateKey, preferredClock.hour, preferredClock.minute)
    while (candidate < preferred) {
      if (fitsAt(candidate)) return candidate
      candidate = new Date(candidate.getTime() + 5 * 60 * 1000)
    }
    // Extreme overload fallback: retain the requested day even if it overlaps.
    return preferred
  }

  for (const item of week) {
    const old = app.findRecordsByFilter(
      plans,
      "user_id = {:owner} && plan_id = {:planId}",
      "id",
      0,
      0,
      { owner: ownerId, planId: item.planId },
    )
    for (const record of old) app.delete(record)

    const existing = existingPlansForDay(item.date)
    let maxOrder = -1
    for (const record of existing) {
      maxOrder = Math.max(maxOrder, Math.trunc(rawNumber(record, "order", 0)))
    }
    const start = chooseFreeStart(item.date, item.duration, existing)
    const end = new Date(start.getTime() + item.duration * 60 * 1000)

    const plan = new Record(plans)
    plan.set("user_id", ownerId)
    plan.set("plan_id", item.planId)
    plan.set("category_id", child.id)
    plan.set("title", item.title)
    plan.set("is_done", false)
    plan.set("start_time", start.toISOString())
    plan.set("end_time", end.toISOString())
    plan.set("initial_date_key", item.date)
    plan.set("is_postponed", false)
    plan.set("order", maxOrder + 1)
    plan.set("checklist", item.checklist.map((text, index) => ({
      id: `${item.planId}-check-${index + 1}`,
      text,
      isDone: false,
    })))
    plan.set(
      "notes_plain",
      `Подпроект: ЭТНИКА → ${childName}. ${item.stageRefs}. Запланированный рабочий блок: ${item.duration} минут.`,
    )
    app.save(plan)
  }

  // Root ETNIKA no longer owns a Path. Remove only its Path rows and their
  // immutable revision history; do not touch the ETNIKA category, records,
  // notes, ordinary plans, or the historical legacy source rows.
  const rootPaths = pathsForCategory(etnika.id).filter((record) =>
    record.getString("user_id") === ownerId
  )
  for (const oldPath of rootPaths) {
    const oldPathId = oldPath.getString("path_id")
    app.delete(oldPath)
    if (!oldPathId) continue
    const oldRevisions = app.findRecordsByFilter(
      revisions,
      "user_id = {:owner} && path_id = {:path}",
      "id",
      0,
      0,
      { owner: ownerId, path: oldPathId },
    )
    for (const oldRevision of oldRevisions) app.delete(oldRevision)
  }
}, (app) => {
  // Intentional no-op rollback: this is a one-time user data operation. The
  // migration creates a new durable Path + concrete plans and removes the old
  // ETNIKA Path only after the replacement data is saved successfully.
})
