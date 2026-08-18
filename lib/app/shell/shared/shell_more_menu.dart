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

  void openMoreMenu({bool secondaryOnly = false}) {
    final loc = currentLocale.value;
    final isRu = loc.toLowerCase().startsWith('ru');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StreamBuilder<UserSettings>(
        stream: DatabaseService.instance.userSettingsStream,
        initialData: DatabaseService.instance.settings,
        builder: (context, snapshot) {
          final isAdmin =
              snapshot.data?.isAdmin ??
              DatabaseService.instance.settings.isAdmin;
          debugPrint(
            '[ADMIN_FLAG] More bottom sheet settings.isAdmin=$isAdmin renderDevLab=$isAdmin',
          );
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!secondaryOnly) ...[
                  ListTile(
                    leading: const Icon(Icons.person_rounded),
                    title: Text(t(loc, 'more_menu_profile')),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => setShellPageIndex(5));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.label_rounded),
                    title: Text(t(loc, 'more_menu_categories')),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => setShellPageIndex(4));
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.alt_route_rounded),
                  title: Text(isRu ? 'Пути проектов' : 'Project paths'),
                  subtitle: Text(
                    isRu
                        ? 'От конечной цели до действий не длиннее 30 минут'
                        : 'From the end goal to actions no longer than 30 minutes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    openProjectPaths();
                  },
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.design_services_rounded),
                    title: const Text('Dev / Design Lab'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const ComponentLabPage(),
                        ),
                      );
                    },
                  ),
                if (_desktopVoiceDevDiagnosticsVisible)
                  ListTile(
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: Text(t(loc, 'more_menu_voice_diagnostics')),
                    subtitle: Text(
                      t(loc, 'more_menu_voice_diagnostics_subtitle'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showDesktopVoiceAttemptDialog(context);
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    'Admin flag: $isAdmin',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
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
      0 || 1 || 2 || 3 || 4 || 5 => shellPageIndex,
      _ => 7,
    };
  }
}
