from pathlib import Path

cascade = Path('lib/data/plans/plan_time_cascade_helpers.dart')
text = cascade.read_text(encoding='utf-8')
text = text.replace(
    'currentWall ?? applyUserOffset(getPlanetaryNow());',
    'currentWall ?? applyUserOffset(DatabaseService.getPlanetaryNow());',
)
cascade.write_text(text, encoding='utf-8')

settings = Path('lib/features/planning/time_view/time_view_settings_sheet.dart')
text = settings.read_text(encoding='utf-8')
old = '''  late PlanAutoPlacementMode _mode = widget.initialMode;

  Future<void> _select(PlanAutoPlacementMode mode) async {'''
new = '''  late PlanAutoPlacementMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  Future<void> _select(PlanAutoPlacementMode mode) async {'''
if old in text:
    text = text.replace(old, new, 1)
settings.write_text(text, encoding='utf-8')
