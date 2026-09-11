part of '../app_shell.dart';

const String _browserExtensionConsumedRequestIdsKey =
    'browser_extension_consumed_request_ids_v1';
const int _browserExtensionConsumedRequestLimit = 32;

mixin ShellBrowserExtensionQuickAdd on ShellDashboardBase {
  Future<void> consumeBrowserExtensionQuickAddIfPresent() async {
    if (!kIsWeb) return;

    final params = Uri.base.queryParameters;
    if (params['life_source'] != 'browser_extension' ||
        params['life_action'] != 'quick_add') {
      return;
    }

    final requestId = (params['life_request'] ?? '').trim();
    final rawText = (params['life_text'] ?? '').trim();
    if (requestId.isEmpty || rawText.isEmpty) return;

    final target = params['life_target'] == 'list' ? 'list' : 'plan';

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }

    final consumed = prefs.getStringList(
          _browserExtensionConsumedRequestIdsKey,
        ) ??
        <String>[];
    if (consumed.contains(requestId)) {
      if (mounted) _showBrowserExtensionTarget(target);
      return;
    }

    final wallDay = DatabaseService.instance.getTimelineDeviceLocalToday();
    final added = await DatabaseService.instance.addPlanningTaskFromVoiceText(
      rawText: rawText,
      wallDay: wallDay,
      isBacklog: target == 'list',
    );
    if (!mounted) return;

    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'sync_failed_retry'))),
      );
      return;
    }

    final next = <String>[
      for (final id in consumed)
        if (id != requestId) id,
      requestId,
    ];
    if (next.length > _browserExtensionConsumedRequestLimit) {
      next.removeRange(0, next.length - _browserExtensionConsumedRequestLimit);
    }
    await prefs.setStringList(_browserExtensionConsumedRequestIdsKey, next);
    if (!mounted) return;

    _showBrowserExtensionTarget(target);
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
