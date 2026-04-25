// AppErrorState / AppEmptyState — placeholder widgets for failed and empty
// content surfaces. Replaces ad-hoc Text("error...") / Center(Text("nothing")).
// Tier 1 / ROADMAP April 2026.

import 'package:flutter/material.dart';

/// Generic error placeholder. Use when a load/fetch fails and the surface
/// can't render its real content.
///
/// ```dart
/// AppErrorState(
///   message: 'Could not load tasks.',
///   onRetry: () => _refresh(),
/// )
/// ```
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline_rounded,
  });

  final String message;

  /// Optional retry callback. When null, no retry button is shown.
  final VoidCallback? onRetry;

  /// Optional override for the retry button label (defaults to "Retry").
  final String? retryLabel;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(retryLabel ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Generic empty-state placeholder. Use when a list / grid loaded successfully
/// but contains no items.
///
/// ```dart
/// AppEmptyState(
///   message: 'No plans for today.',
///   icon: Icons.event_available_rounded,
/// )
/// ```
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;

  /// Optional CTA below the message (e.g. "Add task" button).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
