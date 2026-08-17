from pathlib import Path
import re

p = Path('lib/app/shell/shared/shell_path_governance.dart')
s = p.read_text(encoding='utf-8')

# 1) Approval identifiers.
anchor = "const String _weekRoutinePlanMarkerV4 = 'LIFEOS_WEEK_ROUTINE_V4|';\n"
insert = anchor + "const String _projectPlanApprovalStageIdV5 = 'project-plan-approval-v5';\nconst String _projectPlanApprovalActionIdV5 = 'project-plan-approval-v5-review';\n"
if '_projectPlanApprovalStageIdV5' not in s:
    if anchor not in s: raise SystemExit('constant anchor missing')
    s = s.replace(anchor, insert, 1)

# 2) Money-management audit profile before Price Reporter.
profile_anchor = "  _PathAuditProfileV4(\n    name: 'Price Reporter',\n"
money_profile = """  _PathAuditProfileV4(
    name: 'Управление деньгами / ZenMoney',
    aliases: [
      'Управление деньгами / ZenMoney',
      'Управление деньгами',
      'ZenMoney',
      'Zen Money',
      'Финансы',
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
"""
if "name: 'Управление деньгами / ZenMoney'" not in s:
    if profile_anchor not in s: raise SystemExit('profile anchor missing')
    s = s.replace(profile_anchor, money_profile + profile_anchor, 1)

# 3) Approval stage, money path, category creation, and gate helpers.
helper_anchor = "bool _checklistHasPrefixV4(List<Map<String, dynamic>> checklist, String prefix) =>\n"
helpers = r'''Map<String, dynamic> _projectPlanApprovalStageV5() => _stageV4(
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
        'approval-v5-gate';

bool _projectPlanApprovedV5(PlanningTask root) =>
    _hasProjectPlanApprovalGateV5(root) && root.checklist.first['isDone'] == true;

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
    'Финансы',
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
  return db.getCategoryRuleById(created);
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
  final roots = await db.fetchBacklogPlans(includeCompleted: true);
  for (final root in roots) {
    if ((root.notesPlain ?? '').trim() != _activePathMarkerV4) continue;
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

'''
if '_projectPlanApprovalStageV5()' not in s:
    if helper_anchor not in s: raise SystemExit('helper insertion anchor missing')
    s = s.replace(helper_anchor, helpers + helper_anchor, 1)

# 4) Ensure money project and approval gates after reality upgrades.
upgrade_end = """      if (!ok) throw StateError('Could not extend Rulers Path');
    }
  }
}

String _weekKeyV4"""
upgrade_repl = """      if (!ok) throw StateError('Could not extend Rulers Path');
    }
  }

  await _ensureMoneyManagementPathV5();
  await _ensureProjectPlanApprovalGatesV5();
}

String _weekKeyV4"""
if 'await _ensureProjectPlanApprovalGatesV5();' not in s:
    if upgrade_end not in s: raise SystemExit('upgrade end anchor missing')
    s = s.replace(upgrade_end, upgrade_repl, 1)

# 5) Planner: approval gate can feed one 30-min review even though project is not yet audited.
loop_old = """    final audit = auditExecutableProjectPathV4(category, root);
    if (!audit.audited) {
      blocked.add(profile.name);
      continue;
    }
    auditedProjects++;
    if (profile.weeklyMinutes <= 0) continue;
    pools[profile] = _currentActionsForRootV4(profile, category, root);
"""
loop_new = """    final audit = auditExecutableProjectPathV4(category, root);
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
"""
if loop_old in s:
    s = s.replace(loop_old, loop_new, 1)
elif "план не согласован" not in s:
    raise SystemExit('planner audit loop anchor missing')

# 6) Approval tasks should fit even for profiles whose normal weekly budget is 0.
budget_old = """  final remainingBudget = <_PathAuditProfileV4, int>{
    for (final profile in pools.keys) profile: profile.weeklyMinutes,
  };
"""
budget_new = """  final remainingBudget = <_PathAuditProfileV4, int>{
    for (final profile in pools.keys)
      profile: (pools[profile]?.isNotEmpty == true &&
              (pools[profile]!.first.stageId.startsWith('approval-v5-')))
          ? 30
          : profile.weeklyMinutes,
  };
"""
if budget_old in s:
    s = s.replace(budget_old, budget_new, 1)
elif "first.stageId.startsWith('approval-v5-')" not in s:
    raise SystemExit('budget anchor missing')

# 7) Remove auto-created recurring Atozed and Price Reporter blocks entirely.
start = s.find("  final atozed = _findCategoryByAliasesV4(const [")
end = s.find("  final remainingBudget = <_PathAuditProfileV4, int>{", start)
if start != -1 and end != -1:
    # Keep dayCursor initialization, but strip all auto-routine creation.
    replacement = """  final dayCursor = <String, DateTime>{};
  for (final day in weekdays) {
    var start = DateTime(day.year, day.month, day.day, 9);
    if (day.year == today.year && day.month == today.month && day.day == today.day) {
      final rounded = _roundUp5V4(now.add(const Duration(minutes: 10)));
      if (rounded.isAfter(start)) start = rounded;
    }
    dayCursor[_dateKeyV4(day)] = start;
  }

"""
    s = s[:start] + replacement + s[end:]

p.write_text(s, encoding='utf-8')
