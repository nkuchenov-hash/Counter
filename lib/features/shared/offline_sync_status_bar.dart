import 'dart:async';

import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

// Global offline / sync indicator (O1).
// ---------------------------------------------------------------------------

class OfflineSyncStatusBar extends StatefulWidget {
  const OfflineSyncStatusBar({this.routeTab});

  final String? routeTab;

  @override
  State<OfflineSyncStatusBar> createState() => OfflineSyncStatusBarState();
}

class OfflineSyncStatusBarState extends State<OfflineSyncStatusBar> {
  bool _wasShowing = false;

  @override
  Widget build(BuildContext context) {
    rebuildMetricsTick('OfflineSyncBanner');
    final sync = DatabaseService.instance.offlineSync;
    final brain = DatabaseService.instance;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        sync.ensureBannerInvariant(
          syncFlushInFlight: brain.isSyncFlushInFlight,
        );
        final showing = sync.shouldShowBanner;
        if (showing && !_wasShowing) {
          _wasShowing = true;
          final kind = sync.bannerKindLabel;
          unawaited(
            sync.logVisibleBannerState(
              bannerKind: kind,
              routeTab: widget.routeTab,
              pbBackoffActive: brain.pbHttpBackoffActive,
            ),
          );
        } else if (!showing) {
          _wasShowing = false;
        }
        if (!showing) {
          return const SizedBox.shrink();
        }
        final locale = currentLocale.value;
        final scheme = Theme.of(context).colorScheme;
        String label;
        Color fg;
        Color bg;
        if (sync.isSyncing) {
          label = t(locale, 'offline_sync_syncing');
          fg = scheme.onSurfaceVariant;
          bg = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
        } else if (sync.authPaused) {
          label = t(locale, 'offline_sync_auth_paused');
          fg = scheme.onErrorContainer;
          bg = scheme.errorContainer.withValues(alpha: 0.85);
        } else if (sync.hasBlockingSyncError) {
          label = t(locale, 'offline_sync_error');
          fg = scheme.onErrorContainer;
          bg = scheme.errorContainer.withValues(alpha: 0.85);
        } else if (sync.isOffline) {
          label = t(
            locale,
            'offline_sync_pending',
          ).replaceAll('%s', '${sync.pendingCount}');
          fg = scheme.onSurfaceVariant;
          bg = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
        } else {
          label = t(
            locale,
            'offline_sync_pending_online',
          ).replaceAll('%s', '${sync.pendingCount}');
          fg = scheme.onSurfaceVariant;
          bg = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
        }
        return Material(
          color: bg,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: () {
                unawaited(() async {
                  sync.logTapRetry(phase: 'TAP_RETRY');
                  await DatabaseService.instance.flushPendingLocalMutations();
                  sync.logTapRetry(phase: 'AFTER_RETRY');
                }());
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                            color: fg,
                          ),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: fg),
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
