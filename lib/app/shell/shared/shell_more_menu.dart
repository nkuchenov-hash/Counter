part of '../app_shell.dart';

const String _portfolioBootstrapPref =
    'lifeos.portfolio.bootstrap.2026-08-17.v1';
const String _portfolioPathMarker = 'LIFEOS_PATH::V1';

typedef _PortfolioSeed = ({
  String name,
  List<String> aliases,
  String goal,
  List<String> stages,
  IconData icon,
  Color color,
});

const List<_PortfolioSeed> _discussedPortfolioSeeds = [
  (
    name: 'КАДР',
    aliases: ['КАДР', 'KADR'],
    goal:
        'Превратить КАДР в стабильный Windows-инструмент для скриншотов с подтверждённой регулярной ценностью и первыми платящими пользователями.',
    stages: [
      'Зафиксировать стабильный core: выделение области → редактор → Copy/Save; закрыть оставшиеся blocker’ы видео, истории и hotkey.',
      'Собрать публичную beta-сборку и простую страницу с одним понятным обещанием продукта.',
      'Дать КАДР 5 внешним пользователям и записать реальные сценарии использования без подсказки, за что им «следовало бы» платить.',
      'Дойти до 20 внешних пользователей и измерять WAU, скриншоты на пользователя, retention 7/30 дней.',
      'Выделить один повторяющийся Job-to-be-Done, который бесплатные Lightshot / Snipping Tool / ShareX решают хуже.',
      'Проверить одну Pro-гипотезу без нативного iOS-приложения: например, передача на телефон через web/PWA, история/поиск или приватные share links.',
      'Получить первую реальную оплату и понять, за какую именно ценность она пришла.',
      'Дойти до 10 платящих пользователей или принять решение о перепозиционировании на основании данных.',
    ],
    icon: Icons.crop_free_rounded,
    color: Color(0xFF546E7A),
  ),
  (
    name: 'Игропоиск',
    aliases: ['Игропоиск', 'Igropoisk'],
    goal:
        'Сделать Игропоиск самопополняемым русскоязычным игровым сайтом с качественными страницами, органическим трафиком и подтверждённой моделью монетизации.',
    stages: [
      'Закрыть контрольный production lifecycle: Popular / Releases / News → Registry → полноценная страница игры без ручного создания.',
      'Добить обязательную полноту: у каждой популярной игры есть страница, news-хэштеги ведут на неё, New Releases идут полностью и хронологически.',
      'Унифицировать обзор и оценку: одна итоговая оценка на странице, средняя из источников обзора; добавить минимум 5 сильных русскоязычных изданий.',
      'Довести текст обзоров до живого русского редакционного уровня и убрать ощущение машинного перевода.',
      'Перепроверить алгоритм похожих игр и GAME DNA на реальных примерах, где текущая похожесть не устраивает.',
      'Обеспечить индексируемость: sitemap, canonical, метаданные, стабильные URL и отсутствие «страница готовится».',
      'Подключить базовую аналитику и получить первые устойчивые органические переходы из Google / Яндекс.',
      'После появления трафика проверить одну монетизацию: affiliate, реклама или партнёрский формат — и оставить только подтверждённую.',
    ],
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF6A5ACD),
  ),
  (
    name: 'GOLOS',
    aliases: ['GOLOS', 'Golos', 'Голос'],
    goal:
        'Довести GOLOS до надёжной голосовой печати с понятным отличием от конкурентов, регулярными пользователями и подтверждённой платной ценностью.',
    stages: [
      'Восстановить Parakeet: гарантированная установка GGUF, реальный inference и явная ошибка пользователю вместо final_empty.',
      'Закрыть базовый UX: hotkey, overlay, вставка текста, light/dark, RU/EN и корректные dropdown-слои.',
      'Зафиксировать бренд как сочетание voice + typing / keyboard key и собрать стабильный installer.',
      'Дать рабочую сборку 5 внешним пользователям и собрать проблемы по точности, задержке и вставке текста.',
      'Дойти до 20 пользователей и измерять повторное использование, количество диктовок и retention.',
      'Определить главное отличие GOLOS на данных, а не заранее: скорость, локальность, hotkey-flow, исправление текста или другой сценарий.',
      'Проверить первую платную функцию и получить первую оплату.',
      'После подтверждения спроса решить, масштабировать GOLOS или оставить его нишевым инструментом.',
    ],
    icon: Icons.mic_rounded,
    color: Color(0xFF00897B),
  ),
  (
    name: 'LIFE OS',
    aliases: ['LIFE OS', 'Life OS', 'LIFEOS'],
    goal:
        'Сделать LIFE OS личным центром управления: каждый день ясно, что делать, а раз в неделю видно, какие проекты реально растут, приносят деньги или тормозят.',
    stages: [
      'Завести актуальный портфель проектов и живые Paths с ближайшими действиями.',
      'Сделать еженедельный Portfolio Review: деньги, рост, затраченное время, bottleneck и следующий результат по каждому активному направлению.',
      'Добавить минимальные поля проекта: роль, стадия, текущий доход, North Star Metric, 90-day objective, milestone, Next Action, weekly budget.',
      'Связать ежедневный Planner с текущими этапами Paths так, чтобы план на день вытекал из проекта, а не жил отдельно.',
      'Собирать базовые метрики проектов сначала вручную, без строительства большого dashboard.',
      'Автоматизировать только те источники данных, которые уже регулярно используются: деньги, traffic, users, health и т.п.',
      'Сделать Portfolio Momentum видимым и перераспределять время между проектами по фактическим результатам.',
      'Довести систему до состояния, где портфелем можно управлять удалённо без постоянного ручного администрирования.',
    ],
    icon: Icons.hub_rounded,
    color: Color(0xFF3949AB),
  ),
  (
    name: 'Atozed / IntraWeb17',
    aliases: [
      'Atozed / IntraWeb17',
      'Atozed',
      'IntraWeb17',
      'IntraWeb 17',
      'IW17',
      'IntraWeb',
    ],
    goal:
        'Помочь успешно вывести IntraWeb17 и построить повторяемую систему beta → content → distribution → sales, которая увеличивает продажи и мой доход от Atozed.',
    stages: [
      'Свести IW17, beta-тестеров и CMS с Артемом в один launch-план с понятными владельцами и текущими blocker’ами.',
      'Довести CMS до регулярной публикации информации по нужным каналам без ручного копирования одного и того же контента.',
      'Сформировать стабильный поток beta-тестеров и обратной связи, который реально влияет на готовность IW17.',
      'Подготовить контент и каналы к релизу: страницы, новости, кейсы, документация и последовательность публикаций.',
      'После релиза отслеживать источник лидов, продажи IW17 и вклад контент-каналов в конверсию.',
      'Убирать ручные операции в sales/support, которые повторяются и могут быть безопасно автоматизированы.',
      'Когда вклад в IW17 измерим, обсудить отдельную мотивацию / комиссию за продажи нового продукта на фактических результатах.',
      'Довести канал до состояния, где продажи и контент растут без ежедневного ручного управления с моей стороны.',
    ],
    icon: Icons.language_rounded,
    color: Color(0xFF1976D2),
  ),
  (
    name: 'Etnika Studio',
    aliases: ['Etnika Studio', 'Etnika', 'ЭТНИКА', 'Этника'],
    goal:
        'Сделать вклад в Etnika измеримым и системным: прозрачная экономика, стабильный поток заявок и рост чистой прибыли при меньшем количестве ручной работы.',
    stages: [
      'Зафиксировать реальную unit-экономику: выручка − все расходы ≈ чистая прибыль → 20% пул мне + Егору → моя фактическая доля.',
      'Собрать baseline: трафик, заявки, записи/продажи, средний чек, расходы и чистая прибыль по месяцу.',
      'Довести сайт / формы / Telegram-передачу заявок до надёжного контура без потерянных обращений.',
      'Настроить понятную атрибуцию: откуда пришёл лид и какой канал реально дал продажу.',
      'Вместе с Егором убрать или изменить маркетинговые активности, которые потребляют бюджет и не дают измеримого результата.',
      'Автоматизировать повторяющиеся операции вокруг заявок, контента и отчётности.',
      'Повышать чистую прибыль бизнеса, а не только выручку, и видеть, как это отражается на моей доле.',
      'Довести мою часть участия до регулярного контроля системы вместо постоянного ручного обслуживания.',
    ],
    icon: Icons.palette_rounded,
    color: Color(0xFF8E5A4A),
  ),
  (
    name: 'Russian Culture Club',
    aliases: ['Russian Culture Club', 'RCC', 'Русский культурный клуб'],
    goal:
        'Построить устойчивое сообщество иностранцев и русских в Санкт-Петербурге, которое живёт не на одном организаторе, регулярно проводит события и само покрывает свою операционную нагрузку.',
    stages: [
      'Пересобрать операционную модель после ухода Алисы: какие форматы сохраняем, кто отвечает и что сейчас держится только на Кристине.',
      'Зафиксировать простой регулярный календарь событий, который реально можно поддерживать без перегруза.',
      'Найти 2–3 дополнительных ведущих / волонтёров, чтобы Кристина не была единственной точкой отказа.',
      'Собрать единый контур Telegram / Instagram / YouTube и повторяемый процесс публикации контента с мероприятий.',
      'Начать вести базу активного сообщества: новые люди, повторные посещения, самые сильные форматы и причины возвращения.',
      'Создать несколько событий, которые работают по шаблону и могут проводиться почти без моего участия.',
      'Аккуратно проверить устойчивую монетизацию: платные специальные события, membership, партнёры или sponsors — без разрушения открытой миссии клуба.',
      'Довести RCC до самоподдерживающегося сообщества с распределённой операционкой и финансовым запасом на развитие.',
    ],
    icon: Icons.groups_rounded,
    color: Color(0xFFC62828),
  ),
  (
    name: 'FLOW',
    aliases: ['FLOW', 'Flow'],
    goal:
        'Превратить FLOW в практический слой дистрибуции: научиться стабильно получать органический трафик и affiliate-доход и применять этот навык к собственным проектам.',
    stages: [
      'Закончить ключевую часть курса, достаточную для запуска, не проходя материал ради самого прохождения.',
      'Выбрать один acquisition-канал для первого цикла: SEO, Shorts, social или другой конкретный формат.',
      'Создать собственное присутствие и связать контент с реальными проектами, а не с абстрактными учебными примерами.',
      'Использовать CMS / автоматизацию там, где это ускоряет регулярность, но не заменяет проверку качества.',
      'Получить первые реальные переходы по referral / affiliate links.',
      'Получить первый \$1 affiliate-доход, затем \$10 и \$100 — как последовательные доказательства работающего канала.',
      'Перенести работающую механику трафика на IW17, КАДР, Игропоиск или другой проект, где есть подходящий intent.',
      'Оставить только каналы, которые дают измеримый результат на единицу моего времени.',
    ],
    icon: Icons.campaign_rounded,
    color: Color(0xFFEF6C00),
  ),
  (
    name: 'Price Reporter',
    aliases: ['Price Reporter'],
    goal:
        'Сохранить Price Reporter как надёжную удалённую финансовую базу, повысить ценность моей роли и со временем уменьшить долю ручной работы на единицу дохода.',
    stages: [
      'Посчитать фактический среднемесячный доход за 12 месяцев: фикс \$2,000 + все квартальные 12.5% бонусы.',
      'Зафиксировать, какие задачи и результаты реально создают наибольшую ценность для компании и клиентов.',
      'Выделить повторяющиеся операции GSA / FCP / pricing / market research, которые можно стандартизировать шаблонами или автоматизацией.',
      'Сократить время на рутинные задачи без снижения качества и compliance.',
      'Собрать доказательства объёма ответственности, экономии времени и клиентского результата.',
      'На этой базе обсудить повышение фиксированной части, бонусной схемы или роли — без привязки к фантазийному числу.',
      'Поддерживать стабильность дохода, пока собственные активы ещё проходят валидацию.',
      'Постепенно снижать зависимость портфеля от одного работодателя только после появления подтверждённых альтернативных доходов.',
    ],
    icon: Icons.work_rounded,
    color: Color(0xFF455A64),
  ),
  (
    name: 'Правители России',
    aliases: ['Правители России', 'Rulers of Russia', 'Praviteli Rossii'],
    goal:
        'Создать качественный evergreen-сайт о правителях России как культурный/SEO-медиа актив, используя готовую CMS и дистрибуцию только после проверки более близких приоритетов.',
    stages: [
      'Зафиксировать концепцию, аудиторию, структуру одной страницы правителя и критерий, когда проект действительно пора начинать строить.',
      'Определить стандарт источников, фактчекинга и редакционного качества до автоматизации контента.',
      'Не уходить в активную разработку, пока CMS / дистрибуция и более близкие продукты не освободят ресурс.',
      'Когда критерий старта выполнен — собрать один production-шаблон страницы и общий индекс правителей.',
      'Наполнить небольшой эталонный набор страниц вручную и проверить читаемость, источники и SEO-структуру.',
      'Подключить CMS только к тем частям генерации, где качество можно автоматически контролировать.',
      'Запустить сайт и измерять индексирование / organic impressions до масштабного наполнения.',
      'Расширять базу только если ранние страницы действительно получают поиск или усиливают RCC / культурную экосистему.',
    ],
    icon: Icons.account_balance_rounded,
    color: Color(0xFF6D4C41),
  ),
];

String _normalizePortfolioSeedName(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');

int? _findPortfolioSeedCategoryId(DatabaseService db, _PortfolioSeed seed) {
  final wanted = <String>{
    _normalizePortfolioSeedName(seed.name),
    for (final alias in seed.aliases) _normalizePortfolioSeedName(alias),
  };
  for (final pair in db.allCategoryIdPathPairs) {
    final rule = db.getCategoryRuleById(pair.id);
    if (rule == null || rule.isArchived) continue;
    if (wanted.contains(_normalizePortfolioSeedName(rule.name))) return pair.id;
  }
  return null;
}

bool _isPortfolioSeedPath(PlanningTask task) =>
    (task.notesPlain ?? '').trim() == _portfolioPathMarker;

Future<int?> _ensurePortfolioSeedCategory(
  DatabaseService db,
  _PortfolioSeed seed,
) async {
  final existing = _findPortfolioSeedCategoryId(db, seed);
  if (existing != null) return existing;

  final status = db.classifyCategoryDisplayNameInput(seed.name);
  if (status.kind == CategoryNameInputKind.active &&
      status.activeLocalId != null) {
    return status.activeLocalId;
  }
  if (status.kind == CategoryNameInputKind.archived &&
      status.archivedPbRowId != null) {
    final restored = await db.restoreArchivedCategory(status.archivedPbRowId!);
    if (restored != null) return restored;
  }

  final created = await db.addNestedCategory(
    null,
    CategoryRule(
      id: db.newId(),
      name: seed.name,
      colorValue: seed.color.toARGB32(),
      iconCodePoint: seed.icon.codePoint,
      isSynced: false,
    ),
  );
  if (created != null) return created;

  await db.refreshCategoryRulesFromServer();
  return _findPortfolioSeedCategoryId(db, seed);
}

Future<void> _bootstrapDiscussedPortfolioPaths() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_portfolioBootstrapPref) == true) return;

  final db = DatabaseService.instance;
  await db.refreshCategoryRulesFromServer();
  final backlog = await db.fetchBacklogPlans(includeCompleted: true);
  final categoriesWithPaths = <int>{
    for (final task in backlog)
      if (_isPortfolioSeedPath(task)) task.categoryId,
  };

  var allSucceeded = true;
  for (final seed in _discussedPortfolioSeeds) {
    final categoryId = await _ensurePortfolioSeedCategory(db, seed);
    if (categoryId == null) {
      allSucceeded = false;
      continue;
    }
    if (categoriesWithPaths.contains(categoryId)) continue;

    final order = await db.nextBacklogPlanningOrder();
    final slug = _normalizePortfolioSeedName(seed.name);
    final ok = await db.addPlanningTask(
      PlanningTask(
        id: 0,
        title: seed.goal,
        categoryId: categoryId,
        isDone: true,
        dateKey: '',
        order: order,
        checklist: [
          for (var i = 0; i < seed.stages.length; i++)
            <String, dynamic>{
              'id': 'portfolio-$slug-${i + 1}',
              'text': seed.stages[i],
              'isDone': false,
            },
        ],
        notesPlain: _portfolioPathMarker,
        isSynced: false,
      ),
    );
    if (ok) {
      categoriesWithPaths.add(categoryId);
    } else {
      allSucceeded = false;
    }
  }

  if (allSucceeded) {
    await prefs.setBool(_portfolioBootstrapPref, true);
  }
}

mixin ShellMoreMenu on ShellCoreLogic {
  static bool _moreMenuDiagnosticsMarkerLogged = false;

  bool get _desktopVoiceDevDiagnosticsVisible {
    const devToolsDefine = bool.fromEnvironment(
      'DESKTOP_VOICE_DEV_TOOLS',
      defaultValue: false,
    );
    final visible = kDebugMode || devToolsDefine;
    if (!_moreMenuDiagnosticsMarkerLogged) {
      _moreMenuDiagnosticsMarkerLogged = true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_MORE_MENU_DIAGNOSTICS_REMOVED');
      if (visible) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_DEV_ENTRY_GATED', 'dev_only');
      }
    }
    return visible;
  }

  void openProjectPaths() {
    unawaited(_openProjectPathsAfterPortfolioBootstrap());
  }

  Future<void> _openProjectPathsAfterPortfolioBootstrap() async {
    try {
      await _bootstrapDiscussedPortfolioPaths();
    } catch (e) {
      debugPrint('[PORTFOLIO_PATHS] bootstrap failed: $e');
    }
    if (!mounted) return;

    final formFactor = shellFormFactorForWidth(MediaQuery.sizeOf(context).width);
    if (formFactor != ShellFormFactor.desktop) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const CategoryPathsPage(),
        ),
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => DesktopShellFrame(
          selectedIndex: 6,
          onTabSelected: (navIndex) {
            if (navIndex == 6) return;
            Navigator.of(routeContext).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              onDesktopSideNavSelected(navIndex);
            });
          },
          child: const CategoryPathsPage(),
        ),
      ),
    );
  }

  void openMoreMenu({bool secondaryOnly = false}) {
    final loc = currentLocale.value;
    final isRu = loc.toLowerCase().startsWith('ru');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StreamBuilder<UserSettings>(
        stream: DatabaseService.instance.userSettingsStream,
        initialData: DatabaseService.instance.settings,
        builder: (context, snapshot) {
          final isAdmin =
              snapshot.data?.isAdmin ??
              DatabaseService.instance.settings.isAdmin;
          debugPrint(
            '[ADMIN_FLAG] More bottom sheet settings.isAdmin=$isAdmin renderDevLab=$isAdmin',
          );
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!secondaryOnly) ...[
                  ListTile(
                    leading: const Icon(Icons.person_rounded),
                    title: Text(t(loc, 'more_menu_profile')),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => setShellPageIndex(5));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.label_rounded),
                    title: Text(t(loc, 'more_menu_categories')),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => setShellPageIndex(4));
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.alt_route_rounded),
                  title: Text(isRu ? 'Пути проектов' : 'Project paths'),
                  subtitle: Text(
                    isRu
                        ? 'Живой план от цели к следующим действиям'
                        : 'A living plan from the goal to next actions',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    openProjectPaths();
                  },
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.design_services_rounded),
                    title: const Text('Dev / Design Lab'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const ComponentLabPage(),
                        ),
                      );
                    },
                  ),
                if (_desktopVoiceDevDiagnosticsVisible)
                  ListTile(
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: Text(t(loc, 'more_menu_voice_diagnostics')),
                    subtitle: Text(
                      t(loc, 'more_menu_voice_diagnostics_subtitle'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showDesktopVoiceAttemptDialog(context);
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    'Admin flag: $isAdmin',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void onShellTabSelected(int i) {
    if (i == 4) {
      openMoreMenu(secondaryOnly: false);
      return;
    }
    setState(() => setShellPageIndex(i));
    if (i == 0 || i == 1) {
      final target = DatabaseService.instance.getTimelineDeviceLocalToday();
      applySharedSelectedDate(target, loadTimelineTasks: i == 0);
    }
  }

  void onDesktopSideNavSelected(int navIndex) {
    // 0–3 primary tabs, 4 Categories, 5 Profile, 6 Paths, 7 More.
    if (navIndex == 6) {
      openProjectPaths();
      return;
    }
    if (navIndex == 7) {
      openMoreMenu(secondaryOnly: true);
      return;
    }
    if (navIndex <= 5) {
      setState(() => setShellPageIndex(navIndex));
      if (navIndex == 0 || navIndex == 1) {
        final target = DatabaseService.instance.getTimelineDeviceLocalToday();
        applySharedSelectedDate(target, loadTimelineTasks: navIndex == 0);
      }
    }
  }

  int desktopSideNavSelectedIndex(int shellPageIndex) {
    return switch (shellPageIndex) {
      0 || 1 || 2 || 3 || 4 || 5 => shellPageIndex,
      _ => 7,
    };
  }
}
