from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one match, got {count}: {old!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/features/paths/widgets/path_stage_card.dart',
    'fontSize: 20,\n                  height: 1.18,',
    'fontSize: 16,\n                  height: 1.25,',
)

replace_once(
    'lib/features/paths/paths_page.dart',
    'child: SafeArea(\n        bottom: false,',
    'child: SafeArea(\n        top: false,\n        bottom: false,',
)
replace_once(
    'lib/features/paths/paths_page.dart',
    'padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),',
    'padding: EdgeInsets.fromLTRB(\n        20,\n        MediaQuery.paddingOf(context).top,\n        12,\n        12,\n      ),',
)
replace_once(
    'lib/features/paths/paths_page.dart',
    'padding: const EdgeInsets.fromLTRB(24, 28, 24, 56),',
    'padding: const EdgeInsets.fromLTRB(24, 0, 24, 56),',
)

replace_once(
    'lib/features/planning/widgets/planning_filter_controls.dart',
    'padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),',
    'padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),',
)

replace_once(
    'docs/PATHS_STAGE_CARD_VARIANT_2.md',
    '- stage title: 20px, 800, line-height 1.18;',
    '- stage title: 16px, 800, line-height 1.25;',
)
