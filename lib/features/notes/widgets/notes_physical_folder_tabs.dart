part of 'notes_library_production_shell.dart';

// Notes paper-folder tab bar and its continuous colored content pane.
// Keep all tabs, section-selection controls and pane colors in this module.
Color _paneColorFor(BuildContext context, int? categoryId) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final accent = categoryId == null
      ? const Color(0xFF285B99)
      : (DatabaseService.instance.getCategoryRuleById(categoryId)
              ?.colorOrDefault ??
          const Color(0xFF285B99));
  return Color.alphaBlend(
    accent.withValues(alpha: dark ? 0.20 : 0.12),
    scheme.surface,
  );
}

/// The selected paper tab touches the same folder-colored content surface.
class _NotesFolderPane extends StatelessWidget {
  const _NotesFolderPane({required this.categoryId, required this.child});

  final int? categoryId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _paneColorFor(context, categoryId),
          border: Border(
            left: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
            right: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: child,
        ),
      ),
    );
  }
}

class _NotesCategoryAdapter {
  const _NotesCategoryAdapter({
    required this.chipIds,
    required this.chipMode,
    required this.filterCategoryId,
    required this.scrollController,
    required this.onFilterChanged,
    required this.onManualChipReorder,
  });

  final List<int> chipIds;
  final String chipMode;
  final int? filterCategoryId;
  final ScrollController scrollController;
  final ValueChanged<int?> onFilterChanged;
  final void Function(int oldIndex, int newIndex) onManualChipReorder;
  final ValueChanged<List<int>> onVisibleSectionsChanged;
}

class _NotesPhysicalFolderTabs extends StatefulWidget {
  const _NotesPhysicalFolderTabs({
    required this.adapter,
    this.onOpenSettings,
  });

  final _NotesCategoryAdapter adapter;
  final VoidCallback? onOpenSettings;

  @override
  State<_NotesPhysicalFolderTabs> createState() =>
      _NotesPhysicalFolderTabsState();
}

class _NotesPhysicalFolderTabsState extends State<_NotesPhysicalFolderTabs> {
  List<int>? _localChipIds;

  List<int> get _ids => _localChipIds ?? widget.adapter.chipIds;

  @override
  void didUpdateWidget(covariant _NotesPhysicalFolderTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final local = _localChipIds;
    if (local == null) return;
    if (_sameIds(local, widget.adapter.chipIds)) {
      _localChipIds = null;
    }
  }

  bool _sameIds(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _editSections() async {
    final current = _ids;
    final picked = await showCategoryTreeMultiPicker(
      context,
      initialCategoryIds: Set<int>.from(current),
    );
    if (!mounted || picked == null) return;

    final selected = Set<int>.from(picked);
    final next = <int>[
      for (final id in current)
        if (selected.remove(id)) id,
      ...selected,
    ];

    if (!mounted) return;
    setState(() => _localChipIds = next);
    widget.adapter.onVisibleSectionsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView(
                controller: widget.adapter.scrollController,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: EdgeInsets.zero,
                children: [
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: _FolderTab(
                      label: _allLabel(currentLocale.value),
                      icon: Icons.format_list_bulleted_rounded,
                      accent: const Color(0xFF285B99),
                      fill: _paneColorFor(context, null),
                      selected: widget.adapter.filterCategoryId == null,
                      onTap: () => widget.adapter.onFilterChanged(null),
                    ),
                  ),
                  for (final id in ids)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: _categoryTab(id),
                    ),
                ],
              ),
            ),
          ),
          Tooltip(
            message: currentLocale.value == 'ru'
                ? 'Добавить раздел'
                : 'Add folder section',
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _FolderTab(
                label: '',
                icon: Icons.add_rounded,
                accent: Colors.white,
                fill: kNotesInk,
                selected: false,
                compact: true,
                onTap: () => unawaited(_editSections()),
              ),
            ),
          ),
          Tooltip(
            message: currentLocale.value == 'ru'
                ? 'Выбрать отображаемые разделы'
                : 'Select visible folder sections',
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _FolderTab(
                label: '',
                icon: Icons.tune_rounded,
                accent: Colors.white,
                fill: kNotesInk,
                selected: false,
                compact: true,
                onTap: () => unawaited(_editSections()),
                onLongPress: widget.onOpenSettings,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTab(int id) {
    final rule = DatabaseService.instance.getCategoryRuleById(id);
    if (rule == null) return const SizedBox.shrink();
    final accent = rule.colorOrDefault;
    final icon = rule.iconCodePoint == null
        ? Icons.folder_outlined
        : IconData(rule.iconCodePoint!, fontFamily: 'MaterialIcons');
    return _FolderTab(
      label: rule.name.trim().isEmpty ? '—' : rule.name.trim(),
      icon: icon,
      accent: accent,
      fill: _paneColorFor(context, id),
      selected: widget.adapter.filterCategoryId == id,
      onTap: () => widget.adapter.onFilterChanged(id),
    );
  }

  String _allLabel(String locale) {
    switch (locale) {
      case 'ru':
        return 'Все';
      case 'de':
        return 'Alle';
      case 'fr':
        return 'Tous';
      case 'es':
        return 'Todo';
      case 'it':
        return 'Tutte';
      default:
        return 'All';
    }
  }
}

class _FolderTab extends StatelessWidget {
  const _FolderTab({
    required this.label,
    required this.icon,
    required this.accent,
    required this.fill,
    required this.selected,
    required this.onTap,
    this.compact = false,
    this.onLongPress,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Color fill;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final mobile = MediaQuery.sizeOf(context).width <= 520;

    final tabFill = compact
        ? kNotesInk
        : selected
            ? fill
            : Color.alphaBlend(
                accent.withValues(alpha: dark ? 0.32 : 0.23),
                scheme.surface,
              );
    final foreground = compact
        ? Colors.white
        : Color.lerp(
            accent,
            scheme.onSurface,
            dark ? 0.58 : 0.67,
          )!;
    final outline = compact
        ? kNotesInk
        : Color.lerp(accent, scheme.outline, dark ? 0.32 : 0.38)!;

    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(9),
          topRight: Radius.circular(9),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: selected ? 44 : 40,
            constraints: BoxConstraints(
              minWidth: compact ? 39 : (mobile ? 82 : 94),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : (mobile ? 12 : 15),
            ),
            decoration: BoxDecoration(
              color: tabFill,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
              border: Border.all(
                color: outline.withValues(alpha: compact ? 1 : 0.78),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: compact ? 19 : 17, color: foreground),
                    if (!compact) ...[
                      const SizedBox(width: 7),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Hide only the selected tab's bottom outline so its paper
                // surface visually continues into the content pane.
                if (selected && !compact)
                  Positioned(
                    left: 2,
                    right: 2,
                    bottom: 0,
                    child: ColoredBox(
                      color: tabFill,
                      child: const SizedBox(height: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

