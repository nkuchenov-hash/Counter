from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, got {count}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


# Restore LIFE OS branding in the global desktop header. Section names belong in page content.
replace_once(
    'lib/app/shell/shared/shell_chrome.dart',
    """                                      Text(\n                                        desktopShell\n                                            ? _desktopSectionTitle(loc)\n                                            : t(loc, 'app_title'),""",
    """                                      Text(\n                                        t(loc, 'app_title'),""",
)

# Add one consistent large section heading inside the desktop content column only.
replace_once(
    'lib/app/shell/shared/shell_chrome.dart',
    """                              final mainColumn = Column(\n                                children: [\n                                  const ShellTopStatusBars(),\n                                  Expanded(""",
    """                              final mainColumn = Column(\n                                children: [\n                                  const ShellTopStatusBars(),\n                                  if (formFactor == ShellFormFactor.desktop)\n                                    Padding(\n                                      padding: const EdgeInsets.fromLTRB(\n                                        24,\n                                        18,\n                                        24,\n                                        12,\n                                      ),\n                                      child: Align(\n                                        alignment:\n                                            AlignmentDirectional.centerStart,\n                                        child: Text(\n                                          _desktopSectionTitle(loc),\n                                          maxLines: 1,\n                                          overflow: TextOverflow.ellipsis,\n                                          style: Theme.of(context)\n                                              .textTheme\n                                              .headlineSmall\n                                              ?.copyWith(\n                                                fontWeight: FontWeight.w800,\n                                                height: 1.1,\n                                              ),\n                                        ),\n                                      ),\n                                    ),\n                                  Expanded(""",
)

# Give the desktop navigation a real visual boundary from the content area.
replace_once(
    'lib/app/shell/desktop/shell_side_navigation.dart',
    """    return Material(\n      color: scheme.surfaceContainerLow.withValues(alpha: 0.55),\n      child: SizedBox(""",
    """    return Material(\n      color: scheme.surfaceContainerLow.withValues(alpha: 0.55),\n      shape: Border(\n        right: BorderSide(\n          color: scheme.outlineVariant.withValues(alpha: 0.9),\n        ),\n      ),\n      child: SizedBox(""",
)

# Correct the governing contract: shared brand header + large content title, no duplicate feature AppBars.
p = Path('docs/DESIGN_SYSTEM.md')
text = p.read_text(encoding='utf-8')
old = """On wide desktop layouts, the shell owns one shared top header for every primary section. Feature pages must not stack a second page AppBar/title above their content on desktop; feature-specific commands may remain in a compact secondary toolbar below the shared header. This rule applies to shell/menu chrome only and does not authorize redesigning feature cards, rows, editors, or other local controls. Phone and tablet chrome remain feature-adaptive unless separately specified."""
new = """On wide desktop layouts, the shell owns one shared top header for every primary section. The global header keeps the LIFE OS brand/app title; the active section name is rendered once as a large heading inside the main content column, not in the brand position and not duplicated beside the navigation item. Feature pages must not stack a second page AppBar/title above their content on desktop; feature-specific commands may remain in a compact secondary toolbar below the section heading. The desktop side navigation has a visible boundary separating it from page content. This rule applies to shell/menu chrome only and does not authorize redesigning feature cards, rows, editors, or other local controls. Phone and tablet chrome remain feature-adaptive unless separately specified."""
if text.count(old) != 1:
    raise SystemExit('DESIGN_SYSTEM desktop shell contract mismatch')
p.write_text(text.replace(old, new, 1), encoding='utf-8')
