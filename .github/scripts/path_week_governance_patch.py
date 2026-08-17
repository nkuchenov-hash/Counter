from pathlib import Path
import re

app = Path('lib/app/shell/app_shell.dart')
more = Path('lib/app/shell/shared/shell_more_menu.dart')
helper = Path('lib/app/shell/shared/shell_path_governance.dart')
structure = Path('docs/APP_STRUCTURE.md')

a = app.read_text(encoding='utf-8')
if "shell_path_governance.dart" not in a:
    needle = "import 'package:counter/app/shell/shared/shell_shared.dart';\n"
    if needle not in a:
        raise SystemExit('app import anchor missing')
    a = a.replace(
        needle,
        needle + "import 'package:counter/app/shell/shared/shell_path_governance.dart';\n",
        1,
    )
app.write_text(a, encoding='utf-8')

s = more.read_text(encoding='utf-8')
old_boot = "      await bootstrapExecutablePortfolioPaths();\n      await _upgradeKadrRealityPathV3();\n"
new_boot = old_boot + "      await runPathGovernanceAndPlanCurrentWeekV4();\n"
if 'runPathGovernanceAndPlanCurrentWeekV4();' not in s:
    if old_boot not in s:
        raise SystemExit('bootstrap anchor missing')
    s = s.replace(old_boot, new_boot, 1)

pattern = re.compile(
    r"_V3RealityCheck _v3CheckPath\(CategoryRule category, PlanningTask root\) \{.*?\n\}\n\nclass ProjectPathsV3Page",
    re.S,
)
replacement = """_V3RealityCheck _v3CheckPath(CategoryRule category, PlanningTask root) {
  final audit = auditExecutableProjectPathV4(category, root);
  return _V3RealityCheck(
    structureProblems: <String>[
      ...audit.structureProblems,
      for (final topic in audit.missingTopics) 'Слепая зона: $topic.',
    ],
    missingTracks: audit.missingTracks,
    audited: audit.audited,
  );
}

class ProjectPathsV3Page"""
if pattern.search(s):
    s = pattern.sub(replacement, s, count=1)
elif 'final audit = auditExecutableProjectPathV4(category, root);' not in s:
    raise SystemExit('v3 check function anchor missing')

ru_anchor = "    'release' => 'Выпуск версий',\n    _ => 'Исполнение',\n"
ru_repl = """    'release' => 'Выпуск версий',
    'reliability' => 'Надёжность',
    'distribution' => 'Распространение',
    'privacy' => 'Приватность',
    'operations' => 'Операционка',
    'content' => 'Контент',
    'seo' => 'Поиск / SEO',
    'validation' => 'Проверка результата',
    'sales' => 'Продажи',
    'finance' => 'Финансы',
    'automation' => 'Автоматизация',
    'career' => 'Рабочая ценность',
    'people' => 'Люди / роли',
    'learning' => 'Обучение',
    'course_assignment' => 'Задания курса',
    'channel' => 'Каналы',
    'playbook' => 'База навыков',
    'transfer' => 'Перенос в проекты',
    'offer' => 'Бесплатное / платное',
    'website' => 'Сайт',
    'licensing' => 'Лицензирование',
    'support' => 'Поддержка',
    'execution' => 'Исполнение',
    _ => track,
"""
if ru_anchor in s:
    s = s.replace(ru_anchor, ru_repl, 1)

en_anchor = "      'release' => 'Release process',\n      _ => 'Execution',\n"
en_repl = """      'release' => 'Release process',
      'reliability' => 'Reliability',
      'distribution' => 'Distribution',
      'privacy' => 'Privacy',
      'operations' => 'Operations',
      'content' => 'Content',
      'seo' => 'Search / SEO',
      'validation' => 'Validation',
      'sales' => 'Sales',
      'finance' => 'Finance',
      'automation' => 'Automation',
      'career' => 'Work value',
      'people' => 'People / roles',
      'learning' => 'Learning',
      'course_assignment' => 'Course assignments',
      'channel' => 'Channels',
      'playbook' => 'Skills playbook',
      'transfer' => 'Transfer to projects',
      'offer' => 'Free / paid',
      'website' => 'Website',
      'licensing' => 'Licensing',
      'support' => 'Support',
      'execution' => 'Execution',
      _ => track,
"""
if en_anchor in s:
    s = s.replace(en_anchor, en_repl, 1)

# Stage headings must be visually stronger than action text.
stage_style_old = """          style: TextStyle(
            decoration: stage.done ? TextDecoration.lineThrough : null,
          ),
"""
stage_style_new = """          style: TextStyle(
            fontWeight: FontWeight.w800,
            decoration: stage.done ? TextDecoration.lineThrough : null,
          ),
"""
if stage_style_old in s:
    s = s.replace(stage_style_old, stage_style_new, 1)
more.write_text(s, encoding='utf-8')

h = helper.read_text(encoding='utf-8')
h = h.replace(
    "  final now = DateTime.now();\n",
    "  final now = db.applyUserOffset(DateTime.now().toUtc());\n",
    1,
)
h = h.replace(
    "    final dt = DateTime.tryParse(start)?.toLocal();\n",
    "    final parsedUtc = DateTime.tryParse(start);\n    final dt = parsedUtc == null ? null : db.applyUserOffset(parsedUtc.toUtc());\n",
    1,
)
h = h.replace(
    "Future<PathWeekPlanReportV4> runPathGovernanceAndPlanCurrentWeekV4() async {\n  await upgradeRealityPathsV4();\n  return planCurrentWeekFromPathsV4();\n}\n",
    "Future<PathWeekPlanReportV4> runPathGovernanceAndPlanCurrentWeekV4() =>\n    planCurrentWeekFromPathsV4();\n",
    1,
)
helper.write_text(h, encoding='utf-8')

d = structure.read_text(encoding='utf-8')
if 'shell_path_governance.dart' not in d:
    needle = "| `app/shell/shared/shell_more_menu.dart` | More bottom sheet *(part)* |"
    if needle not in d:
        raise SystemExit('APP_STRUCTURE anchor missing')
    d = d.replace(
        needle,
        needle + "\n| `app/shell/shared/shell_path_governance.dart` | Project Path reality audit, targeted Path upgrades, Path-action → current-week Planner orchestration |",
        1,
    )
structure.write_text(d, encoding='utf-8')
