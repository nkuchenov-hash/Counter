import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';
import 'package:flutter/material.dart';

/// Global O1 offline/sync indicator owned by shell presentation.
///
/// Brain owns queue state and retry semantics through [DatabaseService.offlineSync].
/// This widget only renders that state and forwards tap-to-retry.
class OfflineSyncStatusBar extends StatefulWidget {
  const OfflineSyncStatusBar({super.key});

  @override
  State<OfflineSyncStatusBar> createState() => _OfflineSyncStatusBarState();
}

class _OfflineSyncStatusBarState extends State<OfflineSyncStatusBar> {
  bool _wasShowing = false;

  @override
  Widget build(BuildContext context) {
    rebuildMetricsTick('OfflineSyncBanner');
    final sync = DatabaseService.instance.offlineSync;
    final brain = DatabaseService.instance;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        sync.ensureBannerInvariant(syncFlushInFlight: brain.isSyncFlushInFlight);
        final showing = sync.shouldShowBanner;
        if (showing && !_wasShowing) {
          _wasShowing = true;
          unawaited(
            sync.logVisibleBannerState(
              bannerKind: sync.bannerKindLabel,
              pbBackoffActive: brain.pbHttpBackoffActive,
            ),
          );
        } else if (!showing) {
          _wasShowing = false;
        }
        if (!showing) return const SizedBox.shrink();

        final locale = currentLocale.value;
        final scheme = Theme.of(context).colorScheme;
        final String label;
        final Color foreground;
        final Color background;
        if (sync.isSyncing) {
          label = t(locale, 'offline_sync_syncing');
          foreground = scheme.onSurfaceVariant;
          background = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
        } else if (sync.authPaused) {
          label = t(locale, 'offline_sync_auth_paused');
          foreground = scheme.onErrorContainer;
          background = scheme.errorContainer.withValues(alpha: 0.85);
        } else if (sync.hasBlockingSyncError) {
          label = t(locale, 'offline_sync_error');
          foreground = scheme.onErrorContainer;
          background = scheme.errorContainer.withValues(alpha: 0.85);
        } else if (sync.isOffline) {
          label = t(locale, 'offline_sync_pending')
              .replaceAll('%s', '${sync.pendingCount}');
          foreground = scheme.onSurfaceVariant;
          background = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
        } else {
          label = t(locale, 'offline_sync_pending_online')
              .replaceAll('%s', '${sync.pendingCount}');
          foreground = scheme.onSurfaceVariant;
          background = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
        }

        return Material(
          color: background,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: () {
                unawaited(() async {
                  sync.logTapRetry(phase: 'TAP_RETRY');
                  await brain.flushPendingLocalMutations();
                  sync.logTapRetry(phase: 'AFTER_RETRY');
                }());
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (sync.isSyncing)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
