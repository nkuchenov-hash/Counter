// Barrel for the canonical Notes editor widgets.
//
// These widgets are pure UI and live in `lib/core/widgets/` per the
// architecture boundary rules. Feature surfaces compose them; they MUST NOT
// import `lib/features/` or `lib/data/database_service.dart`.

export 'notes_context_row.dart';
export 'notes_editor_surface.dart';
export 'notes_markdown.dart';
export 'notes_save_status.dart';
export 'notes_toolbar.dart';
export 'note_preview_card.dart';
