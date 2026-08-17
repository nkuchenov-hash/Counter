import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shell_daily_routine.dart';

const String _activePathMarkerV4 = 'LIFEOS_PATH::V2';
const String _retiredPathMarkerV4 = 'LIFEOS_PATH::V2_RETIRED';
const String _pathActionPlanMarkerV4 = 'LIFEOS_PATH_ACTION_V4|';
const String _weekRoutinePlanMarkerV4 = 'LIFEOS_WEEK_ROUTINE_V4|';
const String _plannerBaselineMigrationV7 = 'lifeos_planner_baseline_migration_v7';

String _pathSystemIdTokenV7(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'unknown' : normalized;
}

String _pathActionBusinessIdV7({
  required String rootId,
  required String stageId,
  required String actionId,
}) =>
    'lifeos-path-action-v1-${_pathSystemIdTokenV7(rootId)}-'
    '${_pathSystemIdTokenV7(stageId)}-${_pathSystemIdTokenV7(actionId)}';

const String _projectPlanApprovalStageIdV5 = 'approval-v5-gate';
const String _projectPlanApprovalActionIdV5 = 'approval-v5-review';

class ProjectPathAuditV4 {
  const ProjectPathAuditV4({
    required this.audited,
    required this.structureProblems,
    required this.missingTracks,
    required this.missingTopics,
  });

  final bool audited;
  final List<String> structureProblems;
  final List<String> missingTracks;
  final List<String> missingTopics;
}

class PathWeekPlanReportV4 {
  const PathWeekPlanReportV4({
    required this.createdTasks,
    required this.reconciledActions,
    required this.auditedProjects,
    required this.blockedProjects,
  });

  final int createdTasks;
  final int reconciledActions;
  final int auditedProjects;
  final List<String> blockedProjects;
}

class _PathAuditProfileV4 {
  const _PathAuditProfileV4({
    required this.name,
    required this.aliases,
    required this.requiredTracks,
    required this.requiredTopics,
    required this.weeklyMinutes,
    this.planningStageIndex,
  });

  final String name;
  final List<String> aliases;
  final List<String> requiredTracks;
  final Map<String, List<String>> requiredTopics;
  final int weeklyMinutes;
  final int? planningStageIndex;
}

const List<_PathAuditProfileV4> _pathAuditProfilesV4 = [
  _PathAuditProfileV4(
    name: 'КАДР',
    aliases: ['КАДР', 'KADR'],
    requiredTracks: [
      'offer',
      'product',
      'website',
      'payments',
      'licensing',
      'legal',
      'windows_distribution',
      'microsoft_store',
      'demand',
      'apple',
      'android',
      'support',
      'release',
    ],
    requiredTopics: {
      'что бесплатно и за что платят': ['бесплат', 'платн'],
      'сайт': ['сайт'],
      'лицензирование': ['лиценз'],
      'Microsoft Store': ['microsoft store'],
      'Apple/macOS/iPhone': ['apple', 'macos', 'iphone'],
      'Android/RuStore': ['android', 'rustore'],
      'проверка спроса': ['спрос', 'пользовател'],
      'поддержка': ['поддерж'],
    },
    weeklyMinutes: 120,
  ),
  _PathAuditProfileV4(
    name: 'Игропоиск',
    aliases: ['Игропоиск', 'Igropoisk'],
    requiredTracks: [
      'product',
      'reliability',
      'content',
      'seo',
      'demand',
      'legal',
      'payments',
      'operations',
    ],
    requiredTopics: {
      'создание страниц игр': ['game page', 'страниц'],
      'релизы': ['релиз'],
      'новости': ['новост'],
      'индексация': ['sitemap', 'canonical'],
      'права на контент': ['прав', 'лиценз', 'copyright'],
      'поисковый спрос': ['поиск', 'organic', 'трафик'],
      'монетизация': ['монет', 'affiliate', 'реклам'],
    },
    weeklyMinutes: 90,
  ),
  _PathAuditProfileV4(
    name: 'GOLOS',
    aliases: ['GOLOS', 'Golos', 'Голос'],
    requiredTracks: [
      'product',
      'reliability',
      'privacy',
      'distribution',
      'demand',
      'payments',
      'legal',
      'operations',
      'offer',
      'website',
      'licensing',
      'support',
    ],
    requiredTopics: {
      'Parakeet': ['parakeet'],
      'что бесплатно и за что платят': ['бесплат', 'платн'],
      'сайт': ['сайт'],
      'лицензирование': ['лиценз'],
      'публикация': ['store', 'магазин'],
      'поддержка': ['поддерж'],
      'проверка спроса': ['пользовател', 'спрос'],
    },
    weeklyMinutes: 60,
  ),
  _PathAuditProfileV4(
    name: 'LIFE OS',
    aliases: ['LIFE OS', 'Life OS', 'LIFEOS'],
    requiredTracks: ['product', 'reliability', 'privacy', 'validation', 'operations'],
    requiredTopics: {
      'Path → Planner': ['daily planner', 'planner'],
      'AI-доступ и разрешения': ['ai', 'ии', 'permission', 'разреш'],
      'проверка на реальном использовании': ['14', 'использован'],
      'синхронизация/восстановление': ['sync', 'синх', 'backup', 'восстанов'],
    },
    weeklyMinutes: 0,
  ),
  _PathAuditProfileV4(
    name: 'Atozed / IntraWeb17',
    aliases: [
      'Atozed / IntraWeb17',
      'Atozed',
      'IntraWeb17',
      'IntraWeb 17',
      'IW17',
      'IntraWeb',
    ],
    requiredTracks: [
      'operations',
      'product',
      'content',
      'distribution',
      'sales',
      'legal',
      'payments',
      'validation',
    ],
    requiredTopics: {
      'ежедневная операционка': ['почт', 'лиценз'],
      'IntraWeb17 beta': ['beta'],
      'CMS с Артёмом': ['cms'],
      'оплата/vendor flow': ['paddle', 'payment', 'оплат'],
      'юридический контур': ['terms', 'legal', 'лиценз'],
      'продажи/дистрибуция': ['sales', 'продаж', 'distribution'],
    },
    weeklyMinutes: 60,
    planningStageIndex: 2,
  ),
  _PathAuditProfileV4(
    name: 'Etnika Studio',
    aliases: ['Etnika Studio', 'Etnika', 'ЭТНИКА', 'Этника'],
    requiredTracks: ['finance', 'demand', 'distribution', 'legal', 'reliability', 'operations'],
    requiredTopics: {
      'экономика': ['прибыл', 'расход', 'выруч'],
      'заявки': ['заявк', 'lead'],
      'атрибуция': ['атриб', 'source', 'источник'],
      'персональные данные': ['privacy', 'персональн'],
      'автоматизация': ['автомат'],
    },
    weeklyMinutes: 30,
  ),
  _PathAuditProfileV4(
    name: 'Russian Culture Club',
    aliases: ['Russian Culture Club', 'RCC', 'Русский культурный клуб'],
    requiredTracks: ['people', 'operations', 'demand', 'distribution', 'legal', 'payments'],
    requiredTopics: {
      'распределение ролей': ['кристин', 'организатор', 'owner'],
      'события': ['событ', 'event'],
      'резерв организаторов': ['волонт', 'ведущ'],
      'каналы контента': ['telegram', 'instagram', 'youtube'],
      'правила/безопасность': ['legal', 'ответствен', 'безопас'],
      'оплата': ['оплат', 'paid', 'монет'],
    },
    weeklyMinutes: 30,
  ),
  _PathAuditProfileV4(
    name: 'FLOW',
    aliases: ['FLOW', 'Flow'],
    requiredTracks: [
      'learning',
      'course_assignment',
      'channel',
      'content',
      'validation',
      'playbook',
      'transfer',
    ],
    requiredTopics: {
      'полное прохождение курса': ['пройти курс', 'все обязательные'],
      'задания курса': ['задани'],
      'свои каналы': ['свои канал', 'канал'],
      'фиксация навыков': ['навык', 'playbook'],
      'перенос навыков на другие проекты': ['перенест', 'проект'],
    },
    weeklyMinutes: 75,
  ),
  _PathAuditProfileV4(
    name: 'Управление деньгами / ZenMoney',
    aliases: [
      'Управление деньгами / ZenMoney',
      'Управление деньгами',
      'ZenMoney',
      'Zen Money',
    ],
    requiredTracks: ['finance', 'operations', 'validation'],
    requiredTopics: {
      'ZenMoney как источник фактов': ['zenmoney'],
      'фактический доход по источникам': ['доход', 'источник'],
      'Price Reporter fixed/bonus': ['price reporter', 'бонус'],
      'расходы': ['расход'],
      'разрыв до 600 000': ['600 000', 'разрыв'],
    },
    weeklyMinutes: 45,
  ),
  _PathAuditProfileV4(
    name: 'Price Reporter',
    aliases: ['Price Reporter'],
    requiredTracks: ['operations', 'reliability', 'legal', 'automation', 'career'],
    requiredTopics: {
      'автоматизация': ['автомат'],
      'compliance': ['compliance', 'риск'],
      'доказательства ценности': ['ценност', 'value'],
      'непрерывность работы': ['sop', 'continuity', 'критич'],
    },
    weeklyMinutes: 0,
  ),
  _PathAuditProfileV4(
    name: 'Правители России',
    aliases: ['Правители России', 'Rulers of Russia', 'Praviteli Rossii'],
    requiredTracks: ['content', 'legal', 'product', 'seo', 'demand', 'operations', 'payments', 'website'],
    requiredTopics: {
      'источники и фактчекинг': ['источник', 'source', 'факт'],
      'права на контент': ['copyright', 'прав'],
      'сайт': ['домен', 'хостинг', 'https'],
      'SEO': ['seo', 'sitemap'],
      'проверка спроса': ['индекс', 'search', 'показ'],
      'монетизация': ['монет', 'payments', 'affiliate'],
    },
    weeklyMinutes: 0,
  ),
];

String _normalizeProjectNameV4(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');

_PathAuditProfileV4? _profileForProjectV4(String name) {
  final n = _normalizeProjectNameV4(name);
  for (final profile in _pathAuditProfilesV4) {
    for (final alias in profile.aliases) {
      if (_normalizeProjectNameV4(alias) == n) return profile;
    }
  }
  return null;
}

CategoryRule? _findCategoryByAliasesV4(List<String> aliases) {
  final db = DatabaseService.instance;
  final wanted = aliases.map(_normalizeProjectNameV4).toSet();
  for (final pair in db.allCategoryIdPathPairs) {
    final rule = db.getCategoryRuleById(pair.id);
    if (rule == null || rule.isArchived) continue;
    if (wanted.contains(_normalizeProjectNameV4(rule.name))) return rule;
  }
  return null;
}

List<Map<String, dynamic>> _pathActionsFromStageRawV4(Map<String, dynamic> stage) {
  final raw = stage['actions'];
  if (raw is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in raw)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

ProjectPathAuditV4 auditExecutableProjectPathV4(
  CategoryRule category,
  PlanningTask root,
) {
  final profile = _profileForProjectV4(category.name);
  final structure = <String>[];
  final tracks = <String>{};
  final text = StringBuffer(root.title.toLowerCase());

  if (root.checklist.isEmpty) structure.add('Нет этапов.');
  for (var si = 0; si < root.checklist.length; si++) {
    final stage = root.checklist[si];
    final stageTitle = (stage['text'] ?? '').toString().trim();
    final doneWhen = (stage['definitionOfDone'] ?? '').toString().trim();
    final stageDone = stage['isDone'] == true;
    if (stageTitle.isEmpty) structure.add('Этап ${si + 1}: нет названия результата.');
    if (doneWhen.isEmpty) {
      structure.add('Этап ${si + 1}: не указано проверяемое условие завершения.');
    }
    text
      ..write(' ')
      ..write(stageTitle.toLowerCase())
      ..write(' ')
      ..write(doneWhen.toLowerCase());
    final actions = _pathActionsFromStageRawV4(stage);
    if (!stageDone && actions.isEmpty) {
      structure.add('Этап ${si + 1}: нет конкретных действий.');
    }
    for (var ai = 0; ai < actions.length; ai++) {
      final action = actions[ai];
      final actionText = (action['text'] ?? '').toString().trim();
      final result = (action['result'] ?? '').toString().trim();
      final rawMinutes = action['minutes'];
      final minutes = rawMinutes is int
          ? rawMinutes
          : int.tryParse(rawMinutes?.toString() ?? '') ?? 0;
      final track = (action['track'] ?? '').toString().trim();
      if (actionText.isEmpty) {
        structure.add('Этап ${si + 1}, действие ${ai + 1}: нет физического действия.');
      }
      if (result.isEmpty) {
        structure.add('Этап ${si + 1}, действие ${ai + 1}: не указан результат.');
      }
      if (minutes < 1 || minutes > 30) {
        structure.add('Этап ${si + 1}, действие ${ai + 1}: время должно быть 1–30 минут.');
      }
      if (track.isNotEmpty) tracks.add(track);
      text
        ..write(' ')
        ..write(actionText.toLowerCase())
        ..write(' ')
        ..write(result.toLowerCase())
        ..write(' ')
        ..write(track.toLowerCase());
    }
  }

  if (profile == null) {
    return ProjectPathAuditV4(
      audited: false,
      structureProblems: structure,
      missingTracks: const [],
      missingTopics: const ['Для этого проекта ещё не задана предметная проверка слепых зон.'],
    );
  }

  final missingTracks = <String>[
    for (final required in profile.requiredTracks)
      if (!tracks.contains(required)) required,
  ];
  final searchable = text.toString();
  final missingTopics = <String>[];
  for (final entry in profile.requiredTopics.entries) {
    if (!entry.value.any((token) => searchable.contains(token.toLowerCase()))) {
      missingTopics.add(entry.key);
    }
  }
  if (!_projectPlanApprovedV5(root)) {
    missingTopics.insert(0, 'план проекта ещё не согласован');
  }

  return ProjectPathAuditV4(
    audited: structure.isEmpty && missingTracks.isEmpty && missingTopics.isEmpty,
    structureProblems: structure,
    missingTracks: missingTracks,
    missingTopics: missingTopics,
  );
}

Map<String, dynamic> _actionV4(
  String prefix,
  String id,
  String text,
  String result,
  int minutes,
  String track,
) => <String, dynamic>{
  'id': '$prefix$id',
  'text': text,
  'result': result,
  'minutes': minutes,
  'track': track,
  'isDone': false,
};

Map<String, dynamic> _stageV4(
  String prefix,
  String id,
  String title,
  String doneWhen,
  List<Map<String, dynamic>> actions,
) => <String, dynamic>{
  'type': 'stage',
  'id': '$prefix$id',
  'text': title,
  'definitionOfDone': doneWhen,
  'isDone': false,
  'actions': actions,
};

List<Map<String, dynamic>> _flowLearningPathV4() {
  const p = 'flow-v4-';
  return <Map<String, dynamic>>[
    _stageV4(
      p,
      '01',
      'Разобрать курс FLOW и превратить его структуру в очередь реальных действий',
      'В LIFE OS записаны все доступные модули/уроки курса, отмечено что уже пройдено, где я нахожусь сейчас, какие задания обязательны и какие каналы нужно создавать по заданиям.',
      [
        _actionV4(p, '01-01', 'Открыть кабинет FLOW и выписать названия всех доступных модулей курса по порядку', 'Список модулей в фактическом порядке курса', 20, 'learning'),
        _actionV4(p, '01-02', 'Отметить у каждого модуля: пройден / начат / не начат', 'Точная текущая позиция в курсе', 10, 'learning'),
        _actionV4(p, '01-03', 'Выписать из текущего и следующего модуля все задания, которые требуют что-то создать или опубликовать', 'Список ближайших практических заданий курса', 20, 'course_assignment'),
        _actionV4(p, '01-04', 'Отдельно выписать все площадки и каналы, которые курс требует создать по ходу обучения', 'Список каналов, которые появляются из заданий курса, а не из догадок', 15, 'channel'),
        _actionV4(p, '01-05', 'Создать короткий шаблон заметки для каждого урока: идея → действие → результат → где ещё применить', 'Один повторяемый шаблон конспекта урока', 15, 'playbook'),
        _actionV4(p, '01-06', 'Выбрать следующий непройденный урок строго по порядку курса', 'Однозначно выбран следующий урок', 5, 'learning'),
      ],
    ),
    _stageV4(
      p,
      '02',
      'Пройти курс последовательно, не откладывая задания на потом',
      'Все обязательные уроки курса пройдены, а у каждого практического задания есть реальный выполненный результат; нет хвоста «урок посмотрел, задание потом».',
      [
        _actionV4(p, '02-01', 'Пройти следующие 25 минут текущего непройденного урока FLOW', 'Следующий фрагмент урока реально просмотрен/изучен', 25, 'learning'),
        _actionV4(p, '02-02', 'Записать после текущего фрагмента 3–5 конкретных приёмов или правил, которые можно повторить', 'Короткий конспект без общих пересказов', 10, 'playbook'),
        _actionV4(p, '02-03', 'Определить ближайшее физическое действие из задания текущего урока', 'Одно конкретное следующее действие задания ≤30 минут', 10, 'course_assignment'),
        _actionV4(p, '02-04', 'Выполнить первые 30 минут ближайшего задания курса', 'Материальный прогресс по заданию: созданный аккаунт, текст, настройка, публикация или другой артефакт', 30, 'course_assignment'),
        _actionV4(p, '02-05', 'Сохранить ссылку, скриншот или другой результат выполненного задания и отметить его в конспекте урока', 'Проверяемое доказательство выполнения задания', 10, 'validation'),
        _actionV4(p, '02-06', 'После завершения урока обновить в Path следующий урок и ближайшее задание из фактического курса', 'Path продолжает реальную программу курса, а не шаблонные задачи', 10, 'learning'),
      ],
    ),
    _stageV4(
      p,
      '03',
      'Запустить собственные каналы именно по заданиям курса',
      'Все каналы, которые требуются заданиями пройденной части курса, реально созданы, оформлены до минимально рабочего состояния и в каждом выполнено первое действие/публикация, предусмотренное курсом.',
      [
        _actionV4(p, '03-01', 'Взять первый ещё не созданный канал из списка заданий курса и проверить требования к регистрации', 'Понятно, какие данные нужны для регистрации конкретного канала', 15, 'channel'),
        _actionV4(p, '03-02', 'Создать аккаунт/канал на первой требуемой курсом площадке', 'Реально существующий канал', 20, 'channel'),
        _actionV4(p, '03-03', 'Заполнить минимальный профиль канала: имя, описание, ссылка и аватар/обложка, если они требуются', 'Канал не выглядит пустой технической заготовкой', 25, 'channel'),
        _actionV4(p, '03-04', 'Выполнить первое контентное задание курса для этого канала', 'Готовый материал строго по текущему заданию', 30, 'content'),
        _actionV4(p, '03-05', 'Опубликовать материал и сохранить URL/идентификатор публикации', 'Первая реальная публикация в собственном канале', 15, 'channel'),
        _actionV4(p, '03-06', 'Повторить цикл для следующего канала только когда курс действительно требует его создать', 'Каналы появляются вслед за программой курса, без лишнего распыления', 10, 'course_assignment'),
      ],
    ),
    _stageV4(
      p,
      '04',
      'Выполнять следующие задания курса на живых каналах и смотреть фактический результат',
      'Задания выполняются на реально работающих каналах; для каждого теста сохранены публикация, действие аудитории и вывод, что повторять или менять.',
      [
        _actionV4(p, '04-01', 'Подготовить следующий материал или настройку, которую прямо требует текущий урок', 'Готовый результат текущего задания', 30, 'content'),
        _actionV4(p, '04-02', 'Опубликовать/включить результат задания на соответствующем живом канале', 'Задание находится в реальной среде, а не только в черновике', 15, 'channel'),
        _actionV4(p, '04-03', 'Записать доступный фактический результат задания: просмотры, переходы, подписки, ответы или другой показатель курса', 'Один результат без оценки «кажется, сработало»', 15, 'validation'),
        _actionV4(p, '04-04', 'Записать одним предложением, что из этого задания стоит повторить, изменить или не использовать', 'Одно практическое правило по результату теста', 10, 'playbook'),
      ],
    ),
    _stageV4(
      p,
      '05',
      'Собрать из курса личную базу навыков продвижения',
      'По пройденным модулям есть компактный playbook: конкретный приём, когда применять, пошаговое действие, пример из собственного канала и ограничения/условия, при которых он не сработал.',
      [
        _actionV4(p, '05-01', 'Выбрать один законченный модуль и выписать из него только применимые техники продвижения', 'Список практических техник одного модуля', 20, 'playbook'),
        _actionV4(p, '05-02', 'Для каждой техники записать, какую проблему она решает и на каком типе проекта применима', 'У каждой техники есть контекст применения', 20, 'playbook'),
        _actionV4(p, '05-03', 'Добавить к одной технике реальный пример из собственного канала FLOW', 'Техника привязана к фактическому выполнению, а не только теории', 15, 'playbook'),
        _actionV4(p, '05-04', 'Отметить один приём, который не дал ожидаемого результата, и условие, при котором его не стоит повторять', 'Playbook хранит не только успехи, но и ограничения', 15, 'validation'),
      ],
    ),
    _stageV4(
      p,
      '06',
      'Переносить освоенные навыки в продвижение реальных проектов',
      'Минимум один приём из FLOW применён в реальном продвижении каждого подходящего активного проекта, а результат сравнивается с исходной ситуацией; техники выбираются по задаче проекта, а не потому что они есть в курсе.',
      [
        _actionV4(p, '06-01', 'Выбрать один освоенный приём FLOW и один активный проект, где он решает реальную текущую проблему', 'Пара «приём → проект» с понятной причиной', 15, 'transfer'),
        _actionV4(p, '06-02', 'Разложить применение выбранного приёма в этом проекте на первое действие ≤30 минут', 'Конкретный перенос навыка в проект', 15, 'transfer'),
        _actionV4(p, '06-03', 'Выполнить первое действие применения приёма в выбранном проекте', 'Реальный артефакт/изменение в проекте', 30, 'transfer'),
        _actionV4(p, '06-04', 'После теста записать результат и решить, переносить ли этот приём в KADR, GOLOS, Игропоиск, IW17, RCC или другой проект', 'Решение о повторном использовании техники на основании результата', 15, 'validation'),
      ],
    ),
    _stageV4(
      p,
      '07',
      'Если курс ведёт к affiliate/реферальному доходу — пройти этот контур практически',
      'Если это предусмотрено программой курса, affiliate/реферальная механика настроена по заданиям, disclosure и получение выплат проверены; если курс этого не требует, этап явно отмечен как неприменимый и не подменяет основную цель FLOW.',
      [
        _actionV4(p, '07-01', 'Проверить в фактической программе курса, является ли affiliate/реферальная монетизация обязательным практическим заданием', 'Явное решение: требуется курсом / не требуется', 10, 'course_assignment'),
        _actionV4(p, '07-02', 'Если требуется, выписать точную партнёрскую программу и условия регистрации из урока', 'Конкретная программа и условия вместо абстрактного affiliate', 15, 'course_assignment'),
        _actionV4(p, '07-03', 'Если требуется, пройти доступную часть регистрации в партнёрской программе', 'Фактический статус регистрации и следующий шаг', 30, 'course_assignment'),
        _actionV4(p, '07-04', 'Если требуется, проверить disclosure и способ получения выплат до публикации реферальных материалов', 'Проверены обязательные правила и payout route', 20, 'validation'),
      ],
    ),
  ];
}

List<Map<String, dynamic>> _golosRealityAdditionsV4() {
  const p = 'golos-v4-';
  return <Map<String, dynamic>>[
    _stageV4(
      p,
      'offer',
      'Определить бесплатную и платную версии GOLOS до попытки продавать',
      'Записано, какие функции составляют полноценную бесплатную версию, за какую конкретную ценность платят, что входит в первую платную версию, какая модель оплаты и стартовая цена проверяются.',
      [
        _actionV4(p, 'offer-01', 'Выписать все функции текущей рабочей версии GOLOS без будущих идей', 'Фактический список функций', 20, 'product'),
        _actionV4(p, 'offer-02', 'Отметить функции, которые должны остаться бесплатными, чтобы бесплатная версия решала основную задачу диктовки', 'Черновой состав бесплатной версии', 20, 'offer'),
        _actionV4(p, 'offer-03', 'Выписать три причины, за которые пользователь мог бы платить: экономия времени, качество или дополнительный сценарий', 'Три проверяемые гипотезы платной ценности', 20, 'offer'),
        _actionV4(p, 'offer-04', 'Выбрать первую платную комплектацию максимум из трёх преимуществ', 'Одна версия Pro для проверки', 15, 'offer'),
        _actionV4(p, 'offer-05', 'Выбрать первую модель оплаты и стартовую цену для теста', 'Конкретная модель оплаты и цена', 15, 'payments'),
      ],
    ),
    _stageV4(
      p,
      'website',
      'Сделать сайт GOLOS, через который продукт можно понять, скачать и купить',
      'Работает домен и сайт с объяснением продукта, download, Free/Pro, ценой, документами и поддержкой; ссылки проверены как новый пользователь.',
      [
        _actionV4(p, 'website-01', 'Выбрать домен GOLOS и проверить доступность', 'Выбранный доступный домен', 20, 'website'),
        _actionV4(p, 'website-02', 'Записать структуру сайта: главная, скачать, цены, вопросы, документы, поддержка', 'Карта страниц сайта', 15, 'website'),
        _actionV4(p, 'website-03', 'Выбрать технологию и размещение сайта без лишней инфраструктуры', 'Один способ публикации сайта', 20, 'website'),
        _actionV4(p, 'website-04', 'Опубликовать минимальную главную страницу с рабочей ссылкой скачивания', 'Публичная страница GOLOS', 30, 'website'),
        _actionV4(p, 'website-05', 'Добавить на сайт блок Free/Pro и место для checkout', 'Пользователь понимает разницу бесплатной и платной версий', 25, 'website'),
      ],
    ),
    _stageV4(
      p,
      'license-support',
      'Довести оплату, лицензию и поддержку до полного пользовательского пути',
      'Тестовая покупка выдаёт платный доступ, восстановление покупки и возврат проверены, а пользователь знает куда писать и как получить следующую версию.',
      [
        _actionV4(p, 'license-01', 'Создать товар и тестовую цену в выбранной платёжной системе', 'Тестовый товар GOLOS существует у продавца', 20, 'payments'),
        _actionV4(p, 'license-02', 'Записать техническую связь «успешная оплата → платный доступ в GOLOS» и разбить её на действия ≤30 минут', 'Исполнимый подплан лицензирования', 30, 'licensing'),
        _actionV4(p, 'license-03', 'Проверить восстановление платного доступа после переустановки/нового устройства', 'Проверенный restore flow или конкретный blocker', 20, 'licensing'),
        _actionV4(p, 'license-04', 'Выбрать один адрес/форму поддержки и добавить его в приложение и сайт', 'Один рабочий support entry point', 15, 'support'),
        _actionV4(p, 'license-05', 'Записать порядок выпуска новой версии: сборка → проверка → подпись → публикация → заметка', 'Повторяемый release process', 20, 'operations'),
      ],
    ),
  ];
}

List<Map<String, dynamic>> _rulersWebsiteAdditionsV4() {
  const p = 'rulers-v4-';
  return <Map<String, dynamic>>[
    _stageV4(
      p,
      'website',
      'Физически запустить сайт «Правители России», а не только спроектировать контент',
      'Выбран и подключён домен, сайт опубликован на реальном хостинге по HTTPS, есть повторяемый deploy/backup и подключены базовые источники поисковой аналитики.',
      [
        _actionV4(p, 'website-01', 'Составить пять вариантов домена и проверить доступность', 'Список доступных доменов', 20, 'website'),
        _actionV4(p, 'website-02', 'Выбрать домен и место регистрации', 'Один выбранный домен и регистратор', 15, 'website'),
        _actionV4(p, 'website-03', 'Выбрать технологию и хостинг первого сайта', 'Один конкретный способ публикации', 20, 'website'),
        _actionV4(p, 'website-04', 'Опубликовать пустой технический shell сайта на выбранном хостинге', 'Реальный публичный URL сайта', 30, 'website'),
        _actionV4(p, 'website-05', 'Подключить домен и проверить HTTPS', 'Сайт открывается по основному домену без предупреждений', 20, 'website'),
        _actionV4(p, 'website-06', 'Записать и проверить один способ резервного копирования/восстановления сайта', 'Понятный backup/restore route', 20, 'operations'),
        _actionV4(p, 'website-07', 'Подключить Search Console/Яндекс Вебмастер или соответствующие источники индексации', 'Сайт добавлен минимум в один реальный search-data источник', 20, 'seo'),
      ],
    ),
  ];
}

Map<String, dynamic> _projectPlanApprovalStageV5() => _stageV4(
  'approval-v5-',
  'gate',
  'Согласовать план проекта',
  'Мы вместе прошли цель, последовательность этапов, конкретные действия и слепые зоны; все замечания внесены, после чего пользователь явно подтвердил, что эту версию плана можно использовать для дальнейшего планирования.',
  [
    _actionV4(
      'approval-v5-',
      'review',
      'Согласовать со мной текущий план проекта: пройти цель, этапы, действия и возможные слепые зоны',
      'Либо подтверждённая рабочая версия плана, либо конкретный список правок, после которых согласование продолжается',
      30,
      'strategy',
    ),
  ],
);

bool _hasProjectPlanApprovalGateV5(PlanningTask root) =>
    root.checklist.isNotEmpty &&
    (root.checklist.first['id'] ?? '').toString() ==
        _projectPlanApprovalStageIdV5;

bool _projectPlanApprovedV5(PlanningTask root) =>
    _hasProjectPlanApprovalGateV5(root) && root.checklist.first['isDone'] == true;

List<PlanningTask> _canonicalActivePathRootsV6(
  Iterable<PlanningTask> roots,
) {
  final byCategory = <int, PlanningTask>{};
  for (final root in roots) {
    if ((root.notesPlain ?? '').trim() != _activePathMarkerV4) continue;
    final current = byCategory[root.categoryId];
    if (current == null) {
      byCategory[root.categoryId] = root;
      continue;
    }
    final currentAt = current.updatedAt ?? current.createdAt;
    final candidateAt = root.updatedAt ?? root.createdAt;
    if (currentAt == null && candidateAt != null) {
      byCategory[root.categoryId] = root;
      continue;
    }
    if (currentAt != null &&
        candidateAt != null &&
        candidateAt.isAfter(currentAt)) {
      byCategory[root.categoryId] = root;
      continue;
    }
    if (currentAt == candidateAt &&
        root.planRowIdForBackend.compareTo(current.planRowIdForBackend) > 0) {
      byCategory[root.categoryId] = root;
    }
  }
  return byCategory.values.toList();
}

List<Map<String, dynamic>> _moneyManagementPathV5() {
  const p = 'money-v5-';
  return <Map<String, dynamic>>[
    _stageV4(
      p,
      'baseline',
      'Собрать фактическую картину личных денег',
      'В ZenMoney и LIFE OS есть проверенная картина доходов и расходов минимум за последние 3 полных месяца, доход разбит по источникам, отдельно видны фактические выплаты Price Reporter и бонусы, рассчитан средний месячный доход и разрыв до 600 000 ₽.',
      [
        _actionV4(p, 'baseline-01', 'Открыть ZenMoney и разобрать первые 15 минут неразнесённых операций', 'Меньше неразнесённых операций; исправленные категории сохранены', 15, 'operations'),
        _actionV4(p, 'baseline-02', 'Выписать все источники дохода, по которым были реальные поступления за последние 3 полных месяца', 'Список фактических источников дохода, а не потенциальных проектов', 20, 'finance'),
        _actionV4(p, 'baseline-03', 'Выписать фактические поступления Price Reporter по месяцам, отдельно фиксированную часть и полученные бонусы', 'Таблица фактических выплат Price Reporter по месяцам', 25, 'finance'),
        _actionV4(p, 'baseline-04', 'Выписать фактические поступления Atozed и остальных источников по тем же месяцам', 'Сопоставимая таблица остальных доходов', 25, 'finance'),
        _actionV4(p, 'baseline-05', 'Выписать общие расходы за те же 3 месяца из ZenMoney без попытки оптимизировать их', 'Три фактических месячных значения расходов', 15, 'finance'),
        _actionV4(p, 'baseline-06', 'Посчитать средний фактический месячный доход и разрыв до 600 000 ₽', 'Одно текущее число среднего дохода и одно число разрыва до цели', 15, 'validation'),
      ],
    ),
    _stageV4(
      p,
      'review',
      'Сделать денежную картину регулярно обновляемой',
      'Есть короткая повторяемая процедура: разнести операции, проверить поступления по источникам, обновить средний доход/расход и разрыв до 600 000 ₽ без ручного пересчёта с нуля.',
      [
        _actionV4(p, 'review-01', 'Записать пятишаговый еженедельный порядок проверки ZenMoney', 'Короткий денежный review, который можно превратить в повторяющийся план', 15, 'operations'),
        _actionV4(p, 'review-02', 'Определить, какие итоговые цифры LIFE OS должен читать из ZenMoney или получать вручную', 'Минимальный набор финансовых показателей LIFE OS без копирования бухгалтерии', 20, 'operations'),
        _actionV4(p, 'review-03', 'Проверить процедуру на одном фактическом обновлении и записать, что пришлось считать вручную', 'Список оставшихся ручных операций для будущей автоматизации', 20, 'validation'),
      ],
    ),
  ];
}

Future<CategoryRule?> _ensureMoneyManagementCategoryV5() async {
  final existing = _findCategoryByAliasesV4(const [
    'Управление деньгами / ZenMoney',
    'Управление деньгами',
    'ZenMoney',
    'Zen Money',
  ]);
  if (existing != null) return existing;

  final db = DatabaseService.instance;
  final status = db.classifyCategoryDisplayNameInput('Управление деньгами / ZenMoney');
  if (status.activeLocalId != null) {
    return db.getCategoryRuleById(status.activeLocalId!);
  }
  if (status.archivedPbRowId != null) {
    final restored = await db.restoreArchivedCategory(status.archivedPbRowId!);
    if (restored != null) return db.getCategoryRuleById(restored);
  }
  final created = await db.addNestedCategory(
    null,
    CategoryRule(
      id: db.newId(),
      name: 'Управление деньгами / ZenMoney',
      colorValue: 0xFF2E7D32,
      iconCodePoint: 0xe263,
      isSynced: false,
    ),
  );
  if (created == null) return null;
  await db.refreshCategoryRulesFromServer();
  return _findCategoryByAliasesV4(const [
    'Управление деньгами / ZenMoney',
    'Управление деньгами',
    'ZenMoney',
    'Zen Money',
  ]);
}

Future<void> _ensureMoneyManagementPathV5() async {
  final category = await _ensureMoneyManagementCategoryV5();
  if (category == null) return;
  final root = await _activePathForCategoryV4(category.id);
  if (root != null) return;
  final order = await DatabaseService.instance.nextBacklogPlanningOrder();
  await DatabaseService.instance.addPlanningTask(
    PlanningTask(
      id: 0,
      title: 'Поддерживать актуальную картину личных денег и управлять движением к 600 000 ₽ в месяц на основании фактических данных ZenMoney и реальных поступлений по каждому источнику.',
      categoryId: category.id,
      isDone: true,
      dateKey: '',
      order: order,
      checklist: _moneyManagementPathV5(),
      notesPlain: _activePathMarkerV4,
      isSynced: false,
    ),
  );
}

Future<void> _ensureProjectPlanApprovalGatesV5() async {
  final db = DatabaseService.instance;
  final roots = _canonicalActivePathRootsV6(
    await db.fetchBacklogPlans(includeCompleted: true),
  );
  for (final root in roots) {
    if (_hasProjectPlanApprovalGateV5(root)) continue;
    final checklist = <Map<String, dynamic>>[
      _projectPlanApprovalStageV5(),
      ...root.checklist.map((e) => Map<String, dynamic>.from(e)),
    ];
    final ok = await db.updatePlanningTask(
      root.planRowIdForBackend,
      planBusinessId: root.planRowId,
      title: root.title,
      categoryId: root.categoryId,
      isDone: true,
      notesPlain: _activePathMarkerV4,
      checklist: checklist,
      suppressAppSnack: true,
    );
    if (!ok) throw StateError('Could not add plan approval gate to category ${root.categoryId}');
  }
}

bool _checklistHasPrefixV4(List<Map<String, dynamic>> checklist, String prefix) =>
    checklist.any((row) => (row['id'] ?? '').toString().startsWith(prefix));

Future<PlanningTask?> _activePathForCategoryV4(int categoryId) async {
  final tasks = await DatabaseService.instance.fetchBacklogPlans(
    categoryId: categoryId,
    includeCompleted: true,
  );
  PlanningTask? best;
  for (final task in tasks) {
    if ((task.notesPlain ?? '').trim() != _activePathMarkerV4) continue;
    if (best == null) {
      best = task;
      continue;
    }
    final a = best.updatedAt ?? best.createdAt;
    final b = task.updatedAt ?? task.createdAt;
    if (a == null || (b != null && b.isAfter(a))) best = task;
  }
  return best;
}

Future<void> _replacePathV4({
  required CategoryRule category,
  required String goal,
  required List<Map<String, dynamic>> checklist,
}) async {
  final db = DatabaseService.instance;
  final tasks = await db.fetchBacklogPlans(
    categoryId: category.id,
    includeCompleted: true,
  );
  for (final task in tasks) {
    if ((task.notesPlain ?? '').trim() != _activePathMarkerV4) continue;
    final ok = await db.updatePlanningTask(
      task.planRowIdForBackend,
      planBusinessId: task.planRowId,
      title: task.title,
      categoryId: task.categoryId,
      isDone: true,
      notesPlain: _retiredPathMarkerV4,
      checklist: task.checklist,
      suppressAppSnack: true,
    );
    if (!ok) throw StateError('Could not preserve previous Path for ${category.name}');
  }
  final order = await db.nextBacklogPlanningOrder();
  final created = await db.addPlanningTask(
    PlanningTask(
      id: 0,
      title: goal,
      categoryId: category.id,
      isDone: true,
      dateKey: '',
      order: order,
      checklist: checklist,
      notesPlain: _activePathMarkerV4,
      isSynced: false,
    ),
  );
  if (!created) throw StateError('Could not create revised Path for ${category.name}');
}

Future<void> _detachPriceReporterMoneyWorkV5() async {
  final category = _findCategoryByAliasesV4(const ['Price Reporter']);
  if (category == null) return;
  final root = await _activePathForCategoryV4(category.id);
  if (root == null) return;

  var changed = false;
  final next = <Map<String, dynamic>>[];
  for (final rawStage in root.checklist) {
    final stage = Map<String, dynamic>.from(rawStage);
    final id = (stage['id'] ?? '').toString();
    final actions = _pathActionsFromStageRawV4(stage);

    if (id == 'exec-pricereporter-stage-1') {
      stage['text'] = 'Зафиксировать фактическую рабочую нагрузку и критичные виды работы';
      stage['definitionOfDone'] =
          'Есть наблюдение реального рабочего дня и список основных повторяющихся/критичных типов работы; расчёты выплат и среднего дохода ведутся отдельно в «Управление деньгами / ZenMoney».';
      final kept = <Map<String, dynamic>>[
        for (final action in actions)
          if ((action['track'] ?? '').toString() != 'finance') action,
      ];
      if (!kept.any((a) => (a['id'] ?? '').toString() == 'pr-v5-work-types')) {
        kept.add(_actionV4(
          'pr-v5-',
          'work-types',
          'Выписать пять основных типов работы Price Reporter, которые регулярно занимают время или несут compliance-риск',
          'Список 5 рабочих типов с понятной ролью в нагрузке',
          15,
          'operations',
        ));
      }
      stage['actions'] = kept;
      changed = true;
    } else if (id == 'exec-pricereporter-stage-4') {
      stage['text'] = 'Снизить операционную уязвимость Price Reporter';
      stage['definitionOfDone'] =
          'Критические рабочие процессы документированы так, чтобы отпуск, болезнь или передача части рутины не создавали compliance/continuity риска; финансовый порог зависимости ведётся в ZenMoney-проекте.';
      stage['actions'] = <Map<String, dynamic>>[
        for (final action in actions)
          if ((action['track'] ?? '').toString() != 'finance') action,
      ];
      changed = true;
    }
    next.add(stage);
  }

  if (!changed) return;
  final ok = await DatabaseService.instance.updatePlanningTask(
    root.planRowIdForBackend,
    planBusinessId: root.planRowId,
    title: root.title,
    categoryId: root.categoryId,
    isDone: true,
    notesPlain: _activePathMarkerV4,
    checklist: next,
    suppressAppSnack: true,
  );
  if (!ok) throw StateError('Could not detach Price Reporter money work');
}

Future<void> upgradeRealityPathsV4() async {
  final db = DatabaseService.instance;
  await db.refreshCategoryRulesFromServer();
  await ensureDailyRoutineV6();

  final flow = _findCategoryByAliasesV4(const ['FLOW', 'Flow']);
  if (flow != null) {
    final root = await _activePathForCategoryV4(flow.id);
    if (root == null || !_checklistHasPrefixV4(root.checklist, 'flow-v4-')) {
      await _replacePathV4(
        category: flow,
        goal:
            'Полностью пройти курс FLOW, по ходу курса выполнять задания на собственных живых каналах и превратить полученные навыки в практический набор инструментов продвижения для KADR, GOLOS, Игропоиск, IW17, RCC и других проектов.',
        checklist: _flowLearningPathV4(),
      );
    }
  }

  final golos = _findCategoryByAliasesV4(const ['GOLOS', 'Golos', 'Голос']);
  if (golos != null) {
    final root = await _activePathForCategoryV4(golos.id);
    if (root != null && !_checklistHasPrefixV4(root.checklist, 'golos-v4-')) {
      final next = <Map<String, dynamic>>[
        ...root.checklist.map((e) => Map<String, dynamic>.from(e)),
        ..._golosRealityAdditionsV4(),
      ];
      final ok = await db.updatePlanningTask(
        root.planRowIdForBackend,
        planBusinessId: root.planRowId,
        title: root.title,
        categoryId: root.categoryId,
        isDone: true,
        notesPlain: _activePathMarkerV4,
        checklist: next,
        suppressAppSnack: true,
      );
      if (!ok) throw StateError('Could not extend GOLOS Path');
    }
  }

  final rulers = _findCategoryByAliasesV4(const [
    'Правители России',
    'Rulers of Russia',
    'Praviteli Rossii',
  ]);
  if (rulers != null) {
    final root = await _activePathForCategoryV4(rulers.id);
    if (root != null && !_checklistHasPrefixV4(root.checklist, 'rulers-v4-')) {
      final next = <Map<String, dynamic>>[
        ...root.checklist.map((e) => Map<String, dynamic>.from(e)),
        ..._rulersWebsiteAdditionsV4(),
      ];
      final ok = await db.updatePlanningTask(
        root.planRowIdForBackend,
        planBusinessId: root.planRowId,
        title: root.title,
        categoryId: root.categoryId,
        isDone: true,
        notesPlain: _activePathMarkerV4,
        checklist: next,
        suppressAppSnack: true,
      );
      if (!ok) throw StateError('Could not extend Rulers Path');
    }
  }

  await _ensureMoneyManagementPathV5();
  await _detachPriceReporterMoneyWorkV5();
  await _ensureProjectPlanApprovalGatesV5();
}

String _weekKeyV4(DateTime monday) =>
    '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';

DateTime _mondayOfV4(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

String _dateKeyV4(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _roundUp5V4(DateTime dt) {
  final extra = (5 - dt.minute % 5) % 5;
  var out = dt.add(Duration(minutes: extra));
  out = DateTime(out.year, out.month, out.day, out.hour, out.minute);
  return out;
}

bool _rawPlanDoneV4(Map<String, dynamic> row) {
  final v = row['is_done'] ?? row['isDone'];
  if (v is bool) return v;
  return v?.toString().toLowerCase() == 'true' || v?.toString() == '1';
}

Future<int> _reconcileCompletedPathActionsV4(
  List<PlanningTask> roots,
  List<Map<String, dynamic>> allPlans,
) async {
  final doneMarkers = <String>{};
  for (final row in allPlans) {
    if (!_rawPlanDoneV4(row)) continue;
    final notes = (row['notes_plain'] ?? row['notesPlain'] ?? '').toString();
    final firstLine = notes.split('\n').first.trim();
    if (firstLine.startsWith(_pathActionPlanMarkerV4)) {
      doneMarkers.add(firstLine);
    }
  }
  if (doneMarkers.isEmpty) return 0;

  var reconciled = 0;
  final db = DatabaseService.instance;
  for (final root in roots) {
    final rootId = (root.pocketRecordId ?? root.planRowIdForBackend).trim();
    if (rootId.isEmpty) continue;
    var changed = false;
    final checklist = <Map<String, dynamic>>[];
    for (final rawStage in root.checklist) {
      final stage = Map<String, dynamic>.from(rawStage);
      final stageId = (stage['id'] ?? '').toString();
      final rawActions = _pathActionsFromStageRawV4(stage);
      final nextActions = <Map<String, dynamic>>[];
      for (final rawAction in rawActions) {
        final action = Map<String, dynamic>.from(rawAction);
        final actionId = (action['id'] ?? '').toString();
        final marker = '$_pathActionPlanMarkerV4$rootId|$stageId|$actionId';
        if (doneMarkers.contains(marker) && action['isDone'] != true) {
          action['isDone'] = true;
          changed = true;
          reconciled++;
        }
        nextActions.add(action);
      }
      if (rawStage['actions'] is List) stage['actions'] = nextActions;
      checklist.add(stage);
    }
    if (changed) {
      await db.updatePlanningTask(
        root.planRowIdForBackend,
        planBusinessId: root.planRowId,
        title: root.title,
        categoryId: root.categoryId,
        isDone: true,
        notesPlain: _activePathMarkerV4,
        checklist: checklist,
        suppressAppSnack: true,
      );
    }
  }
  return reconciled;
}

class _WeekActionCandidateV4 {
  const _WeekActionCandidateV4({
    required this.profile,
    required this.category,
    required this.root,
    required this.stageId,
    required this.actionId,
    required this.text,
    required this.result,
    required this.minutes,
  });

  final _PathAuditProfileV4 profile;
  final CategoryRule category;
  final PlanningTask root;
  final String stageId;
  final String actionId;
  final String text;
  final String result;
  final int minutes;
}

List<_WeekActionCandidateV4> _currentActionsForRootV4(
  _PathAuditProfileV4 profile,
  CategoryRule category,
  PlanningTask root,
) {
  var targetStage = _projectPlanApprovedV5(root)
      ? profile.planningStageIndex
      : 0;
  if (targetStage == null) {
    for (var i = 0; i < root.checklist.length; i++) {
      if (root.checklist[i]['isDone'] != true) {
        targetStage = i;
        break;
      }
    }
  }
  if (targetStage == null || targetStage < 0 || targetStage >= root.checklist.length) {
    return const <_WeekActionCandidateV4>[];
  }
  final stage = root.checklist[targetStage];
  final stageId = (stage['id'] ?? 'stage-$targetStage').toString();
  final out = <_WeekActionCandidateV4>[];
  for (var ai = 0; ai < _pathActionsFromStageRawV4(stage).length; ai++) {
    final action = _pathActionsFromStageRawV4(stage)[ai];
    if (action['isDone'] == true) continue;
    final rawMinutes = action['minutes'];
    final minutes = rawMinutes is int
        ? rawMinutes
        : int.tryParse(rawMinutes?.toString() ?? '') ?? 0;
    if (minutes < 1 || minutes > 30) continue;
    out.add(
      _WeekActionCandidateV4(
        profile: profile,
        category: category,
        root: root,
        stageId: stageId,
        actionId: (action['id'] ?? 'action-$ai').toString(),
        text: (action['text'] ?? '').toString().trim(),
        result: (action['result'] ?? '').toString().trim(),
        minutes: minutes,
      ),
    );
  }
  return out;
}

DateTime? _firstFreeProjectSlotV5(
  DatabaseService db, {
  required DateTime earliest,
  required int minutes,
  required DateTime latestEnd,
  required List<PlanningTask> existing,
}) {
  var candidate = _roundUp5V4(earliest);
  final busy = <(DateTime, DateTime)>[];
  for (final task in existing) {
    final rawStart = task.startTime;
    if (rawStart == null) continue;
    final start = rawStart;
    if (start.year != candidate.year ||
        start.month != candidate.month ||
        start.day != candidate.day) {
      continue;
    }
    final rawEnd = task.endDateTime;
    final end = rawEnd == null
        ? start.add(const Duration(minutes: 30))
        : rawEnd;
    if (!end.isAfter(start)) continue;
    busy.add((start, end));
  }
  busy.sort((a, b) => a.$1.compareTo(b.$1));

  for (final interval in busy) {
    if (!interval.$2.isAfter(candidate)) continue;
    final requestedEnd = candidate.add(Duration(minutes: minutes));
    if (!requestedEnd.isAfter(interval.$1)) {
      return requestedEnd.isAfter(latestEnd) ? null : candidate;
    }
    candidate = _roundUp5V4(interval.$2);
    if (candidate.add(Duration(minutes: minutes)).isAfter(latestEnd)) {
      return null;
    }
  }
  return candidate.add(Duration(minutes: minutes)).isAfter(latestEnd)
      ? null
      : candidate;
}

Future<bool> _createScheduledTaskV4({
  required CategoryRule category,
  required String title,
  required String notes,
  required DateTime start,
  required int minutes,
  String? clientPlanId,
}) async {
  final db = DatabaseService.instance;
  final wallDay = DateTime(start.year, start.month, start.day);
  final existing = await db.getPlanningTasksForWallDate(wallDay);
  final schedule = db.resolveAutoPlanSchedule(
    wallDay: wallDay,
    categoryId: category.id,
    tags: const <Tag>[],
    existingDayPlans: existing,
    explicitStartWall: start,
    explicitDurationMinutes: minutes,
  );
  final task = db.planningTaskWithAutoSchedule(
    PlanningTask(
      id: 0,
      title: title,
      categoryId: category.id,
      isDone: false,
      dateKey: _dateKeyV4(wallDay),
      order: await db.nextPlanningOrderForDate(wallDay),
      notesPlain: notes,
      isSynced: false,
    ),
    schedule,
  );
  return db.addPlanningTask(task, clientPlanId: clientPlanId);
}

Future<void> _removeSupersededWeekRoutinesV5() async {
  final db = DatabaseService.instance;
  final today = db.getTimelineDeviceLocalToday();
  final monday = _mondayOfV4(today);
  final ids = <String>{};
  for (var i = 0; i < 7; i++) {
    final day = monday.add(Duration(days: i));
    final tasks = await db.getPlanningTasksForWallDate(day);
    for (final task in tasks) {
      final notes = (task.notesPlain ?? '').trim();
      if (!notes.startsWith(_weekRoutinePlanMarkerV4)) continue;
      final id = task.planRowIdForBackend.trim();
      if (id.isEmpty || id.startsWith('virt-') || id.startsWith('optimistic-')) {
        continue;
      }
      ids.add(id);
    }
  }
  if (ids.isNotEmpty) {
    await db.deletePlanningTasksBulk(ids);
  }
}

Future<void> _removePrematurePathActionsV5() async {
  final db = DatabaseService.instance;
  final roots = _canonicalActivePathRootsV6(
    await db.fetchBacklogPlans(includeCompleted: true),
  );
  final approvalByRootId = <String, bool>{};
  for (final root in roots) {
    final rootId = (root.pocketRecordId ?? root.planRowIdForBackend).trim();
    if (rootId.isEmpty) continue;
    approvalByRootId[rootId] = _projectPlanApprovedV5(root);
  }

  final today = db.getTimelineDeviceLocalToday();
  final monday = _mondayOfV4(today);
  final ids = <String>{};
  for (var i = 0; i < 7; i++) {
    final day = monday.add(Duration(days: i));
    final tasks = await db.getPlanningTasksForWallDate(day);
    for (final task in tasks) {
      if (task.isDone) continue;
      final firstLine = (task.notesPlain ?? '').split('\n').first.trim();
      if (!firstLine.startsWith(_pathActionPlanMarkerV4)) continue;
      final payload = firstLine.substring(_pathActionPlanMarkerV4.length);
      final parts = payload.split('|');
      if (parts.length < 3) continue;
      final rootId = parts[0].trim();
      final stageId = parts[1].trim();
      if (stageId.startsWith('approval-v5-')) continue;
      if (approvalByRootId[rootId] == true) continue;
      final id = task.planRowIdForBackend.trim();
      if (id.isEmpty || id.startsWith('virt-') || id.startsWith('optimistic-')) {
        continue;
      }
      ids.add(id);
    }
  }
  if (ids.isNotEmpty) {
    await db.deletePlanningTasksBulk(ids);
  }
}


List<String>? _pathMarkerPartsV7(PlanningTask task) {
  final firstLine = (task.notesPlain ?? '').split('\n').first.trim();
  if (!firstLine.startsWith(_pathActionPlanMarkerV4)) return null;
  final parts = firstLine
      .substring(_pathActionPlanMarkerV4.length)
      .split('|')
      .map((e) => e.trim())
      .toList(growable: false);
  return parts.length >= 3 ? parts : null;
}

String _normalizeApprovalTitleV7(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');

bool _isApprovalPlannerTaskV6(PlanningTask task) {
  final parts = _pathMarkerPartsV7(task);
  if (parts == null) return false;
  if (parts[1] == _projectPlanApprovalStageIdV5 &&
      parts[2] == _projectPlanApprovalActionIdV5) {
    return true;
  }
  final normalizedTitle = _normalizeApprovalTitleV7(task.title);
  return normalizedTitle.endsWith('согласоватьпланпроекта') ||
      normalizedTitle.endsWith('approveprojectplan');
}

Future<Set<int>> _currentWeekApprovalCategoryIdsV7() async {
  final db = DatabaseService.instance;
  final today = db.getTimelineDeviceLocalToday();
  final monday = _mondayOfV4(today);
  final categories = <int>{};
  for (var i = 0; i < 7; i++) {
    final tasks = await db.getPlanningTasksForWallDate(
      monday.add(Duration(days: i)),
    );
    for (final task in tasks) {
      if (!task.isDone && _isApprovalPlannerTaskV6(task)) {
        categories.add(task.categoryId);
      }
    }
  }
  return categories;
}

Future<void> _migrateLegacyApprovalDuplicatesV7() async {
  final db = DatabaseService.instance;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_plannerBaselineMigrationV7) == true) return;

  final roots = _canonicalActivePathRootsV6(
    await db.fetchBacklogPlans(includeCompleted: true),
  );
  final canonicalRootByCategory = <int, String>{
    for (final root in roots)
      root.categoryId:
          (root.pocketRecordId ?? root.planRowIdForBackend).trim(),
  };

  final today = db.getTimelineDeviceLocalToday();
  final monday = _mondayOfV4(today);
  final byCategory = <int, List<PlanningTask>>{};
  for (var i = 0; i < 7; i++) {
    final tasks = await db.getPlanningTasksForWallDate(
      monday.add(Duration(days: i)),
    );
    for (final task in tasks) {
      if (task.isDone || !_isApprovalPlannerTaskV6(task)) continue;
      byCategory.putIfAbsent(task.categoryId, () => <PlanningTask>[]).add(task);
    }
  }

  for (final entry in byCategory.entries) {
    final tasks = entry.value;
    if (tasks.isEmpty) continue;
    final canonicalRootId = canonicalRootByCategory[entry.key] ?? '';
    tasks.sort((a, b) {
      int rank(PlanningTask task) {
        final parts = _pathMarkerPartsV7(task);
        if (parts != null && parts[0] == canonicalRootId) return 0;
        return 1;
      }
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final at = a.startTime;
      final bt = b.startTime;
      if (at != null && bt != null) {
        final byTime = at.compareTo(bt);
        if (byTime != 0) return byTime;
      }
      return a.planRowIdForBackend.compareTo(b.planRowIdForBackend);
    });

    final keep = tasks.first;
    final deleteIds = <String>{
      for (final duplicate in tasks.skip(1))
        if (duplicate.planRowIdForBackend.trim().isNotEmpty &&
            !duplicate.planRowIdForBackend.startsWith('virt-') &&
            !duplicate.planRowIdForBackend.startsWith('optimistic-'))
          duplicate.planRowIdForBackend.trim(),
    };
    if (deleteIds.isNotEmpty) {
      await db.deletePlanningTasksBulk(deleteIds);
    }

    final parts = _pathMarkerPartsV7(keep);
    if (parts != null && parts[0].isNotEmpty) {
      final deterministicPlanId = _pathActionBusinessIdV7(
        rootId: parts[0],
        stageId: parts[1],
        actionId: parts[2],
      );
      if ((keep.planRowId ?? '').trim() != deterministicPlanId) {
        await db.updatePlanningTask(
          keep.planRowIdForBackend,
          planBusinessId: deterministicPlanId,
          suppressAppSnack: true,
        );
      }
    }
  }

  await prefs.setBool(_plannerBaselineMigrationV7, true);
}

/// Startup baseline only: ensure recurring routine and migrate old broken
/// generated rows. It does not schedule new project work.
Future<void> ensurePlannerBaselineV7() async {
  final db = DatabaseService.instance;
  await db.refreshCategoryRulesFromServer();
  await ensureDailyRoutineV6();
  await _removeSupersededWeekRoutinesV5();
  await _migrateLegacyApprovalDuplicatesV7();
}


Future<PathWeekPlanReportV4> planCurrentWeekFromPathsV4() async {
  final db = DatabaseService.instance;
  await upgradeRealityPathsV4();
  await _removeSupersededWeekRoutinesV5();
  final existingApprovalCategoryIds =
      await _currentWeekApprovalCategoryIdsV7();
  await _removePrematurePathActionsV5();

  final backlog = await db.fetchBacklogPlans(includeCompleted: true);
  final roots = _canonicalActivePathRootsV6(backlog);
  var allPlans = await db.fetchPlans();
  final reconciled = await _reconcileCompletedPathActionsV4(roots, allPlans);
  if (reconciled > 0) {
    allPlans = await db.fetchPlans();
  }

  final existingMarkers = <String>{};
  final existingBusinessIds = <String>{};
  final existingTitlesByDate = <String, Set<String>>{};
  for (final row in allPlans) {
    final businessId = (row['plan_id'] ?? '').toString().trim();
    if (businessId.isNotEmpty) existingBusinessIds.add(businessId);
    final notes = (row['notes_plain'] ?? row['notesPlain'] ?? '').toString();
    final firstLine = notes.split('\n').first.trim();
    if (firstLine.startsWith(_pathActionPlanMarkerV4) ||
        firstLine.startsWith(_weekRoutinePlanMarkerV4)) {
      existingMarkers.add(firstLine);
    }
    final title = (row['title'] ?? '').toString().trim().toLowerCase();
    final start = (row['start_time'] ?? row['startTime'])?.toString() ?? '';
    final parsedUtc = DateTime.tryParse(start);
    final dt = parsedUtc == null ? null : db.applyUserOffset(parsedUtc.toUtc());
    if (title.isNotEmpty && dt != null) {
      existingTitlesByDate.putIfAbsent(_dateKeyV4(dt), () => <String>{}).add(title);
    }
  }

  final categoriesById = <int, CategoryRule>{};
  for (final pair in db.allCategoryIdPathPairs) {
    final rule = db.getCategoryRuleById(pair.id);
    if (rule != null && !rule.isArchived) categoriesById[rule.id] = rule;
  }

  final blocked = <String>[];
  var auditedProjects = 0;
  final pools = <_PathAuditProfileV4, List<_WeekActionCandidateV4>>{};
  for (final root in roots) {
    final category = categoriesById[root.categoryId];
    if (category == null) continue;
    final profile = _profileForProjectV4(category.name);
    if (profile == null) continue;
    final audit = auditExecutableProjectPathV4(category, root);
    if (!_projectPlanApprovedV5(root)) {
      // Until the user explicitly checks the first stage as agreed, the only
      // permissible Path-derived task is the approval review itself. Price
      // Reporter stays user-planned and is never auto-scheduled here.
      if (profile.name != 'Price Reporter') {
        pools[profile] = _currentActionsForRootV4(profile, category, root);
      }
      blocked.add('${profile.name}: план не согласован');
      continue;
    }
    if (!audit.audited) {
      blocked.add(profile.name);
      continue;
    }
    auditedProjects++;
    if (profile.weeklyMinutes <= 0) continue;
    pools[profile] = _currentActionsForRootV4(profile, category, root);
  }

  final today = db.getTimelineDeviceLocalToday();
  final monday = _mondayOfV4(today);
  final weekdays = <DateTime>[
    for (var i = 0; i < 5; i++) monday.add(Duration(days: i)),
  ].where((d) => !d.isBefore(DateTime(today.year, today.month, today.day))).toList();
  if (weekdays.isEmpty) {
    return PathWeekPlanReportV4(
      createdTasks: 0,
      reconciledActions: reconciled,
      auditedProjects: auditedProjects,
      blockedProjects: blocked,
    );
  }

  var created = 0;
  final now = db.applyUserOffset(DateTime.now().toUtc());

  final dayCursor = <String, DateTime>{};
  for (final day in weekdays) {
    var start = DateTime(day.year, day.month, day.day, 9);
    if (day.year == today.year && day.month == today.month && day.day == today.day) {
      final rounded = _roundUp5V4(now.add(const Duration(minutes: 10)));
      if (rounded.isAfter(start)) start = rounded;
    }
    dayCursor[_dateKeyV4(day)] = start;
  }

  final remainingBudget = <_PathAuditProfileV4, int>{
    for (final profile in pools.keys)
      profile: (pools[profile]?.isNotEmpty == true &&
              (pools[profile]!.first.stageId == _projectPlanApprovalStageIdV5))
          ? 30
          : profile.weeklyMinutes,
  };
  final indexes = <_PathAuditProfileV4, int>{for (final p in pools.keys) p: 0};
  var dayIndex = 0;
  var safety = 0;
  final activeProfiles = pools.keys.toList();
  while (activeProfiles.isNotEmpty && safety++ < 500) {
    final profile = activeProfiles.removeAt(0);
    final candidates = pools[profile] ?? const <_WeekActionCandidateV4>[];
    final idx = indexes[profile] ?? 0;
    final budget = remainingBudget[profile] ?? 0;
    if (idx >= candidates.length || budget <= 0) continue;

    final candidate = candidates[idx];
    indexes[profile] = idx + 1;
    if (candidate.minutes > budget) continue;
    final isApprovalTask =
        candidate.stageId == _projectPlanApprovalStageIdV5 &&
        candidate.actionId == _projectPlanApprovalActionIdV5;
    if (isApprovalTask &&
        existingApprovalCategoryIds.contains(candidate.category.id)) {
      remainingBudget[profile] = budget - candidate.minutes;
      continue;
    }
    final rootId = (candidate.root.pocketRecordId ?? candidate.root.planRowIdForBackend).trim();
    final marker = '$_pathActionPlanMarkerV4$rootId|${candidate.stageId}|${candidate.actionId}';
    final planBusinessId = _pathActionBusinessIdV7(
      rootId: rootId,
      stageId: candidate.stageId,
      actionId: candidate.actionId,
    );
    if (existingMarkers.contains(marker) ||
        existingBusinessIds.contains(planBusinessId)) {
      remainingBudget[profile] = budget - candidate.minutes;
      if ((indexes[profile] ?? 0) < candidates.length && (remainingBudget[profile] ?? 0) > 0) {
        activeProfiles.add(profile);
      }
      continue;
    }

    var placed = false;
    for (var attempt = 0; attempt < weekdays.length; attempt++) {
      final day = weekdays[(dayIndex + attempt) % weekdays.length];
      final dk = _dateKeyV4(day);
      final earliest = dayCursor[dk] ?? DateTime(day.year, day.month, day.day, 9);
      final existingDay = await db.getPlanningTasksForWallDate(
        DateTime(day.year, day.month, day.day),
      );
      final cursor = _firstFreeProjectSlotV5(
        db,
        earliest: earliest,
        minutes: candidate.minutes,
        latestEnd: DateTime(day.year, day.month, day.day, 15, 30),
        existing: existingDay,
      );
      if (cursor == null) continue;
      final end = cursor.add(Duration(minutes: candidate.minutes));
      final approvalTask = isApprovalTask;
      final ok = await _createScheduledTaskV4(
        category: candidate.category,
        title: approvalTask
            ? '${candidate.profile.name}: согласовать план проекта'
            : '${candidate.profile.name}: ${candidate.text}',
        notes: '$marker\nОжидаемый результат: ${candidate.result}',
        start: cursor,
        minutes: candidate.minutes,
        clientPlanId: planBusinessId,
      );
      if (ok) {
        created++;
        existingMarkers.add(marker);
        existingBusinessIds.add(planBusinessId);
        if (approvalTask) {
          existingApprovalCategoryIds.add(candidate.category.id);
        }
        dayCursor[dk] = end.add(const Duration(minutes: 5));
        dayIndex = (dayIndex + attempt + 1) % weekdays.length;
        placed = true;
      }
      break;
    }

    if (placed) remainingBudget[profile] = budget - candidate.minutes;
    if ((indexes[profile] ?? 0) < candidates.length && (remainingBudget[profile] ?? 0) > 0) {
      activeProfiles.add(profile);
    }
  }

  return PathWeekPlanReportV4(
    createdTasks: created,
    reconciledActions: reconciled,
    auditedProjects: auditedProjects,
    blockedProjects: blocked,
  );
}

Future<PathWeekPlanReportV4> runPathGovernanceAndPlanCurrentWeekV4() =>
    planCurrentWeekFromPathsV4();
