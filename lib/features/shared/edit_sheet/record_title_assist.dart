part of '../timeline_record_edit_sheet.dart';

/// Debounce category matching instead of scanning the tree on each key event.
void _handleRecordTitleInput(
  TimelineRecordSheetContentState state, String raw,
) {
  state._titleAssistDebounce?.cancel();
  state._titleAssistDebounce = Timer(
    const Duration(milliseconds: 450), () {
      if (!state.mounted || state._titleController.text != raw) return;
      state._applyFuzzyCategoryFromRecordTitle(raw);
    },
  );
  state._onRecordFieldChanged();
}
