import 'package:counter/core/widgets/app_mic_level_bars.dart';
import 'package:flutter/material.dart';

/// Handy-style compact desktop voice capsule (bottom overlay).
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 360,
              maxWidth: 480,
              minHeight: 72,
              maxHeight: 120,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE6E2DC)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _LeadingIcon(
                      showMic: showMic,
                      showSpinner: showSpinner,
                      isError: isError,
                      scheme: scheme,
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
                            maxLines: 1,
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
                          if (showMic && micLevel > 0.01) ...[
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
                            ),
                      ),
                    ],
                    if (onRetry != null) ...[
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
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
  });

  final bool showMic;
  final bool showSpinner;
  final bool isError;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (showSpinner) {
      return SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: scheme.onSurface.withValues(alpha: 0.75),
        ),
      );
    }
    return Icon(
      isError ? Icons.error_outline_rounded : Icons.mic_rounded,
      size: 24,
      color: isError ? scheme.error : scheme.onSurface,
    );
  }
}
