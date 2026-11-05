part of '../app_shell.dart';

mixin ShellMoreMenu on ShellCoreLogic {
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

  void openMoreMenu({bool secondaryOnly = false}) {
    final loc = currentLocale.value;
    final isRu = loc.toLowerCase().startsWith('ru');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      builder: (sheetContext) => StreamBuilder<UserSettings>(
        stream: DatabaseService.instance.userSettingsStream,
        initialData: DatabaseService.instance.settings,
        builder: (context, snapshot) {
          final isAdmin =
              snapshot.data?.isAdmin ??
              DatabaseService.instance.settings.isAdmin;

          void navigateTo(int index) {
            Navigator.of(sheetContext).pop();
            setState(() => setShellPageIndex(index));
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.80,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(5, 2, 0, 16),
                      child: Text(
                        isRu ? 'Ещё' : 'More',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    AppSettingsNavigationGroup(
                      children: [
                        AppMenuActionTile(
                          leading: const AppSettingsMenuIcon(
                            icon: Icons.auto_awesome_rounded,
                          ),
                          title: Text(isRu ? 'Виктор · ИИ' : 'Viktor · AI'),
                          subtitle: Text(isRu
                              ? 'Общение, планы и голосовые команды'
                              : 'Chat, planning and voice commands'),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(openViktor());
                          },
                        ),
                      ],
                    ),
                    AppSettingsNavigationGroup(
                      children: [
                        if (!secondaryOnly)
                          AppMenuActionTile(
                            leading: const AppSettingsMenuIcon(
                              icon: Icons.person_outline_rounded,
                            ),
                            title: Text(t(loc, 'more_menu_profile')),
                            onTap: () => navigateTo(5),
                          ),
                        if (!secondaryOnly)
                          AppMenuActionTile(
                            leading: const AppSettingsMenuIcon(
                              icon: Icons.label_outline_rounded,
                            ),
                            title: Text(t(loc, 'more_menu_categories')),
                            onTap: () => navigateTo(4),
                          ),
                        AppMenuActionTile(
                          leading: const AppSettingsMenuIcon(
                            icon: Icons.alt_route_rounded,
                          ),
                          title: Text(
                              isRu ? 'Пути проектов' : 'Project paths'),
                          subtitle: Text(isRu
                              ? 'От цели до конкретных действий'
                              : 'From goals to concrete actions'),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            openProjectPaths();
                          },
                        ),
                      ],
                    ),
                    if (isAdmin || _desktopVoiceDevDiagnosticsVisible)
                      AppSettingsNavigationGroup(
                        children: [
                          if (isAdmin)
                            AppMenuActionTile(
                              leading: const AppSettingsMenuIcon(
                                icon: Icons.design_services_outlined,
                              ),
                              title: const Text('Dev / Design Lab'),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const ComponentLabPage(),
                                  ),
                                );
                              },
                            ),
                          if (_desktopVoiceDevDiagnosticsVisible)
                            AppMenuActionTile(
                              leading: const AppSettingsMenuIcon(
                                icon: Icons.graphic_eq_rounded,
                              ),
                              title: Text(
                                  t(loc, 'more_menu_voice_diagnostics')),
                              subtitle: Text(
                                  t(loc, 'more_menu_voice_diagnostics_subtitle')),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                showDesktopVoiceAttemptDialog(context);
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
    // 0–3 primary tabs, 4 Categories, 5 Profile, 6 Paths, 7 More.
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
      0 || 1 || 2 || 3 || 4 || 5 || 6 => shellPageIndex,
      _ => 7,
    };
  }
}
