from pathlib import Path

p = Path('lib/app/shell/shared/shell_path_governance.dart')
s = p.read_text(encoding='utf-8')

old = """  final missingTopics = <String>[];
  for (final entry in profile.requiredTopics.entries) {
    if (!entry.value.any((token) => searchable.contains(token.toLowerCase()))) {
      missingTopics.add(entry.key);
    }
  }

  return ProjectPathAuditV4(
"""
new = """  final missingTopics = <String>[];
  for (final entry in profile.requiredTopics.entries) {
    if (!entry.value.any((token) => searchable.contains(token.toLowerCase()))) {
      missingTopics.add(entry.key);
    }
  }
  if (!_projectPlanApprovedV5(root)) {
    missingTopics.insert(0, 'план проекта ещё не согласован');
  }

  return ProjectPathAuditV4(
"""
if "missingTopics.insert(0, 'план проекта ещё не согласован')" not in s:
    if old not in s:
        raise SystemExit('audit anchor missing')
    s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
