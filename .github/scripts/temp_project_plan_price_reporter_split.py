from pathlib import Path

p = Path('lib/app/shell/shared/shell_path_governance.dart')
s = p.read_text(encoding='utf-8')

# Price Reporter is an employment/work project. Personal income arithmetic is
# governed by the dedicated ZenMoney project instead.
s = s.replace(
    "    requiredTracks: ['finance', 'operations', 'reliability', 'legal', 'automation', 'career'],\n",
    "    requiredTracks: ['operations', 'reliability', 'legal', 'automation', 'career'],\n",
    1,
)
s = s.replace(
    "      'фактический доход': ['доход', 'income', 'bonus'],\n",
    "",
    1,
)

anchor = "Future<void> upgradeRealityPathsV4() async {\n"
helper = r'''Future<void> _detachPriceReporterMoneyWorkV5() async {
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

'''
if '_detachPriceReporterMoneyWorkV5()' not in s:
    if anchor not in s: raise SystemExit('upgrade anchor missing')
    s = s.replace(anchor, helper + anchor, 1)

old = """  await _ensureMoneyManagementPathV5();
  await _ensureProjectPlanApprovalGatesV5();
}
"""
new = """  await _ensureMoneyManagementPathV5();
  await _detachPriceReporterMoneyWorkV5();
  await _ensureProjectPlanApprovalGatesV5();
}
"""
if old in s:
    s = s.replace(old, new, 1)
elif 'await _detachPriceReporterMoneyWorkV5();' not in s:
    raise SystemExit('upgrade call anchor missing')

p.write_text(s, encoding='utf-8')
