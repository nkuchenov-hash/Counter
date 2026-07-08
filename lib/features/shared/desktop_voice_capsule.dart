import 'package:counter/core/widgets/app_mic_level_bars.dart';
import 'package:flutter/material.dart';

/// Handy/GOLOS-style compact desktop voice capsule (bottom overlay).
class DesktopVoiceCapsule extends StatelessWidget {
  const DesktopVoiceCapsule({
    super.key,
    required this.primaryLine,
    this.secondaryLine,
    required this.showMic,
    required this.showSpinner,
    required this.micLevel,
    this.timerText,
    this.onCancel,
    this.onRetry,
    this.isError = false,
    this.compactActions = false,
    this.progressFill,
    this.onTap,
    this.accentColor,
  });

  final String primaryLine;
  final String? secondaryLine;
  final bool showMic;
  final bool showSpinner;
  final double micLevel;
  final String? timerText;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final bool isError;
  final bool compactActions;
  final double? progressFill;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? scheme.primary;
    final fill = progressFill?.clamp(0.0, 1.0);

    Widget capsule = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _LeadingIcon(
                    showMic: showMic,
                    showSpinner: showSpinner,
                    isError: isError,
                    scheme: scheme,
                    accent: accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          primaryLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isError
                                    ? scheme.error
                                    : scheme.onSurface,
                              ),
                        ),
                        if ((secondaryLine ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            secondaryLine!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        if (showMic) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 18,
                            child: AppMicLevelBars(level: micLevel),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if ((timerText ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      timerText!,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (onRetry != null && !compactActions) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Retry',
                      visualDensity: VisualDensity.compact,
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                  ],
                  if (onCancel != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Cancel',
                      visualDensity: VisualDensity.compact,
                      onPressed: onCancel,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (fill != null && fill > 0)
              LinearProgressIndicator(
                value: fill,
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
                color: accent,
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      capsule = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: capsule,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 260,
              maxWidth: 420,
              minHeight: 52,
              maxHeight: 120,
            ),
            child: capsule,
          ),
        ),
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({
    required this.showMic,
    required this.showSpinner,
    required this.isError,
    required this.scheme,
    required this.accent,
  });

  final bool showMic;
  final bool showSpinner;
  final bool isError;
  final ColorScheme scheme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (showSpinner) {
      return SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: accent.withValues(alpha: 0.85),
        ),
      );
    }
    return Icon(
      isError ? Icons.error_outline_rounded : Icons.mic_rounded,
      size: 24,
      color: isError ? scheme.error : accent.withValues(alpha: 0.9),
    );
  }
}
