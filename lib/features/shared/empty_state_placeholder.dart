import 'package:counter/l10n/dictionary.dart';import 'package:flutter/material.dart';class EmptyStatePlaceholder extends StatelessWidget {
  const EmptyStatePlaceholder({
    super.key,
    required this.icon,
    required this.titleL10nKey,
    required this.subtitleL10nKey,
    this.actionLabelL10nKey,
    this.onAction,
    this.iconSize = 96,
    this.iconOpacity = 0.26,
    this.useFilledAction = false,
  });

  final IconData icon;
  final String titleL10nKey;
  final String subtitleL10nKey;
  final String? actionLabelL10nKey;
  final VoidCallback? onAction;
  final double iconSize;
  final double iconOpacity;

  /// When true, primary-style button (e.g. “create first” flows).
  final bool useFilledAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final loc = currentLocale.value;
    final hasAction = actionLabelL10nKey != null && onAction != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: scheme.onSurface.withValues(alpha: iconOpacity),
            ),
            const SizedBox(height: 20),
            Text(
              t(loc, titleL10nKey),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t(loc, subtitleL10nKey),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (hasAction) ...[
              const SizedBox(height: 22),
              useFilledAction
                  ? FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(t(loc, actionLabelL10nKey!)),
                    )
                  : OutlinedButton.icon(
                      onPressed: onAction,
                      icon: Icon(
                        Icons.north_rounded,
                        size: 18,
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                      label: Text(t(loc, actionLabelL10nKey!)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ActivityDetailSheet & related
// ---------------------------------------------------------------------------
