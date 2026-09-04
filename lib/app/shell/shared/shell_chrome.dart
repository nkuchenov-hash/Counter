part of '../app_shell.dart';

mixin ShellChrome on ShellLifecycle, ShellMoreMenu, ShellVoiceInput {
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
    ProfilePage(
      onSaved: () {
        if (mounted) setState(() {});
        unawaited(refreshDesktopTrayMenu());
      },
      onDesktopVoiceHotkeyChanged: (_) => reattachDesktopVoiceHotkey(),
      onTestDesktopVoice: () {
        unawaited(toggleDesktopVoiceWidget());
      },
    ),
    const PathsPage(),
  ];

  String _desktopSectionTitle(String loc) => switch (shellPageIndex) {
    0 => t(loc, 'tab_timeline'),
    1 => t(loc, 'tab_planning'),
    2 => t(loc, 'calendar'),
    3 => t(loc, 'tab_lists'),
    4 => t(loc, 'more_menu_categories'),
    5 => t(loc, 'more_menu_profile'),
    6 => loc.toLowerCase().startsWith('ru') ? 'Пути' : 'Paths',
    _ => t(loc, 'app_title'),
  };

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
                color: Colors.transparent,
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
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.light,
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
                          appBar: desktopShell || shellPageIndex <= 3
                              ? AppBar(
                                  toolbarHeight: kGlobalCompactHeaderHeight,
                                  backgroundColor: desktopShell
                                      ? scheme.surface
                                      : kGlobalCompactHeaderColor,
                                  foregroundColor: desktopShell
                                      ? scheme.onSurface
                                      : kGlobalCompactHeaderForeground,
                                  surfaceTintColor: Colors.transparent,
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
                                      Text(
                                        t(loc, 'app_title'),
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
                                  if (formFactor == ShellFormFactor.desktop &&
                                      shellPageIndex != 2)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        18,
                                        24,
                                        12,
                                      ),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: Text(
                                          _desktopSectionTitle(loc),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                height: 1.1,
                                              ),
                                        ),
                                      ),
                                    ),
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
                              return switch (formFactor) {
                                ShellFormFactor.desktop => DesktopShellFrame(
                                  selectedIndex: desktopSideNavSelectedIndex(
                                    shellPageIndex,
                                  ),
                                  onTabSelected: onDesktopSideNavSelected,
                                  child: mainColumn,
                                ),
                                ShellFormFactor.tablet => TabletShellFrame(
                                  child: mainColumn,
                                ),
                                ShellFormFactor.phone => PhoneShellFrame(
                                  child: mainColumn,
                                ),
                              };
                            },
                          ),
                          floatingActionButtonLocation:
                              FloatingActionButtonLocation.endFloat,
                          floatingActionButton: ListenableBuilder(
                            listenable: selectedDateListenable,
                            builder: (context, _) {
                              final showFab =
                                  shellPageIndex != 6 &&
                                  (shellPageIndex == 1 ||
                                      shellPageIndex == 3 ||
                                      !isFutureDate);
                              if (!showFab) return const SizedBox.shrink();
                              return ListenableBuilder(
                                listenable: shellLayout,
                                builder: (context, child) {
                                  final bulkReservePx =
                                      shellLayout.fabBottomReservePx;
                                  return AnimatedPadding(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    padding: EdgeInsets.only(
                                      bottom:
                                          MediaQuery.paddingOf(context).bottom +
                                          bulkReservePx,
                                    ),
                                    child: child,
                                  );
                                },
                                child: FloatingActionButton(
                                  onPressed: startVoiceInput,
                                  tooltip: isVoiceListening
                                      ? t(currentLocale.value, 'listening')
                                      : t(currentLocale.value, 'voice_input'),
                                  child: Icon(
                                    isVoiceListening
                                        ? Icons.graphic_eq_rounded
                                        : Icons.mic_rounded,
                                  ),
                                ),
                              );
                            },
                          ),
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
                            unawaited(toggleDesktopVoiceWidget());
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
