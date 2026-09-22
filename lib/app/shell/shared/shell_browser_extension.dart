part of '../app_shell.dart';

const String _browserExtensionConsumedRequestIdsKey =
    'browser_extension_consumed_request_ids_v2';
const String _browserExtensionRecordSnapshotKey =
    'browser_extension_record_snapshot_v2';
const String _browserExtensionResponseKey =
    'browser_extension_response_v2';
const String _browserExtensionCommandKey =
    'browser_extension_command_v3';
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
    browserExtensionCommandPollTimer?.cancel();
    browserExtensionCommandPollTimer = Timer.periodic(
      const Duration(milliseconds: 350),
      (_) => unawaited(_pollBrowserExtensionCommand()),
    );
    await _publishBrowserExtensionRecordSnapshot();
    await _pollBrowserExtensionCommand();
  }

  Future<Map<String, dynamic>> _browserExtensionRecordSnapshot() async {
    final db = DatabaseService.instance;
    Map<String, dynamic>? row;
    try {
      row = await db.activeRecordStream.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
    } catch (_) {}

    final base = <String, dynamic>{
      'active': row != null,
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'locale': currentLocale.value,
      'themeMode': db.settings.themeMode,
    };
    if (row == null) return base;

    final title = (row['title'] ?? '').toString().trim();
    final start = CategoryServiceExtension.startTimeFromRecord(row);
    final businessId = (row['record_id'] ?? '').toString().trim();
    final categoryPath = db.categoryDisplayPathForRecordData(row);
    final categoryColor = db.categoryDisplayColorForRecordData(row);
    final rgbHex = (categoryColor.toARGB32() & 0x00FFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();

    return <String, dynamic>{
      ...base,
      'title': title,
      'categoryPath': categoryPath,
      'startTimeUtc': start?.toUtc().toIso8601String(),
      'recordId': businessId,
      'categoryColor': '#$rgbHex',
    };
  }

  Map<String, dynamic> _browserExtensionOptimisticRecordSnapshot({
    required String title,
    required String recordId,
  }) {
    final db = DatabaseService.instance;
    return <String, dynamic>{
      'active': true,
      'title': title,
      'categoryPath': '',
      'startTimeUtc': DateTime.now().toUtc().toIso8601String(),
      'recordId': recordId,
      'categoryColor': '',
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'locale': currentLocale.value,
      'themeMode': db.settings.themeMode,
    };
  }

  Future<void> _storeBrowserExtensionRecordSnapshot(
    Map<String, dynamic> snapshot,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _browserExtensionRecordSnapshotKey,
      jsonEncode(snapshot),
    );
  }

  Future<void> _publishBrowserExtensionRecordSnapshot() async {
    if (!kIsWeb) return;
    try {
      final snapshot = await _browserExtensionRecordSnapshot();
      await _storeBrowserExtensionRecordSnapshot(snapshot);
    } catch (_) {}
  }

  Future<void> _writeBrowserExtensionResponse({
    required String requestId,
    required String action,
    required bool ok,
    bool settled = true,
    String? error,
    Map<String, dynamic>? snapshot,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _browserExtensionResponseKey,
        jsonEncode(<String, dynamic>{
          'requestId': requestId,
          'action': action,
          'ok': ok,
          'settled': settled,
          if (error != null && error.isNotEmpty) 'error': error,
          if (snapshot != null) 'snapshot': snapshot,
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

  Future<void> _pollBrowserExtensionCommand() async {
    if (!kIsWeb || browserExtensionCommandPollInFlight) return;
    browserExtensionCommandPollInFlight = true;
    try {
      final prefs = await _browserExtensionPrefs();
      if (prefs == null) return;

      // The extension writes directly to this origin's localStorage. Reload is
      // required because SharedPreferences keeps an in-memory cache.
      await prefs.reload();
      final raw = prefs.getString(_browserExtensionCommandKey);
      if (raw == null || raw.trim().isEmpty) return;

      Map<String, dynamic>? command;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          command = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
      if (command == null) {
        await prefs.remove(_browserExtensionCommandKey);
        return;
      }

      final requestId = (command['requestId'] ?? '').toString().trim();
      final action = (command['action'] ?? '').toString().trim();
      if (requestId.isEmpty || action.isEmpty) {
        await prefs.remove(_browserExtensionCommandKey);
        return;
      }

      await _consumeBrowserExtensionCommand(
        prefs: prefs,
        requestId: requestId,
        action: action,
        rawText: (command['text'] ?? '').toString(),
        target: (command['target'] ?? '').toString(),
      );

      // Do not erase a newer command that may have arrived while this one was
      // being processed.
      await prefs.reload();
      final latestRaw = prefs.getString(_browserExtensionCommandKey);
      if (latestRaw == raw) {
        await prefs.remove(_browserExtensionCommandKey);
      }
    } finally {
      browserExtensionCommandPollInFlight = false;
    }
  }

  Future<void> consumeBrowserExtensionQuickAddIfPresent() async {
    if (!kIsWeb) return;

    final params = Uri.base.queryParameters;
    if (params['life_source'] != 'browser_extension') return;

    final action = (params['life_action'] ?? '').trim();
    final requestId = (params['life_request'] ?? '').trim();
    if (action.isEmpty || requestId.isEmpty) return;

    final prefs = await _browserExtensionPrefs();
    if (prefs == null) return;
    await _consumeBrowserExtensionCommand(
      prefs: prefs,
      requestId: requestId,
      action: action,
      rawText: params['life_text'] ?? '',
      target: params['life_target'] ?? '',
    );
  }

  Future<void> _consumeBrowserExtensionCommand({
    required SharedPreferences prefs,
    required String requestId,
    required String action,
    String rawText = '',
    String target = '',
  }) async {
    final alreadyConsumed =
        await _browserExtensionRequestWasConsumed(prefs, requestId);
    if (alreadyConsumed) {
      final snapshot = await _browserExtensionRecordSnapshot();
      await _storeBrowserExtensionRecordSnapshot(snapshot);
      await _writeBrowserExtensionResponse(
        requestId: requestId,
        action: action,
        ok: true,
        snapshot: snapshot,
      );
      if (action == 'quick_add') {
        final resolvedTarget = target == 'list' ? 'list' : 'plan';
        if (mounted) _showBrowserExtensionTarget(resolvedTarget);
      }
      return;
    }

    switch (action) {
      case 'bridge_sync':
        try {
          await DatabaseService.instance.getRecords(forceNetwork: true);
        } catch (_) {}
        final snapshot = await _browserExtensionRecordSnapshot();
        await _storeBrowserExtensionRecordSnapshot(snapshot);
        await _markBrowserExtensionRequestConsumed(prefs, requestId);
        await _writeBrowserExtensionResponse(
          requestId: requestId,
          action: action,
          ok: true,
          snapshot: snapshot,
        );
        return;

      case 'start_record':
        final text = rawText.trim();
        if (text.isEmpty) {
          await _writeBrowserExtensionResponse(
            requestId: requestId,
            action: action,
            ok: false,
            error: 'empty_record_title',
          );
          return;
        }

        final db = DatabaseService.instance;
        final recordId = await db.startTimer(text);
        final accepted = recordId != null && recordId.trim().isNotEmpty;
        if (!accepted) {
          await _publishBrowserExtensionRecordSnapshot();
          await _writeBrowserExtensionResponse(
            requestId: requestId,
            action: action,
            ok: false,
            error: 'record_start_failed',
          );
          return;
        }

        final optimisticSnapshot = _browserExtensionOptimisticRecordSnapshot(
          title: text,
          recordId: recordId.trim(),
        );
        await _markBrowserExtensionRequestConsumed(prefs, requestId);
        await _storeBrowserExtensionRecordSnapshot(optimisticSnapshot);
        await _writeBrowserExtensionResponse(
          requestId: requestId,
          action: action,
          ok: true,
          settled: false,
          snapshot: optimisticSnapshot,
        );

        // Do not block the command channel on PocketBase. Brain already made
        // the canonical Highlander handoff locally. Finish persistence and
        // authoritative reconciliation in the background.
        unawaited(
          _settleBrowserExtensionStartRecord(
            requestId: requestId,
            recordId: recordId.trim(),
          ),
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
        final snapshot = await _browserExtensionRecordSnapshot();
        await _storeBrowserExtensionRecordSnapshot(snapshot);
        await _writeBrowserExtensionResponse(
          requestId: requestId,
          action: action,
          ok: ok,
          error: ok ? null : 'record_stop_failed',
          snapshot: snapshot,
        );
        return;

      case 'quick_add':
        final text = rawText.trim();
        if (text.isEmpty) return;
        final resolvedTarget = target == 'list' ? 'list' : 'plan';
        final wallDay = DatabaseService.instance.getTimelineDeviceLocalToday();
        final added =
            await DatabaseService.instance.addPlanningTaskFromVoiceText(
          rawText: text,
          wallDay: wallDay,
          isBacklog: resolvedTarget == 'list',
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
        final snapshot = await _browserExtensionRecordSnapshot();
        await _storeBrowserExtensionRecordSnapshot(snapshot);
        await _writeBrowserExtensionResponse(
          requestId: requestId,
          action: action,
          ok: true,
          snapshot: snapshot,
        );
        if (mounted) _showBrowserExtensionTarget(resolvedTarget);
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

  Future<void> _settleBrowserExtensionStartRecord({
    required String requestId,
    required String recordId,
  }) async {
    final db = DatabaseService.instance;
    var networkOk = true;
    try {
      await db.primaryRecordWriteNetworkChain;
    } catch (_) {
      networkOk = false;
    }
    try {
      await db.getRecords(forceNetwork: true);
    } catch (_) {
      networkOk = false;
    }

    final snapshot = await _browserExtensionRecordSnapshot();
    await _storeBrowserExtensionRecordSnapshot(snapshot);
    final confirmed = snapshot['active'] == true &&
        snapshot['recordId']?.toString().trim() == recordId;
    await _writeBrowserExtensionResponse(
      requestId: requestId,
      action: 'start_record',
      ok: networkOk && confirmed,
      settled: true,
      error: networkOk && confirmed ? null : 'record_start_not_confirmed',
      snapshot: snapshot,
    );
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
