import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/widgets/note_editor_block_widgets.dart';
import 'package:counter/features/notes/widgets/notes_editor_tools.dart';
import 'package:counter/features/notes/widgets/notes_special_block_widgets.dart';
import 'package:flutter/material.dart';

const Size kNotesV2ToolsViewport = Size(1156, 1200);
const Key kNotesV2ToolsCaptureKey = Key('notes_v2_tools_capture');

class NotesV2ToolsFixture extends StatelessWidget {
  const NotesV2ToolsFixture({super.key});

  static const NoteBlock _activeBlock = NoteBlock(
    id: 'tools-active',
    type: NoteBlockType.paragraph,
    text: 'Protect mornings from meetings and keep one source of truth.',
    runs: <NoteTextRun>[
      NoteTextRun(
        text: 'Protect mornings',
        marks: NoteInlineMarks(bold: true, highlightColor: '#FFF2A8'),
      ),
      NoteTextRun(text: ' from meetings and keep one source of truth.'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: kNotesV2ToolsCaptureKey,
      child: SizedBox(
        width: kNotesV2ToolsViewport.width,
        height: kNotesV2ToolsViewport.height,
        child: NotesGlmBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Life OS Notes — editor tools v2',
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Production components · formatting, insertion, selection and tables',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PreviewCard(
                        title: 'Aa · text and block formatting',
                        child: NotesEditorToolsDock(
                          activeBlock: _activeBlock,
                          loc: 'en',
                          initialPanel: NotesToolsPanel.format,
                          onToggleChecklist: _noop,
                          onHeading: _noopInt,
                          onSetBlockType: _noopType,
                          onToggleFormat: _noopString,
                          onSetColor: _noopNullableString,
                          onInsert: _noopInsert,
                          onImage: _noop,
                          onDraw: _noop,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _PreviewCard(
                        title: '+ · insert blocks',
                        child: NotesEditorToolsDock(
                          activeBlock: _activeBlock,
                          loc: 'en',
                          initialPanel: NotesToolsPanel.insert,
                          onToggleChecklist: _noop,
                          onHeading: _noopInt,
                          onSetBlockType: _noopType,
                          onToggleFormat: _noopString,
                          onSetColor: _noopNullableString,
                          onInsert: _noopInsert,
                          onImage: _noop,
                          onDraw: _noop,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PreviewCard(
                        title: 'Selected text · contextual actions',
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: NotesSelectionToolbar(
                            selectedRuns: const <NoteTextRun>[
                              NoteTextRun(
                                text: 'Protect mornings',
                                marks: NoteInlineMarks(
                                  bold: true,
                                  highlightColor: '#FFF2A8',
                                ),
                              ),
                            ],
                            onBold: _noop,
                            onItalic: _noop,
                            onUnderline: _noop,
                            onStrike: _noop,
                            onHighlight: _noop,
                            onLink: _noop,
                            onCreatePlan: _noop,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _PreviewCard(
                        title: 'Active table · contextual editing',
                        child: NotesSpecialBlockView(
                          block: const NoteBlock(
                            id: 'tools-table',
                            type: NoteBlockType.table,
                            table: NoteTableData(
                              hasHeader: true,
                              cells: <List<String>>[
                                <String>['Day', 'Focus', 'Status'],
                                <String>['Monday', 'Deep work', 'Done'],
                                <String>['Tuesday', 'Roadmap', 'Next'],
                              ],
                            ),
                          ),
                          isActive: true,
                          loc: 'en',
                          onActivate: _noop,
                          onDelete: _noop,
                          onTableChanged: _noopTable,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _noop() {}
  static void _noopInt(int _) {}
  static void _noopType(NoteBlockType _) {}
  static void _noopString(String _) {}
  static void _noopNullableString(String? _) {}
  static void _noopInsert(NotesInsertRequest _) {}
  static void _noopTable(NoteTableData _) {}
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: notesGlmGlassCardDecoration(radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
