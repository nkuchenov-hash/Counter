from pathlib import Path
import re

path = Path('lib/features/notes/widgets/note_editor_block_widgets.dart')
text = path.read_text(encoding='utf-8')

old_slot = '''                if (widget.isActive)
                  _NoteEditorBlockActiveControls(
                    block: block,
                    canMoveUp: widget.canMoveUp,
                    canMoveDown: widget.canMoveDown,
                    onMoveUp: widget.onMoveUp,
                    onMoveDown: widget.onMoveDown,
                    onConvert: _convertBlock,
                    onCreatePlan: _createPlanFromSelectionOrBlock,
                    onDelete: widget.onDelete,
                    loc: loc,
                  ),
'''
new_slot = '''                SizedBox(
                  width: 32,
                  child: widget.isActive
                      ? _NoteEditorBlockActiveControls(
                          block: block,
                          canMoveUp: widget.canMoveUp,
                          canMoveDown: widget.canMoveDown,
                          onMoveUp: widget.onMoveUp,
                          onMoveDown: widget.onMoveDown,
                          onConvert: _convertBlock,
                          onCreatePlan: _createPlanFromSelectionOrBlock,
                          onDelete: widget.onDelete,
                          loc: loc,
                        )
                      : null,
                ),
'''
if text.count(old_slot) != 1:
    raise RuntimeError('active controls slot not found exactly once')
text = text.replace(old_slot, new_slot)

replacement = r'''class _NoteEditorBlockActiveControls extends StatelessWidget {
  const _NoteEditorBlockActiveControls({
    required this.block,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onConvert,
    required this.onCreatePlan,
    required this.onDelete,
    required this.loc,
  });

  final NoteBlock block;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<NoteBlockType> onConvert;
  final VoidCallback onCreatePlan;
  final VoidCallback onDelete;
  final String loc;

  PopupMenuItem<void> _item({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    bool danger = false,
  }) {
    return PopupMenuItem<void>(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: danger ? const Color(0xFFDC2626) : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: danger ? const Color(0xFFDC2626) : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<void>(
        tooltip: t(loc, 'notes_editor_more_tooltip'),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 210),
        icon: const Icon(Icons.more_horiz_rounded, size: 18),
        itemBuilder: (context) => <PopupMenuEntry<void>>[
          if (canMoveUp)
            _item(
              icon: Icons.keyboard_arrow_up_rounded,
              label: t(loc, 'notes_v3_editor_move_up'),
              onTap: onMoveUp,
            ),
          if (canMoveDown)
            _item(
              icon: Icons.keyboard_arrow_down_rounded,
              label: t(loc, 'notes_v3_editor_move_down'),
              onTap: onMoveDown,
            ),
          if (canMoveUp || canMoveDown) const PopupMenuDivider(),
          _item(
            icon: Icons.text_fields_rounded,
            label: t(loc, 'notes_tools_body'),
            enabled: block.type != NoteBlockType.paragraph,
            onTap: () => onConvert(NoteBlockType.paragraph),
          ),
          _item(
            icon: Icons.title_rounded,
            label: 'H2',
            enabled: block.type != NoteBlockType.heading,
            onTap: () => onConvert(NoteBlockType.heading),
          ),
          _item(
            icon: Icons.checklist_rounded,
            label: t(loc, 'notes_v3_editor_add_checklist'),
            enabled: block.type != NoteBlockType.checklist,
            onTap: () => onConvert(NoteBlockType.checklist),
          ),
          _item(
            icon: Icons.format_list_bulleted_rounded,
            label: t(loc, 'notes_tools_bullets'),
            enabled: block.type != NoteBlockType.bulletedList,
            onTap: () => onConvert(NoteBlockType.bulletedList),
          ),
          _item(
            icon: Icons.format_list_numbered_rounded,
            label: t(loc, 'notes_tools_numbers'),
            enabled: block.type != NoteBlockType.numberedList,
            onTap: () => onConvert(NoteBlockType.numberedList),
          ),
          _item(
            icon: Icons.format_quote_rounded,
            label: t(loc, 'notes_tools_quote'),
            enabled: block.type != NoteBlockType.quote,
            onTap: () => onConvert(NoteBlockType.quote),
          ),
          _item(
            icon: Icons.lightbulb_outline_rounded,
            label: t(loc, 'notes_tools_callout'),
            enabled: block.type != NoteBlockType.callout,
            onTap: () => onConvert(NoteBlockType.callout),
          ),
          const PopupMenuDivider(),
          _item(
            icon: Icons.event_note_outlined,
            label: t(loc, 'notes_tools_create_plan'),
            onTap: onCreatePlan,
          ),
          _item(
            icon: Icons.delete_outline_rounded,
            label: t(loc, 'notes_v3_editor_delete_block'),
            onTap: onDelete,
            danger: true,
          ),
        ],
      ),
    );
  }
}

class _NoteEditorImageBlock'''

pattern = r'class _NoteEditorBlockActiveControls extends StatelessWidget \{.*?\n\}\n\nclass _NoteEditorBlockControlBtn extends StatelessWidget \{.*?\n\}\n\nclass _NoteEditorImageBlock'
text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
if count != 1:
    raise RuntimeError(f'active controls class range found {count} times')

path.write_text(text, encoding='utf-8')
print('Compacted Notes block controls')
