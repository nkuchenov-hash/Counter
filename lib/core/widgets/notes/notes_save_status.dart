// Canonical notes editor save status indicator. Pure UI — no Brain/PocketBase logic.
//
// Renders a subtle, single-line status that reflects autosave state without
// spamming snackbars. Composed by Notes editor surfaces in feature code.

import 'package:flutter/material.dart';

/// Distinct save states for a notes editor session.
enum NotesSaveStatusKind {
  /// No edits yet; nothing pending.
  idle,

  /// User is typing / a change was just observed; debounce pending.
  editing,

  /// Draft has been sent to the Brain; awaiting completion.
  saving,

  /// Latest draft was applied / synced successfully.
  saved,

  /// Latest mutation is queued offline (outbox); UI stays live.
  offlinePending,

  /// Last attempt failed and will not auto-retry without action.
  error,
}

/// Configuration for [AppNotesSaveStatus].
class AppNotesSaveStatusData {
  const AppNotesSaveStatusData({
    required this.kind,
    this.lastSavedLabel,
    this.errorLabel,
    this.retryLabel,
  });

  final NotesSaveStatusKind kind;

  /// Optional localized "Saved · <timestamp>" label for [NotesSaveStatusKind.saved].
  final String? lastSavedLabel;

  /// Localized message for [NotesSaveStatusKind.error].
  final String? errorLabel;

  /// Localized retry button label for [NotesSaveStatusKind.error].
  final String? retryLabel;

  AppNotesSaveStatusData copyWith({
    NotesSaveStatusKind? kind,
    String? lastSavedLabel,
    String? errorLabel,
    String? retryLabel,
  }) {
    return AppNotesSaveStatusData(
      kind: kind ?? this.kind,
      lastSavedLabel: lastSavedLabel ?? this.lastSavedLabel,
      errorLabel: errorLabel ?? this.errorLabel,
      retryLabel: retryLabel ?? this.retryLabel,
    );
  }
}

/// Subtle inline save status chip for the notes editor context row.
///
/// Never blocks; never replaces content; never produces snackbar spam.
/// Error state exposes a single optional retry action.
class AppNotesSaveStatus extends StatelessWidget {
  const AppNotesSaveStatus({
    super.key,
    required this.data,
    this.onRetry,
    this.compact = true,
  });

  final AppNotesSaveStatusData data;

  /// Optional retry callback shown only when [data] is
  /// [NotesSaveStatusKind.error] and a retry label exists.
  final VoidCallback? onRetry;

  /// When true, the chip uses smaller text and tighter padding.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color fg, Color bg, IconData? icon, String label) =
        _appearance(scheme);

    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

    final base = BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    );

    final textScale = compact ? 12.0 : 13.0;

    final core = DecoratedBox(
      decoration: base,
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.kind == NotesSaveStatusKind.saving)
              SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            else if (icon != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 5),
                child: Icon(icon, size: 13, color: fg),
              ),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: textScale,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
            if (data.kind == NotesSaveStatusKind.error &&
                data.retryLabel != null &&
                onRetry != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    data.retryLabel!,
                    style: TextStyle(
                      color: scheme.error,
                      fontSize: textScale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      label: label,
      button: data.kind == NotesSaveStatusKind.error && onRetry != null,
      child: core,
    );
  }

  (Color, Color, IconData?, String) _appearance(ColorScheme scheme) {
    switch (data.kind) {
      case NotesSaveStatusKind.idle:
        return (
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          null,
          data.lastSavedLabel ?? '',
        );
      case NotesSaveStatusKind.editing:
        return (
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          Icons.edit_rounded,
          data.lastSavedLabel ?? '',
        );
      case NotesSaveStatusKind.saving:
        return (
          scheme.primary,
          scheme.primary.withValues(alpha: 0.12),
          null,
          data.lastSavedLabel ?? 'Saving…',
        );
      case NotesSaveStatusKind.saved:
        return (
          scheme.primary,
          scheme.primary.withValues(alpha: 0.12),
          Icons.check_rounded,
          data.lastSavedLabel ?? 'Saved',
        );
      case NotesSaveStatusKind.offlinePending:
        return (
          scheme.tertiary,
          scheme.tertiary.withValues(alpha: 0.14),
          Icons.cloud_off_rounded,
          data.lastSavedLabel ?? 'Offline · pending',
        );
      case NotesSaveStatusKind.error:
        return (
          scheme.error,
          scheme.error.withValues(alpha: 0.14),
          Icons.error_outline_rounded,
          data.errorLabel ?? 'Error',
        );
    }
  }
}
