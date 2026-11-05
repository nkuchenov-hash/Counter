part of '../app_shell.dart';

mixin ShellMoreMenu on ShellVoiceIntegration {
  static bool _moreMenuDiagnosticsMarkerLogged = false;

  bool get _desktopVoiceDevDiagnosticsVisible {
    const devToolsDefine = bool.fromEnvironment(
      'DESKTOP_VOICE_DEV_TOOLS',
      defaultValue: false,
    );
    final visible = kDebugMode || devToolsDefine;
    if (!_moreMenuDiagnosticsMarkerLogged) {
      _moreMenuDiagnosticsMarkerLogged = true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_MORE_MENU_DIAGNOSTICS_REMOVED');
      if (visible) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_DEV_ENTRY_GATED', 'dev_only');
      }
    }
    return visible;
  }

  void openProjectPaths() {
    if (shellPageIndex == 6) return;
    setState(() => setShellPageIndex(6));
  }

  Future<void> openViktor() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ViktorChatPage(wallDay: shellDateOnly(selectedDate)),
      ),
    );
  }

  /// The full-screen Menu tab replaces the previous mixed-action bottom sheet.
  /// Feature-local sheets stay available at their own entry points.
  void openMoreMenu({bool secondaryOnly = false}) {
    setState(() => setShellPageIndex(7));
  }

  void _openProfileDestination(ProfileSettingsDestination target) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          initialDestination: target,
          onSaved: () {
            if (mounted) setState(() {});
            unawaited(refreshDesktopTrayMenu());
          },
          onDesktopVoiceHotkeyChanged: (_) => reattachDesktopVoiceHotkey(),
          onTestDesktopVoice: () => unawaited(openViktor()),
          onOpenViktor: () => unawaited(openViktor()),
        ),
      ),
    );
  }

  void _navigateToWorkspace(int tab) {
    setState(() => setShellPageIndex(tab));
    if (tab == 0 || tab == 1) {
      final target = DatabaseService.instance.getTimelineDeviceLocalToday();
      applySharedSelectedDate(target, loadTimelineTasks: tab == 0);
    }
  }

  void onLifeOsMenuAction(LifeOsMenuAction action) {
    switch (action) {
      case LifeOsMenuAction.viktor:
        unawaited(openViktor());
        break;
      case LifeOsMenuAction.paths:
        openProjectPaths();
        break;
      case LifeOsMenuAction.people:
        setState(() {
          peopleDestination = PeopleSettingsDestination.people;
          setShellPageIndex(8);
        });
        break;
      case LifeOsMenuAction.peopleSources:
        setState(() {
          peopleDestination = PeopleSettingsDestination.sources;
          setShellPageIndex(8);
        });
        break;
      case LifeOsMenuAction.categories:
      case LifeOsMenuAction.categoryAppearance:
        _navigateToWorkspace(4);
        break;
      case LifeOsMenuAction.tags:
        Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => const TagSettingsHub()));
        break;
      case LifeOsMenuAction.tagAppearance:
        Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => const TagSettingsHub(initialTabIndex: 1)));
        break;
      case LifeOsMenuAction.tagDurations:
        Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => const TagSettingsHub(initialTabIndex: 2)));
        break;
      case LifeOsMenuAction.planning:
        _navigateToWorkspace(1);
        break;
      case LifeOsMenuAction.defaultPlanTimes:
        _navigateToWorkspace(1);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) PlanningSettingsNavigationRequests.requestDefaultTimes();
        });
        break;
      case LifeOsMenuAction.planningSettings:
        Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => LifeOsPlanningSettingsPage(
            onOpenDefaultPlanTimes: () {
              Navigator.of(context).pop();
              _navigateToWorkspace(1);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  PlanningSettingsNavigationRequests.requestDefaultTimes();
                }
              });
            },
          )));
        break;
      case LifeOsMenuAction.notes:
        _navigateToWorkspace(3);
        break;
      case LifeOsMenuAction.notesCategoryBar:
        _navigateToWorkspace(3);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) NotesLibraryPreferences.requestCategoryBarEditor();
        });
        break;
      case LifeOsMenuAction.notesSettings:
        Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => LifeOsNotesSettingsPage(
            onOpenCategoryBar: () {
              Navigator.of(context).pop();
              _navigateToWorkspace(3);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) NotesLibraryPreferences.requestCategoryBarEditor();
              });
            },
          )));
        break;
      case LifeOsMenuAction.calendars:
        _openProfileDestination(ProfileSettingsDestination.calendars);
        break;
      case LifeOsMenuAction.notifications:
        _openProfileDestination(ProfileSettingsDestination.notifications);
        break;
      case LifeOsMenuAction.morning:
        _openProfileDestination(ProfileSettingsDestination.morning);
        break;
      case LifeOsMenuAction.sleep:
        _openProfileDestination(ProfileSettingsDestination.sleep);
        break;
      case LifeOsMenuAction.voiceSettings:
        _openProfileDestination(ProfileSettingsDestination.voice);
        break;
      case LifeOsMenuAction.appearance:
        _openProfileDestination(ProfileSettingsDestination.appearance);
        break;
      case LifeOsMenuAction.languageAndTime:
        _openProfileDestination(ProfileSettingsDestination.timeLocale);
        break;
      case LifeOsMenuAction.account:
        if (shellFormFactorForWidth(MediaQuery.sizeOf(context).width) ==
            ShellFormFactor.desktop) {
          setState(() => setShellPageIndex(5));
        } else {
          _openProfileDestination(ProfileSettingsDestination.account);
        }
        break;
      case LifeOsMenuAction.about:
        _openProfileDestination(ProfileSettingsDestination.about);
        break;
      case LifeOsMenuAction.syncStatus:
      case LifeOsMenuAction.diagnostics:
        Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => const LifeOsSyncStatusPage()));
        break;
      case LifeOsMenuAction.componentLab:
        if (!DatabaseService.instance.settings.isAdmin) return;
        Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => const ComponentLabPage()));
        break;
      case LifeOsMenuAction.voiceDiagnostics:
        if (_desktopVoiceDevDiagnosticsVisible) {
          showDesktopVoiceAttemptDialog(context);
        }
        break;
    }
  }

  void onShellTabSelected(int i) {
    if (i == 4) {
      openMoreMenu(secondaryOnly: false);
      return;
    }
    setState(() => setShellPageIndex(i));
    if (i == 0 || i == 1) {
      final target = DatabaseService.instance.getTimelineDeviceLocalToday();
      applySharedSelectedDate(target, loadTimelineTasks: i == 0);
    }
  }

  void onDesktopSideNavSelected(int navIndex) {
    // 0–3 workspace tabs, 6 Paths, 8 People, 7 Menu, 5 Account.
    if (navIndex == 8) {
      onLifeOsMenuAction(LifeOsMenuAction.people);
      return;
    }
    if (navIndex == 5) {
      // Profile is one shell destination, not a settings hub pushed over Menu.
      setState(() => setShellPageIndex(5));
      return;
    }
    if (navIndex == 6) {
      openProjectPaths();
      return;
    }
    if (navIndex == 7) {
      openMoreMenu(secondaryOnly: true);
      return;
    }
    if (navIndex <= 5) {
      setState(() => setShellPageIndex(navIndex));
      if (navIndex == 0 || navIndex == 1) {
        final target = DatabaseService.instance.getTimelineDeviceLocalToday();
        applySharedSelectedDate(target, loadTimelineTasks: navIndex == 0);
      }
    }
  }

  int desktopSideNavSelectedIndex(int shellPageIndex) {
    return switch (shellPageIndex) {
      0 || 1 || 2 || 3 || 4 || 5 || 6 || 8 => shellPageIndex,
      _ => 7,
    };
  }
}
