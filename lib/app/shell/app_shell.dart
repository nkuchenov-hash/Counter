// Life OS dashboard — shell state + composition root.

import 'dart:async';
import 'dart:io' show exit, Platform;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/shared/voice/diagnostics/desktop_voice_log.dart';
import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/shared/diagnostics/startup_log.dart';
import 'package:counter/core/navigation/app_navigator.dart';
import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';
import 'package:counter/shared/diagnostics/performance/runtime_flags.dart';
import 'package:counter/shared/diagnostics/performance/shell_flags.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_tray_service.dart';
import 'package:counter/shared/voice/routing/desktop_voice_acceptance_bridge.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_confirmation.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_installed_identity.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_overlay_bridge.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_overlay_host.dart';
import 'package:counter/data/voice/desktop_voice_record_submit.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_hotkey.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_hotkey_markers.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_settings.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_smoke_bridge.dart';
import 'package:counter/shared/voice/recognition/speech_engine_handle.dart';
import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/core/widgets/lazy_indexed_stack.dart';
import 'package:counter/core/widgets/tag_display_mode_scope.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice/voice_command_parser.dart';
import 'package:counter/features/calendar/calendar_view.dart';
import 'package:counter/features/settings/categories/category_list_view.dart';
import 'package:counter/features/dev/component_lab_view.dart';
import 'package:counter/features/lists/lists_view.dart';
import 'package:counter/features/paths/paths_page.dart';
import 'package:counter/features/planning/planning_view.dart';
import 'package:counter/features/settings/voice/desktop_voice_attempt_dialog.dart';
import 'package:counter/features/profile/profile_view.dart';
import 'package:counter/features/voice/desktop_voice_widget.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/shared/voice/ui/voice_capture_config.dart';
import 'package:counter/shared/voice/ui/voice_input_sheet.dart';
import 'package:counter/features/timeline/timeline_view.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/app/shell/desktop/desktop_shell_frame.dart';
import 'package:counter/app/shell/phone/phone_shell_frame.dart';
import 'package:counter/app/shell/shared/shell_form_factor.dart';
import 'package:counter/app/shell/shared/shell_offline_banner.dart';
import 'package:counter/app/shell/shared/shell_shared.dart';
import 'package:counter/data/paths/compatibility/path_governance_service.dart';
import 'package:counter/app/shell/tablet/tablet_shell_frame.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

part 'shared/shell_core.dart';
part 'shared/shell_task_actions.dart';
part 'shared/shell_tab_host.dart';
part 'shared/shell_edit_hosts.dart';
part 'shared/shell_more_menu.dart';
part 'shared/shell_voice_routing.dart';
part 'shared/shell_lifecycle.dart';
part 'shared/shell_chrome.dart';

mixin ShellDashboardBase on State<LifeOSDashboard> {
  /// 0 Timeline, 1 Planning, 2 Calendar, 3 Lists, 4 Categories, 5 Profile,
  /// 6 Paths.
  int shellPageIndex = 0;

  int get navBarSelectedIndex => shellPageIndex <= 3 ? shellPageIndex : 4;

  static String shellTabDiagnosticLabel(int shellPageIndex) {
    return switch (shellPageIndex) {
      0 => 'timeline',
      1 => 'plan',
      2 => 'calendar',
      3 => 'lists',
      4 => 'categories',
      5 => 'profile',
      6 => 'paths',
      _ => 'tab$shellPageIndex',
    };
  }

  late DateTime selectedDate;
  late DateTime focusedDay;

  final List<Task> tasks = <Task>[];
  bool tasksLoading = true;
  late final ValueNotifier<DateTime> selectedDateListenable;
  final ValueNotifier<int> timelineTasksRevision = ValueNotifier(0);
  final ValueNotifier<int> shellPageIndexListenable = ValueNotifier(0);
  late final Widget timelineTabHost;
  late final Widget planningTabHost;
  late final Widget calendarTabHost;
  late final Widget listsTabHost;
  late List<CategoryRule> rules;
  int? selectedCategoryId;

  final titleController = TextEditingController();
  final titleFocus = FocusNode();

  StreamSubscription<String?>? notificationSub;
  StreamSubscription<List<CategoryRule>>? categoryRulesSub;

  final ShellLayoutController shellLayout = ShellLayoutController();

  stt.SpeechToText? speech;
  SpeechEngineHandle? speechHandle;
  bool speechReady = false;

  /// Last engine init failure (shown with [speech_unavailable] snackbar detail).
  String? speechLastInitError;
  bool isVoiceListening = false;
  void Function(String)? speechStatusCallback;

  /// Tracks device-local calendar day so an open session can follow midnight without restart.
  Timer? deviceLocalMidnightWatchTimer;
  DateTime? deviceTodayAtLastMidnightCheck;
  String? deviceLocalDayKeyLast;

  /// Coalesce rapid Play / Start actions (500ms) to avoid double-running timers.
  DateTime? lastPlayOrStartAction;
  static const Duration playStartDebounce = Duration(milliseconds: 500);

  /// Stop button / callback: ignore duplicate taps within 300ms (double-dispatch guard).
  DateTime? lastStopRecordAction;
  static const Duration stopRecordDebounce = Duration(milliseconds: 300);

  /// Stops sync-failure SnackBars from stacking when rebuilds/errors repeat (e.g. page loop).
  DateTime? lastSyncFailedSnackAt;
  static const Duration syncFailedSnackThrottle = Duration(seconds: 4);

  String get selectedDateString =>
      '${selectedDate.year}-${shellTwoDigits(selectedDate.month)}-${shellTwoDigits(selectedDate.day)}';

  /// Calendar day key for **live** timeline voice (running record starts “now”).
  String get timelineVoiceDateKey {
    final d = DatabaseService.instance.getTimelineDeviceLocalToday();
    return '${d.year}-${shellTwoDigits(d.month)}-${shellTwoDigits(d.day)}';
  }

  bool get isFutureDate => selectedDate.isAfter(shellLocalToday());

  int? get effectiveCategoryId =>
      selectedCategoryId ?? DatabaseService.instance.defaultCategoryId;
}

class LifeOSDashboard extends StatefulWidget {
  const LifeOSDashboard({super.key});

  @override
  State<LifeOSDashboard> createState() => ShellDashboardState();
}

class ShellDashboardState extends State<LifeOSDashboard>
    with
        ShellDashboardBase,
        ShellCoreLogic,
        ShellTaskActions,
        ShellTabHost,
        ShellEditHosts,
        ShellMoreMenu,
        ShellVoiceRouting,
        ShellLifecycle,
        ShellChrome {
  @override
  void initState() {
    super.initState();
    initializeShellLifecycle();
  }

  @override
  void dispose() {
    disposeShellLifecycle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildShellDashboard(context);
}

class DesktopVoiceCommandIntent extends Intent {
  const DesktopVoiceCommandIntent();
}
