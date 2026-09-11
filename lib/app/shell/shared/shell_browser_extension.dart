part of '../app_shell.dart';

const String _browserExtensionConsumedRequestIdsKey =
    'browser_extension_consumed_request_ids_v2';
const String _browserExtensionRecordSnapshotKey =
    'browser_extension_record_snapshot_v2';
const String _browserExtensionResponseKey =
    'browser_extension_response_v2';
const int _browserExtensionConsumedRequestLimit = 48;

mixin ShellBrowserExtensionQuickAdd on ShellDashboardBase {
  Future<void> initializeBrowserExtensionBridge() async {
    if (!kIsWeb) return;
    final existingSub = browserExtensionRecordSub;
    if (existingSub != null) {
      await existingSub.cancel();
    }
    browserExtensionRecordSub =
        DatabaseService.instance.timeUpdates.listen((_) {
      unawaited(_publishBrowserExtensionRecordSnapshot());
    });
    await _publishBrowserExtensionRecordSnapshot();
  }

  Future<void> _publishBrowserExtensionRecordSnapshot() async {
    if (!kIsWeb) return;
    try {
      final db = DatabaseService.instance;
      final snapshot = <String, dynamic>{
        ...db.browserExtensionActiveRecordSnapshot(),
        'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'locale': currentLocale.value,
        'themeMode': db.settings.themeMode,
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _browserExtensionRecordSnapshotKey,
        jsonEncode(snapshot),
      );
    } catch (_) {}
  }

  Future<void> _writeBrowserExtensionResponse({
    required String requestId,
    required String action,
    required bool ok,
    String? error,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _browserExtensionResponseKey,
        jsonEncode(<String, dynamic>{
          'requestId': requestId,
          'action': action,
          'ok': ok,
          if (error != null && error.isNotEmpty) 'error': error,
          'completedAtUtc': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  Future<SharedPreferences?> _browserExtensionPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _browserExtensionRequestWasConsumed(
    SharedPreferences prefs,
    String requestId,
  ) async {
    final consumed =
        prefs.getStringList(_browserExtensionConsumedRequestIdsKey) ??
        <String>[];
    return consumed.contains(requestId);
  }

  Future<void> _markBrowserExtensionRequestConsumed(
    SharedPreferences prefs,
    String requestId,
  ) async {
    final consumed =
        prefs.getStringList(_browserExtensionConsumedRequestIdsKey) ??
        <String>[];
    final next = <String>[
      for (final id in consumed)
        if (id != requestId) id,
      requestId,
    ];
    if (next.length > _browserExtensionConsumedRequestLimit) {
      next.removeRange(0, next.length - _browserExtensionConsumedRequestLimit);
    }
    await prefs.setStringList(_browserExtensionConsumedRequestIdsKey, next);
  }

  Future<void> consumeBrowserExtensionQuickAddIfPresent() async {
    if (!kIsWeb) return;

    final params = Uri.base.queryParameters;
    if (params['life_source'] != 'browser_extension') return;

    final action = (params['life_action'] ?? '').trim();
    if (action.isEmpty) return;

    final requestId = (params['life_request'] ?? '').trim();
    if (requestId.isEmpty) return;

    final prefs = await _browserExtensionPrefs();
    if (prefs == null) return;

    final alreadyConsumed =
        await _browserExtensionRequestWasConsumed(prefs, requestId);
    if (alreadyConsumed) {
      await _publishBrowserExtensionRecordSnapshot();
      await _writeBrowserExtensionResponse(
        requestId: requestId,
        action: action,
        ok: true,
      );
      if (action == 'quick_add') {
        final target = params['life_target'] == 'list' ? 'list' : 'plan';
        if (mounted) _showBrowserExtensionTarget(target);
      }
      return;
    }

    switch (action) {
      case 'bridge_sync':
        try {
          await DatabaseService.instance.getRecords(forceNetwork: true);
        } catch (_) {}
        await _publishBrowserExtensionRecordSnapshot();
        await _markBrowserExtensionRequestConsumed(prefs, requestId);
        await _writeBrowserExtensionResponse(
          requestId: requestId,
          action: action,
          ok: true,
        );
        return;

      case 'start_record':
        final rawText = (params['life_text'] ?? '').trim();
        if (rawText.isEmpty) {
          await _writeBrowserExtensionResponse(
            requestId: requestId,
            action: action,
            ok: false,
            error: 'empty_record_title',
          );
          return;
        }
        final db = DatabaseService.instance;
        final recordId = await db.startTimer(rawText);
        if (recordId != null && recordId.trim().isNotEmpty) {
          try {
            await db.primaryRecordWriteNetworkChain;
            await db.getRecords(forceNetwork: true);
          } catch (_) {}
        }
        final confirmed = db.browserExtensionActiveRecordSnapshot();
        final ok =
            recordId != null &&
            recordId.trim().isNotEmpty &&
            confirmed['active'] == true &&
            confirmed['recordId']?.toString().trim() == recordId.trim();
        if (ok) {
          await _markBrowserExtensionRequestConsumed(prefs, requestId);
        }
        await _publishBrowserExtensionRecordSnapshot();
        await _writeBrowserExtensionResponse(
          requestId: requestId,
          action: action,
          ok: ok,
          error: ok ? null : 'record_start_failed',
        );
        return;

      case 'stop_record':
        final db = DatabaseService.instance;
        final ok = await db.stopAllRunningRecords();
        if (ok) {
          try {
            await db.getRecords(forceNetwork: true);
          } catch (_) {}
          await _markBrowserExtensionRequestConsumed(prefs, requestId);
        }
        await _publishBrowserExtensionRecordSnapshot();
        await _writeBrowserExtensionResponse(
          requestId: requestId,
          action: action,
          ok: ok,
          error: ok ? null : 'record_stop_failed',
        );
        return;

      case 'quick_add':
        final rawText = (params['life_text'] ?? '').trim();
        if (rawText.isEmpty) return;
        final target = params['life_target'] == 'list' ? 'list' : 'plan';
        final wallDay = DatabaseService.instance.getTimelineDeviceLocalToday();
        final added =
            await DatabaseService.instance.addPlanningTaskFromVoiceText(
          rawText: rawText,
          wallDay: wallDay,
          isBacklog: target == 'list',
        );
        if (!mounted) return;
        if (!added) {
          await _writeBrowserExtensionResponse(
            requestId: requestId,
            action: action,
            ok: false,
            error: 'quick_add_failed',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(currentLocale.value, 'sync_failed_retry'))),
          );
          return;
        }
        await _markBrowserExtensionRequestConsumed(prefs, requestId);
        await _publishBrowserExtensionRecordSnapshot();
        await _writeBrowserExtensionResponse(
          requestId: requestId,
          action: action,
          ok: true,
        );
        if (mounted) _showBrowserExtensionTarget(target);
        return;

      default:
        await _writeBrowserExtensionResponse(
          requestId: requestId,
          action: action,
          ok: false,
          error: 'unknown_action',
        );
    }
  }

  void _showBrowserExtensionTarget(String target) {
    final nextIndex = target == 'list' ? 3 : 1;
    final wallDay = DatabaseService.instance.getTimelineDeviceLocalToday();
    setState(() {
      shellPageIndex = nextIndex;
      if (nextIndex == 1) {
        selectedDate = wallDay;
        focusedDay = wallDay;
      }
    });
    shellPageIndexListenable.value = nextIndex;
    if (nextIndex == 1) {
      selectedDateListenable.value = wallDay;
    }
  }
}
