part of '../app_shell.dart';

mixin ShellChrome on ShellLifecycle, ShellMoreMenu {
  List<Widget> buildShellPages() => <Widget>[
    timelineTabHost,
    planningTabHost,
    calendarTabHost,
    listsTabHost,
    StreamBuilder<List<CategoryRule>>(
      stream: DatabaseService.instance.categoryStream,
      initialData: rules,
      builder: (context, snapshot) {
        final r = snapshot.data ?? rules;
        return CategoriesPage(
          rules: r,
          onChanged: () async {
            if (mounted) {
              setState(() {
                rules = List.from(DatabaseService.instance.rules);
              });
            }
          },
        );
      },
    ),
    LifeOsSettingsTabsPage(
      onAction: onLifeOsMenuAction,
      initialTab: 'profile',
      activeTab: shellPageIndexListenable,
      shellTabIndex: 5,
    ),
    const PathsPage(),
    LifeOsSettingsTabsPage(
      onAction: onLifeOsMenuAction,
      activeTab: shellPageIndexListenable,
      shellTabIndex: 7,
    ),
    PeopleSettingsPage(
      key: ValueKey(peopleDestination),
      initialSection: peopleDestination,
      activeTab: shellPageIndexListenable,
      onBackToMenu: () => setState(() => setShellPageIndex(7)),
    ),
    ProfilePage(
      key: ValueKey(profileDestination),
      initialDestination: profileDestination,
      embeddedInShell: true,
      onBackToMenu: () => setState(() => setShellPageIndex(
          profileDestination == ProfileSettingsDestination.account ||
                  profileDestination == ProfileSettingsDestination.security ||
                  profileDestination == ProfileSettingsDestination.session
              ? 5
              : 7)),
      onSaved: () {
        if (mounted) setState(() {});
        unawaited(refreshDesktopTrayMenu());
      },
      onDesktopVoiceHotkeyChanged: (_) => reattachDesktopVoiceHotkey(),
      onOpenViktor: () => unawaited(openViktor()),
      onTestDesktopVoice: () => unawaited(openViktor()),
    ),
  ];

  Widget buildShellDashboard(BuildContext context) {
    rebuildMetricsTick('AppShell');
    final pages = buildShellPages();

    return AnimatedBuilder(
      animation: currentLocale,
      builder: (context, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: desktopVoiceShellSuppressed,
          builder: (context, shellSuppressed, _) {
            if (shellSuppressed) {
              return const ColoredBox(
                color: AppNeutralTones.transparent,
                child: SizedBox.expand(),
              );
            }
            final shellSw = Stopwatch()..start();
            final scheme = Theme.of(context).colorScheme;
            shellLayout.applyShellFrame(shellPageIndex);
            final loc = currentLocale.value;
            final desktopShell =
                shellFormFactorForWidth(MediaQuery.sizeOf(context).width) ==
                ShellFormFactor.desktop;
            final builtTabs = kShellDeferHiddenTabsUntilFirstFrame
                ? 1
                : pages.length;
            final shell = StreamBuilder<UserSettings>(
              stream: DatabaseService.instance.userSettingsStream,
              initialData: DatabaseService.instance.settings,
              builder: (context, settingsSnap) {
                final tagMode =
                    settingsSnap.data?.tagDisplayMode ??
                    CategoryDisplayMode.letterChip;
                return TagDisplayModeScope(
                  mode: tagMode,
                  child: AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      statusBarColor: AppNeutralTones.transparent,
                      statusBarIconBrightness: desktopShell ||
                              (shellPageIndex > 3 &&
                                  scheme.brightness == Brightness.light)
                          ? Brightness.dark : Brightness.light,
                      statusBarBrightness: desktopShell ||
                              (shellPageIndex > 3 &&
                                  scheme.brightness == Brightness.light)
                          ? Brightness.light : Brightness.dark,
                      systemNavigationBarIconBrightness:
                          scheme.brightness == Brightness.light
                              ? Brightness.dark : Brightness.light,
                      systemNavigationBarColor: scheme.surface,
                    ),
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                      },
                      child: ShellLayoutScope(
                        controller: shellLayout,
                        child: Scaffold(
                          backgroundColor: scheme.surface,
                          resizeToAvoidBottomInset: true,
                          // Let Settings content scroll underneath the frosted bottom bar.
                          extendBody: !desktopShell &&
                              (shellPageIndex == 5 || shellPageIndex == 7),
                          // Keep identical app chrome across every desktop destination.
                          appBar: desktopShell || (!desktopShell && shellPageIndex <= 3)
                              ? AppBar(
                                  toolbarHeight: kGlobalCompactHeaderHeight,
                                  backgroundColor: desktopShell
                                      ? AppNeutralTones.white
                                      : kGlobalCompactHeaderColor,
                                  foregroundColor: desktopShell
                                      ? scheme.onSurface
                                      : kGlobalCompactHeaderForeground,
                                  surfaceTintColor: AppNeutralTones.transparent,
                                  automaticallyImplyLeading: false,
                                  elevation: 0,
                                  scrolledUnderElevation: 0,
                                  titleSpacing: 16,
                                  shape: desktopShell
                                      ? Border(
                                          bottom: BorderSide(
                                            color: scheme.outlineVariant
                                                .withValues(alpha: 0.65),
                                          ),
                                        )
                                      : null,
                                  title: Row(
                                    children: [
                                      if (desktopShell ||
                                          MediaQuery.sizeOf(context).width >= 430) ...[
                                      if (desktopShell) ...[
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: scheme.onSurface,
                                            borderRadius: BorderRadius.circular(9),
                                          ),
                                          child: const SizedBox(
                                            height: 28,
                                            width: 28,
                                            child: Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 17,
                                              color: AppNeutralTones.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Text(
                                        desktopShell ? 'LIFE OS' : t(loc, 'app_title'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: desktopShell
                                                  ? scheme.onSurface
                                                  : kGlobalCompactHeaderForeground,
                                              fontWeight: FontWeight.w700,
                                              height: 1.0,
                                            ),
                                      ),
                                      const SizedBox(width: 12),
                                      ],
                                      Expanded(
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional.centerEnd,
                                          child: ListenableBuilder(
                                            listenable: selectedDateListenable,
                                            builder: (context, _) =>
                                                GlobalAppHeader(
                                                  selectedDate: selectedDate,
                                                  onDateSelected:
                                                      selectShellHeaderDate,
                                                  compact: true,
                                                  foregroundColor: desktopShell
                                                      ? scheme.onSurface
                                                      : null,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    AppIconButton(
                                      icon: Icons.auto_awesome_rounded,
                                      tooltip: 'Виктор — ИИ-помощник',
                                      onPressed: () => unawaited(openViktor()),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                )
                              : null,
                          body: LayoutBuilder(
                            builder: (context, constraints) {
                              final formFactor = shellFormFactorForWidth(
                                constraints.maxWidth,
                              );
                              final mainColumn = Column(
                                children: [
                                  const ShellTopStatusBars(),
                                  Expanded(
                                    child: kShellDeferHiddenTabsUntilFirstFrame
                                        ? LazyIndexedStack(
                                            index: shellPageIndex,
                                            children: pages,
                                          )
                                        : ShellFlags.useLazyIndexedStack
                                        ? LazyIndexedStack(
                                            index: shellPageIndex,
                                            children: pages,
                                          )
                                        : IndexedStack(
                                            index: shellPageIndex,
                                            sizing: StackFit.expand,
                                            children: pages,
                                          ),
                                  ),
                                ],
                              );
                              // Settings has no AppBar: respect camera/status-bar
                              // insets instead of painting text under system icons.
                              final settingsScreen = shellPageIndex == 5 ||
                                  shellPageIndex == 7;
                              final compactContent = settingsScreen
                                  ? SafeArea(top: true, bottom: false, child: mainColumn)
                                  : mainColumn;
                              return switch (formFactor) {
                                ShellFormFactor.desktop => DesktopShellFrame(
                                  selectedIndex: desktopSideNavSelectedIndex(
                                    shellPageIndex,
                                  ),
                                  onTabSelected: onDesktopSideNavSelected,
                                  child: mainColumn,
                                ),
                                ShellFormFactor.tablet => TabletShellFrame(
                                  child: compactContent,
                                ),
                                ShellFormFactor.phone => PhoneShellFrame(
                                  child: compactContent,
                                ),
                              };
                            },
                          ),
                          // Viktor is in the header/Menu, never floating over plan cards.
                          floatingActionButton: null,
                          bottomNavigationBar: LayoutBuilder(
                            builder: (context, constraints) {
                              final formFactor = shellFormFactorForWidth(
                                constraints.maxWidth,
                              );
                              if (formFactor == ShellFormFactor.desktop) {
                                return const SizedBox.shrink();
                              }
                              return PhoneShellBottomNavigation(
                                viewportWidth: constraints.maxWidth,
                                selectedIndex: navBarSelectedIndex,
                                onDestinationSelected: onShellTabSelected,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
            shellSw.stop();
            StartupLog.shellBuild(
              activeTab: ShellDashboardBase.shellTabDiagnosticLabel(
                shellPageIndex,
              ),
              ms: shellSw.elapsedMilliseconds,
              builtTabs: builtTabs,
            );
            if (DesktopVoiceHotkey.isActive) {
              return Shortcuts(
                shortcuts: {
                  DesktopVoiceHotkey.inAppActivator:
                      const DesktopVoiceCommandIntent(),
                },
                child: Actions(
                  actions: {
                    DesktopVoiceCommandIntent:
                        CallbackAction<DesktopVoiceCommandIntent>(
                          onInvoke: (_) {
                            unawaited(openViktor());
                            return null;
                          },
                        ),
                  },
                  child: shell,
                ),
              );
            }
            return shell;
          },
        );
      },
    );
  }
}
