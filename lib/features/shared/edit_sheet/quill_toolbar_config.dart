import 'package:counter/core/theme.dart';import 'package:flutter/material.dart';import 'package:flutter_quill/flutter_quill.dart';/// Strike 23: one horizontal row ([multiRowsDisplay]: false → arrow-indicated list, no [Wrap]).
QuillSimpleToolbarConfig planningTaskEditQuillToolbarConfig(
  BuildContext context,
) {
  final scheme = Theme.of(context).colorScheme;
  return QuillSimpleToolbarConfig(
    multiRowsDisplay: false,
    showDividers: false,
    toolbarSize: kPlanningEditQuillToolbarRowSize,
    toolbarRunSpacing: 0,
    buttonOptions: const QuillSimpleToolbarButtonOptions(
      base: QuillToolbarBaseButtonOptions(
        iconSize: kPlanningEditQuillToolbarIconSize,
        iconButtonFactor: 1.42,
      ),
    ),
    showFontFamily: false,
    showFontSize: false,
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: true,
    showInlineCode: false,
    showColorButton: true,
    showBackgroundColorButton: false,
    showClearFormat: true,
    showAlignmentButtons: false,
    showHeaderStyle: false,
    showListNumbers: true,
    showListBullets: true,
    showListCheck: true,
    showCodeBlock: false,
    showQuote: false,
    showIndent: false,
    showLink: false,
    showUndo: false,
    showRedo: false,
    showSearchButton: false,
    showSubscript: false,
    showSuperscript: false,
    showSmallButton: false,
    showLineHeightButton: false,
    showDirection: false,
    color: scheme.surfaceContainerHighest,
  );
}
