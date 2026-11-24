import 'package:counter/core/app_control_tokens.dart';
import 'package:counter/app/shell/phone/shell_bottom_navigation.dart';
import 'package:counter/app/shell/phone/phone_shell_frame.dart';
import 'package:counter/core/widgets/app_glass_edge_fade.dart';
import 'dart:io';

import 'package:counter/core/app_colors.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/features/timeline/timeline_header_controls.dart';
import 'package:counter/features/timeline/timeline_day_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:counter/app/shell/shared/shell_form_factor.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shellFormFactorForWidth', () {
    test('phone below calendar-pill compact band', () {
      expect(shellFormFactorForWidth(390), ShellFormFactor.phone);
      expect(shellFormFactorForWidth(kCalendarEventPillBreakpoint - 1),
          ShellFormFactor.phone);
    });

    test('tablet mid-width still uses compact chrome band', () {
      expect(shellFormFactorForWidth(kCalendarEventPillBreakpoint),
          ShellFormFactor.tablet);
      expect(shellFormFactorForWidth(800), ShellFormFactor.tablet);
      expect(shellFormFactorForWidth(kShellDesktopNavBreakpoint - 1),
          ShellFormFactor.tablet);
    });

    test('desktop at side-nav breakpoint', () {
      expect(shellFormFactorForWidth(kShellDesktopNavBreakpoint),
          ShellFormFactor.desktop);
      expect(shellFormFactorForWidth(1200), ShellFormFactor.desktop);
    });

    test('desktop selection matches shellUsesSideNavigation', () {
      for (final width in <double>[320, 599, 600, 899, 900, 1400]) {
        final factor = shellFormFactorForWidth(width);
        final sideNav = shellUsesSideNavigation(width);
        expect(factor == ShellFormFactor.desktop, sideNav,
            reason: 'width=$width');
      }
    });
  });

  testWidgets('Tags and Style tab content stays in readable Settings width',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: appLightTheme,
      home: Scaffold(
        body: TagSettingsTabFrame(
          child: ColoredBox(
            key: const ValueKey('tag-settings-body'),
            color: ThemeData().colorScheme.surface,
            child: const SizedBox(height: 200),
          ),
        ),
      ),
    ));
    final rect = tester.getRect(find.byKey(
      const ValueKey('tag-settings-body'),
    ));
    final expectedWidth = settingsContentMaxWidth(
      tester.element(find.byType(TagSettingsTabFrame)),
    );
    expect(rect.width, closeTo(expectedWidth, 1));
    expect(rect.center.dx, closeTo(800, 1));
    expect(rect.width, lessThan(1600));
    expect(tester.takeException(), isNull);
  });

  test('Tags and Style use canonical width; Add Tag stays near the list', () {
    final hub = File('lib/features/profile/tag_settings_hub.dart')
        .readAsStringSync();
    final manager = File('lib/features/profile/tag_manager_page.dart')
        .readAsStringSync();
    expect('TagSettingsTabFrame('.allMatches(hub), hasLength(3));
    expect(hub, contains('TagManagerPage('));
    expect(hub, contains('TagSettingsView(embeddedInHub: true)'));
    expect(manager, contains('floatingActionButton: widget.embeddedInHub'));
    expect(manager, contains('if (widget.embeddedInHub) ...['));
    expect(manager, contains("label: t(loc, 'tag_create')"));
    expect(manager, contains('ReorderableListView.builder('));
    expect(manager, contains('onReorder: _onReorder'));
  });

  test('canonical mobile shell has one navigation owner and no hit-test overlap', () {
    final shell = File('lib/app/shell/shared/shell_chrome.dart').readAsStringSync();
    final wrapper = File('lib/app/shell/phone/phone_shell_frame.dart').readAsStringSync();
    final nav = File('lib/app/shell/phone/shell_bottom_navigation.dart').readAsStringSync();
    final settings = File('lib/features/profile/menu/life_os_settings_tabs_page.dart')
        .readAsStringSync();
    final fade = File('lib/core/widgets/app_glass_edge_fade.dart')
        .readAsStringSync();
    expect('bottomNavigationBar: LayoutBuilder('.allMatches(shell), hasLength(1));
    expect('PhoneShellBottomNavigation('.allMatches(shell), hasLength(1));
    expect('ShellCompactBottomNav('.allMatches(wrapper), hasLength(1));
    expect('class ShellCompactBottomNav'.allMatches(nav), hasLength(1));
    expect(shell, contains('extendBody: !desktopShell'));
    expect(shell, contains('List<Widget> get _stableShellPages'));
    expect(shell, contains('..._stableShellPages'));
    expect(shell, contains('_stableLocale == locale'));
    expect(shell, contains('final pages = buildShellPages();'));
    expect(nav, contains('AppFrostedNavigationPanel('));
    expect(nav, isNot(contains('top: -46')));
    // One full-height shell paints the noninteractive fade and one
    // bottom navigation widget paints the capsule on top of it.
    expect('Positioned('.allMatches(wrapper), hasLength(1));
    expect('AppGlassEdgeFade('.allMatches(wrapper), hasLength(1));
    expect(nav, isNot(contains('AppGlassEdgeFade(')));
    expect(nav, isNot(contains('Positioned(')));
    expect(shell, isNot(contains('AppGlassEdgeFade(')));
    expect(shell, contains('final compactContent = mainColumn;'));
    expect(settings, contains('AppGlassEdgeFade('));
    expect(settings, contains('AppGlassEdge.top'));
    expect('class AppGlassEdgeFade'.allMatches(fade), hasLength(1));
    expect('class AppFrostedNavigationPanel'.allMatches(fade), hasLength(1));
    expect(fade, contains('ClipRRect('));
    expect(fade, contains('BackdropFilter('));
    expect(fade, contains('ImageFilter.blur(sigmaX: 18, sigmaY: 18)'));
    // Top and bottom fade without a final linear edge. Near-zero alpha
    // before the clip boundary prevents a line on moving content.
    expect(fade, contains('final topHeader = edge == AppGlassEdge.top;'));
    expect(fade, contains('0.83, 0.90, 0.95, 1.0'));
    expect('stops: fadeStops'.allMatches(fade), hasLength(2));
    expect(fade, contains('surfaceColor.withValues(alpha: 0.015)'));
    expect(fade, contains('surfaceColor.withValues(alpha: 0.008)'));
    expect(fade, contains('AppNeutralTones.transparent'));
    // Preserve the approved design-system fade when adjusting content spacing.
    expect(fade, contains('0.0, 0.12, 0.32, 0.48, 0.62, 0.74'));
    expect(fade, contains('surfaceColor.withValues(alpha: 0.98)'));
    expect(fade, contains('AppNeutralTones.white.withValues(alpha: 0.10)'));
    expect(settings, contains('clipBehavior: Clip.none'));
    expect(settings, contains('height: topInset + 162'));
    expect(settings, contains('blurSigma: 16'));
    // All compact destinations (Timeline, Planning, Calendar, Lists, Settings)
    // use the same approved bottom feather, not tab-dependent geometry/blur.
    expect(wrapper, contains('kPhoneShellDockFadeHeight = 176'));
    expect(wrapper, contains('blurSigma: 14,'));
    expect(wrapper, contains('StackFit.expand'));
    expect(nav, isNot(contains('height: settingsGlass ? 176 : 126')));
    expect(nav, isNot(contains('blurSigma: settingsGlass ? 14 : 0')));
    // Initial content starts closer to the pinned title; title/glass dimensions
    // remain untouched and scroll overlap behind the pinned header still works.
    expect(settings, contains('SizedBox(height: 56 + MediaQuery.viewPaddingOf(context).top)'));
    // No settings-specific or tab-specific second navigation appearance.
    expect(nav, isNot(contains('seamlessGlass ?')));
    expect(nav, isNot(contains('!seamlessGlass ?')));
    expect(settings, contains('AppSettingsPageBody(transparentBackground: true'));
    expect(shell, contains('systemStatusBarContrastEnforced: false'));
  });

  testWidgets('mobile settings list leaves the actual glass backdrop visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      AppSettingsPageBody(transparentBackground: true, children: [Text('Settings')]))));
    final surface = tester.widget<ColoredBox>(find.descendant(
      of: find.byType(AppSettingsPageBody), matching: find.byType(ColoredBox)).first);
    expect(surface.color, Colors.transparent);
  });

  testWidgets('phone navigation uses clipped Telegram-style glass capsule',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        extendBody: true,
        body: const PhoneShellFrame(child: ColoredBox(color: Color(0xFF333333))),
        bottomNavigationBar: ShellCompactBottomNav(
          viewportWidth: 390,
          selectedIndex: 0,
          onDestinationSelected: (index) => selected = index,
        ),
      ),
    ));
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(AppGlassEdgeFade), findsOneWidget);
    expect(find.byType(AppFrostedNavigationPanel), findsOneWidget);
    final capsule = tester.getRect(find.byType(AppFrostedNavigationPanel));
    expect(capsule.left, greaterThanOrEqualTo(12));
    expect(capsule.right, lessThanOrEqualTo(378));
    expect(find.byType(InkWell), findsNWidgets(5));
    expect(kShellBottomNavHeight, lessThan(80));
    await tester.tap(find.byType(InkWell).at(3));
    expect(selected, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('record action cannot overlap any of five nav destinations',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var selectedTab = 0; selectedTab < 5; selectedTab++) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        extendBody: true,
        body: PhoneShellFrame(child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ElevatedButton(
              key: const ValueKey('bottom-body-action'),
              onPressed: () {},
              child: const Text('Save'),
            ),
          ),
        )),
        bottomNavigationBar: ShellCompactBottomNav(
          viewportWidth: 390,
          selectedIndex: selectedTab,
          onDestinationSelected: (_) {},
        ),
      )));
      await tester.pump();
      final action = tester.getRect(
        find.byKey(const ValueKey('bottom-body-action')));
      final navInkWells = find.descendant(
        of: find.byType(ShellCompactBottomNav),
        matching: find.byType(InkWell),
      );
      expect(navInkWells, findsNWidgets(5));
      for (final navItem in tester.widgetList<InkWell>(navInkWells)) {
        final element = find.byWidget(navItem);
        final navRect = tester.getRect(element);
        expect(action.bottom <= navRect.top, isTrue,
            reason: 'Body Save and bottom navigation overlap.');
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every phone tab has capsule blur without a full-width veil',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget navFor(int selectedTab) => MaterialApp(home: Scaffold(
      extendBody: true,
      body: const PhoneShellFrame(child: ColoredBox(color: Color(0xFF333333))),
      bottomNavigationBar: ShellCompactBottomNav(
        viewportWidth: 390,
        selectedIndex: selectedTab,
        onDestinationSelected: (_) {},
      ),
    ));
    Rect? canonicalCapsule;
    Color? canonicalFade;
    for (var selectedTab = 0; selectedTab < 5; selectedTab++) {
      await tester.pumpWidget(navFor(selectedTab));
      expect(find.byType(BackdropFilter), findsNWidgets(2));
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.byType(AppGlassEdgeFade), findsOneWidget);
      expect(find.byKey(const ValueKey('life-os-canonical-bottom-fade')), findsOneWidget);
      final fadeRect = tester.getRect(find.byType(AppGlassEdgeFade));
      expect(fadeRect.height, kPhoneShellDockFadeHeight);
      expect(find.byType(InkWell), findsNWidgets(5));
      final fade = tester.widget<AppGlassEdgeFade>(
        find.byType(AppGlassEdgeFade));
      expect(fade.edge, AppGlassEdge.bottom);
      expect(fade.blurSigma, 14);
      final scheme = Theme.of(
        tester.element(find.byType(ShellCompactBottomNav)),
      ).colorScheme;
      expect(fade.surfaceColor, AppGlassEdgeFade.bottomNavigationFadeColor(scheme));
      expect(fade.surfaceColor, isNot(scheme.surface));
      final capsule = tester.getRect(find.byType(AppFrostedNavigationPanel));
      // The fade belongs to the full body, reaches behind the capsule and
      // stretches well above its paint bounds on every destination.
      expect(fadeRect.top, lessThan(capsule.top));
      expect(fadeRect.bottom, greaterThanOrEqualTo(capsule.bottom - 1));
      if (canonicalCapsule != null) {
        expect(capsule, canonicalCapsule);
        expect(fade.surfaceColor, canonicalFade);
      }
      canonicalCapsule = capsule;
      canonicalFade = fade.surfaceColor;
    }
    expect(tester.takeException(), isNull);
  });

  test('tab switches only notify Timeline/Planning when active state changes', () {
    final lifecycle = File('lib/app/shell/shared/shell_lifecycle.dart')
        .readAsStringSync();
    final core = File('lib/app/shell/shared/shell_core.dart')
        .readAsStringSync();
    expect(lifecycle, contains('timelineTabActiveListenable,'));
    expect(lifecycle, contains('planningTabActiveListenable,'));
    expect(lifecycle, contains('timelineTabActiveListenable.dispose()'));
    expect(lifecycle, contains('planningTabActiveListenable.dispose()'));
    expect(core, contains('if (shellPageIndex == index) return;'));
    expect(core, contains('timelineTabActiveListenable.value = index == 0'));
    expect(core, contains('planningTabActiveListenable.value = index == 1'));
  });

  test('footer and floating actions respect the shared navigation safe area', () {
    final calendar = File('lib/features/calendar/calendar_view.dart')
        .readAsStringSync();
    final notes = File(
      'lib/features/notes/widgets/notes_library_production_shell.dart',
    ).readAsStringSync();
    expect(calendar, contains('18 + MediaQuery.paddingOf(context).bottom'));
    expect(notes, contains('return SafeArea('));
    expect(notes, contains('top: false,'));
  });

  test('screen actions use canonical LIFE OS controls', () {
    final calendar = File('lib/features/calendar/calendar_view.dart').readAsStringSync();
    final lists = File('lib/features/lists/lists_view.dart').readAsStringSync();
    final notes = File('lib/features/notes/widgets/notes_library_production_shell.dart').readAsStringSync();
    final bulk = File('lib/features/planning/widgets/planning_bulk_bar.dart').readAsStringSync();
    final settings = File('lib/features/profile/menu/life_os_settings_tabs_page.dart').readAsStringSync();
    expect(calendar, contains('AppButton.secondary('));
    expect(calendar, contains('AppIconButton('));
    expect(calendar, isNot(contains('class _CalendarFloatingTextButton')));
    expect(calendar, isNot(contains('class _CalendarFloatingAddButton')));
    expect(lists, isNot(contains('class _HeaderSegBtn')));
    expect(lists, contains('AppIconButton('));
    expect(notes, isNot(contains('class _MobileRoundAction')));
    expect(notes, isNot(contains('class _MobileRoundActionVisual')));
    expect(notes, contains('AppIconButtonShape.circular'));
    expect(bulk, contains('AppButton.ghost('));
    expect(bulk, contains('AppIconButtonVariant.danger'));
    expect(settings, contains('56 + MediaQuery.viewPaddingOf(context).top'));
  });

  test('bottom dock feather never brightens either theme, including true black', () {
    for (final scheme in [
      AppColors.lightColorScheme(),
      AppColors.darkColorScheme(),
    ]) {
      final fade = AppGlassEdgeFade.bottomNavigationFadeColor(scheme);
      final canvasLuminance = scheme.surface.computeLuminance();
      if (canvasLuminance > 0) {
        expect(fade, isNot(scheme.surface));
        expect(fade.computeLuminance(), lessThan(canvasLuminance),
            reason: 'A non-black dock must fade downward into shadow.');
      } else {
        // No color is darker than true black. The fade must merge with the
        // black canvas rather than invent a lighter footer halo.
        expect(fade, equals(scheme.surface));
      }
      expect(fade.computeLuminance(), lessThanOrEqualTo(canvasLuminance),
          reason: 'The dock must never brighten the page.');
    }
    // Regression: dark onSurface is LIGHT, so it must not be used to
    // brighten the bottom feather (observed on Android on 18 Nov 2026).
    final dark = AppColors.darkColorScheme();
    expect(dark.onSurface.computeLuminance(),
        greaterThan(dark.surface.computeLuminance()));
    expect(AppGlassEdgeFade.bottomNavigationFadeColor(dark).computeLuminance(),
        lessThanOrEqualTo(dark.surface.computeLuminance()));
  });

  test('all five phone tabs share one unbranched glass dock', () {
    final chrome = File('lib/app/shell/shared/shell_chrome.dart')
        .readAsStringSync();
    final phone = File('lib/app/shell/phone/phone_shell_frame.dart')
        .readAsStringSync();
    final dock = File('lib/app/shell/phone/shell_bottom_navigation.dart')
        .readAsStringSync();
    expect(chrome, contains('PhoneShellBottomNavigation('));
    expect(chrome, isNot(contains('seamlessGlass:')));
    expect(phone, contains('ShellCompactBottomNav('));
    expect(phone, isNot(contains('seamlessGlass')));
    expect(dock, isNot(contains('seamlessGlass')));
    expect(phone, contains('surfaceColor: AppGlassEdgeFade.bottomNavigationFadeColor(scheme),'));
    expect('AppGlassEdgeFade('.allMatches(phone).length, 1);
    expect(dock, isNot(contains('AppGlassEdgeFade(')));
    expect('AppFrostedNavigationPanel('.allMatches(dock).length, 1);
    expect('index: '.allMatches(dock).length, 5);
  });

  group('single settings navigation', () {
    test('Settings use one native tab workspace across both shell entries', () {
      final chrome = File('lib/app/shell/shared/shell_chrome.dart')
          .readAsStringSync();
      final settings = File(
        'lib/features/profile/menu/life_os_settings_tabs_page.dart',
      ).readAsStringSync();
      expect('LifeOsSettingsTabsPage('.allMatches(chrome).length, 2);
      expect(chrome, isNot(contains('LifeOsMenuPage(')));
      expect(settings, contains('AppSettingsPageBody(children:'));
      expect(settings, contains('return Wrap('));
      expect(settings, contains('DropdownButtonFormField<String>('));
      expect(settings, isNot(contains('SingleChildScrollView(')));
      expect(settings, isNot(contains('Color(0x')));
    });

    test('Notes and notification settings edit feature-owned preferences', () {
      final settings = File(
        'lib/features/profile/menu/life_os_settings_tabs_page.dart',
      ).readAsStringSync();
      final notes = File('lib/features/lists/lists_view.dart')
          .readAsStringSync();
      expect(settings, contains('NotesLibraryPreferences.checkboxMode'));
      expect(settings, contains('NotesLibraryPreferences.setCheckboxMode'));
      expect(notes, contains('NotesLibraryPreferences.checkboxMode.addListener'));
      expect(settings, contains('UnfilledTimeGapService.instance.setMinimumGapMinutes'));
      expect(settings, contains('UnfilledTimeGapService.instance.setNotificationDelayMinutes'));
      expect(settings, contains('kNordicEntertainment'));
      expect(settings, contains('ProfileNameEditor('));
      final account = File('lib/features/profile/settings/account_settings_section.dart').readAsStringSync();
      expect(account, contains('AppTextField('));
      expect(account, contains('AppButton.primary('));
    });

    test('Account and settings destinations stay logically separated', () {
      final settings = File('lib/features/profile/menu/life_os_settings_tabs_page.dart').readAsStringSync();
      final profile = File('lib/features/profile/profile_view.dart').readAsStringSync();
      final routes = File('lib/app/shell/shared/shell_more_menu.dart').readAsStringSync();
      final security = File('lib/features/profile/settings/security_settings_section.dart').readAsStringSync();
      expect(settings, contains("_SettingsTab('about'"));
      expect(settings, isNot(contains('LifeOsMenuAction.syncStatus')));
      expect(settings, contains('ProfileNameEditor('));
      expect(profile, contains('ProfileNameEditor('));
      expect(profile, contains('alignWithSettingsBody: true'));
      expect(routes, contains('if (!DatabaseService.instance.settings.isAdmin) return;'));
      expect(security, contains('AuthBridge.changePassword('));
      expect(security, contains('AuthBridge.requestPasswordReset('));
    });

    test('Profile never opens a parallel desktop settings hub', () {
      final profile =
          File('lib/features/profile/profile_view.dart').readAsStringSync();
      expect(profile, contains('ProfileSettingsDestination.account'));
      expect(profile, isNot(contains('_buildDesktopSettings(')));
      expect(profile, isNot(contains('_desktopSettingsTab')));
      expect(profile, isNot(contains('_buildMobileSettings(')));
    });

    test('specific settings use their own destinations', () {
      final routes =
          File('lib/app/shell/shared/shell_more_menu.dart').readAsStringSync();
      for (final destination in <String>[
        'notifications', 'morning', 'appearance', 'timeLocale',
      ]) {
        expect(
          routes,
          contains(
            '_openProfileDestination(ProfileSettingsDestination.$destination);',
          ),
        );
      }
    });

    test('People stays inside the main shell instead of hiding the sidebar', () {
      final chrome = File('lib/app/shell/shared/shell_chrome.dart')
          .readAsStringSync();
      final routes = File('lib/app/shell/shared/shell_more_menu.dart')
          .readAsStringSync();
      final sidebar = File('lib/app/shell/desktop/shell_side_navigation.dart')
          .readAsStringSync();
      expect(chrome, contains('PeopleSettingsPage('));
      expect(chrome, contains('activeTab: shellPageIndexListenable'));
      expect(routes, contains('peopleDestination = PeopleSettingsDestination.people;'));
      expect(routes, contains('peopleDestination = PeopleSettingsDestination.sources;'));
      expect(routes, contains('setShellPageIndex(8)'));
      expect(routes, isNot(contains('builder: (_) => const PeopleSettingsPage(')));
      expect(sidebar, contains('AppMenuIconRole.people'));
      expect(routes, contains('|| 8 => shellPageIndex'));
    });

    test('Menu uses the same persistent desktop header as People', () {
      final chrome = File('lib/app/shell/shared/shell_chrome.dart')
          .readAsStringSync();
      expect(chrome, contains('appBar: desktopShell ||'));
      expect(chrome, isNot(contains('desktopShell && shellPageIndex != 7')));
    });

    test('Embedded People screen has contextual Back without taking over the app', () {
      final people = File('lib/features/settings/people/people_settings_page_impl.dart')
          .readAsStringSync();
      expect(people, contains('final VoidCallback? onBackToMenu;'));
      expect(people, contains('appBar: embeddedInShell && desktop ? null : AppSettingsBreadcrumbBar('));
      expect(people, contains('onBack: widget.onBackToMenu ??'));
      expect(people, contains("parentLabel: _locale.toLowerCase().startsWith('ru')"));
      expect(people, contains('canPop: selectedTab != 8'));
      expect(people, contains('if (!didPop && selectedTab == 8)'));
    });

    test('Categories use pinned frosted Settings navigation and optional search', () {
      final categories = File('lib/features/settings/categories/category_list_view.dart')
          .readAsStringSync();
      final chrome = File('lib/app/shell/shared/shell_chrome.dart')
          .readAsStringSync();
      final breadcrumb = File('lib/core/widgets/app_settings_breadcrumb_bar.dart')
          .readAsStringSync();
      expect(categories, contains('AppGlassEdgeFade('));
      expect(categories, contains("static const _searchPreferenceKey = 'life_os_categories_show_search'"));
      expect(categories, contains('if (mobileSearch && index == 0)'));
      expect(categories, contains('onPressed: _openCategoryViewSettings'));
      expect(categories, contains('onPressed: _toggleAllCategories'));
      expect(categories, contains('AppIconButtonShape.circular'));
      expect(categories, contains('widget.onBack ??'));
      expect(chrome, contains('onBack: () => setState(() => setShellPageIndex(7))'));
      expect(breadcrumb, contains('scrolledUnderElevation: 0'));
      expect(breadcrumb, contains('AppGlassEdgeFade('));
    });

    testWidgets('settings use neutral gray not blue and clear white cards',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: appLightTheme,
        home: Builder(builder: (context) {
          final scheme = settingsNeutralTheme(context).colorScheme;
          expect(scheme.surface, const Color(0xFFF7F7F7));
          expect(scheme.surfaceContainerLowest, const Color(0xFFF7F7F7));
          expect(scheme.surfaceContainerHigh, AppColors.cardSurface);
          expect(scheme.surfaceContainer, AppColors.cardSurface);
          return const SizedBox.shrink();
        }),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('menu rows distinguish names from secondary captions',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: appLightTheme,
        home: Builder(builder: (context) => Theme(
          data: settingsNeutralTheme(context),
          child: Scaffold(body: AppSettingsNavigationRow(
            title: 'Notifications',
            subtitle: 'Quiet reminders and alerts',
            onTap: () {},
          )),
        )),
      ));
      final title = tester.widget<Text>(find.text('Notifications'));
      final subtitle = tester.widget<Text>(find.text('Quiet reminders and alerts'));
      expect(title.style?.fontWeight, FontWeight.w500);
      expect(subtitle.style?.fontWeight, FontWeight.w400);
      expect(subtitle.style?.color, const Color(0xFF5C5C5C));
      expect((title.style?.fontSize ?? 0) > (subtitle.style?.fontSize ?? 0), isTrue);
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.hoverColor, AppNeutralTones.gray200);
      expect(tile.splashColor, Colors.transparent);
      expect(tester.takeException(), isNull);
    });

    test('global typography uses bundled Onest in both themes', () {
      expect(appLightTheme.textTheme.bodyLarge?.fontFamily, 'Onest');
      expect(appDarkTheme.textTheme.bodyLarge?.fontFamily, 'Onest');
    });

    test('desktop brand, sidebar and Profile stay in one shell', () {
      final chrome = File('lib/app/shell/shared/shell_chrome.dart')
          .readAsStringSync();
      final sidebar = File('lib/app/shell/desktop/shell_side_navigation.dart')
          .readAsStringSync();
      final routes = File('lib/app/shell/shared/shell_more_menu.dart')
          .readAsStringSync();
      expect(chrome, contains("desktopShell ? 'LIFE OS'"));
      expect(chrome, contains("initialTab: 'profile'"));
      expect(chrome, contains('embeddedInShell: true'));
      expect(sidebar, contains('AppNeutralTones.gray100'));
      expect(sidebar, isNot(contains("'LIFE OS'")));
      expect(routes, contains('setShellPageIndex(9)'));
      expect(routes, contains('9 => 5,'));
    });

    test('menu groups provide one hover target per item and no card stroke', () {
      final layout = File('lib/core/widgets/app_settings_layout.dart')
          .readAsStringSync();
      expect(layout, contains('class AppSettingsNavigationGroup extends StatefulWidget'));
      expect(layout, contains('clipBehavior: Clip.antiAlias'));
      expect(layout, contains('borderRadius: BorderRadius.circular(20)'));
      expect(layout, contains("ValueKey('settings-row-\$index')"));
      expect(layout, contains('if (_hoveredIndex != index) {'));
      expect(layout, contains('setState(() => _hoveredIndex = index);'));
      expect(layout, isNot(contains('Color(0xFFB6B6B6)')));
    });

    testWidgets('settings rows have balanced outer margins and open middle rhythm',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: appLightTheme,
        home: Builder(builder: (context) => Theme(
          data: settingsNeutralTheme(context),
          child: Scaffold(body: AppSettingsNavigationGroup(children: [
            AppSettingsNavigationRow(
              title: 'First item',
              leading: const AppSettingsMenuIcon(icon: Icons.alarm),
              onTap: () {},
            ),
            AppSettingsNavigationRow(
              title: 'Second item',
              leading: const AppSettingsMenuIcon(icon: Icons.person),
              onTap: () {},
            ),
          ])),
        )),
      ));
      final group = find.byType(AppSettingsNavigationGroup);
      final material = find.descendant(
          of: group, matching: find.byType(Material)).first;
      expect(tester.widget<Material>(material).color, Colors.white);
      expect(tester.widget<Material>(material).shape, isNull);

      final cardRect = tester.getRect(material);
      final icons = find.descendant(
          of: group, matching: find.byType(AppSettingsMenuIcon));
      final first = tester.getRect(icons.first);
      final last = tester.getRect(icons.last);
      final left = first.left - cardRect.left;
      final top = first.top - cardRect.top;
      final bottom = cardRect.bottom - last.bottom;
      expect(left, closeTo(24, 2));
      expect(top, closeTo(left, 5));
      expect(bottom, closeTo(left, 5));
      expect(last.top - first.bottom, greaterThanOrEqualTo(left));
      // One row owns its entire interaction surface; the icon-to-icon gap
      // is deliberate and never collapses to the previous cramped default.
      expect(last.top - first.bottom, greaterThanOrEqualTo(30));
      expect((cardRect.bottom - last.bottom - left).abs(), lessThan(4));

      for (final tile in tester.widgetList<ListTile>(
          find.descendant(of: group, matching: find.byType(ListTile)))) {
        expect(tile.hoverColor, Colors.transparent);
        expect(tile.shape, const RoundedRectangleBorder());
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('hover targets exactly one row and naturally fades its dividers',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: appLightTheme,
        home: Builder(builder: (context) => Theme(
          data: settingsNeutralTheme(context),
          child: Scaffold(body: AppSettingsNavigationGroup(children: [
            AppSettingsNavigationRow(
              title: 'One', leading: const Icon(Icons.alarm), onTap: () {}),
            AppSettingsNavigationRow(
              title: 'Two', leading: const Icon(Icons.person), onTap: () {}),
            AppSettingsNavigationRow(
              title: 'Three', leading: const Icon(Icons.check), onTap: () {}),
          ])),
        )),
      ));

      Color fill(String key) =>
          tester.widget<ColoredBox>(
              find.byKey(ValueKey<String>(key))).color;
      final hover = Theme.of(tester.element(find.text('Two')))
          .colorScheme.onSurface.withValues(alpha: 0.055);
      const divider = AppColors.settingsDivider;
      expect(hover.a, lessThan(0.1));
      expect(fill('settings-row-0'), Colors.white);
      expect(fill('settings-row-1'), Colors.white);
      expect(fill('settings-divider-line-0'), divider);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Two')));
      await tester.pumpAndSettle();
      expect(fill('settings-row-0'), Colors.white);
      expect(fill('settings-row-1'), hover);
      expect(fill('settings-row-2'), Colors.white);
      expect(fill('settings-divider-line-0'), divider);
      expect(fill('settings-divider-line-1'), divider);

      await mouse.moveTo(tester.getCenter(find.text('Three')));
      await tester.pumpAndSettle();
      expect(fill('settings-row-1'), Colors.white);
      expect(fill('settings-row-2'), hover);
      expect(fill('settings-divider-line-0'), divider);
      expect(fill('settings-divider-line-1'), divider);

      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(fill('settings-row-2'), Colors.white);
      expect(fill('settings-divider-line-1'), divider);
      expect(tester.takeException(), isNull);
    });

    test('Menu hover is a static row paint, not layered animations', () {
      final layout = File('lib/core/widgets/app_settings_layout.dart')
          .readAsStringSync();
      final group = layout.split(
          'class _AppSettingsNavigationGroupState').last.split(
          '/// Compact neutral icon treatment').first;
      expect(group, isNot(contains('AnimatedContainer(')));
      expect(group, contains("ValueKey('settings-row-\$index')"));
      expect(group, contains("ValueKey('settings-divider-line-\$index')"));
    });

    test('Timeline scrolls full width while Planning retains readable page width', () {
      final host = File('lib/app/shell/shared/shell_tab_host.dart')
          .readAsStringSync();
      expect(host, contains('Widget _readableWorkPage(Widget page)'));
      expect(host, contains('maxWidth: settingsContentMaxWidth(context)'));
      expect('return _readableWorkPage(child);'.allMatches(host).length, 1);
      expect(host.split('Widget buildPlanningSwipeTab()').first,
          contains('return child;'));
      expect(shellReadableContentMaxWidth(1600), 960);
      expect(shellReadableContentMaxWidth(800), 840);
      expect(shellReadableContentMaxWidth(390), 390);
      final chrome = File('lib/app/shell/shared/shell_chrome.dart')
          .readAsStringSync();
      expect(chrome, isNot(contains('_readableWorkPage(calendarTabHost)')));
      expect(chrome, isNot(contains('_readableWorkPage(listsTabHost)')));
    });

    testWidgets('Timeline divider matches quick-entry while scroll viewport '
        'reaches the right edge', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entry = TextEditingController();
      final focus = FocusNode();
      addTearDown(entry.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: Column(
            children: [
              TimelineHeaderControls(
                showStatsView: false,
                visibleDate: DateTime(2026, 11, 6),
                visibleIsFuture: false,
                titleController: entry,
                titleFocus: focus,
                onShowStatsViewChanged: (_) {},
                onStart: () {},
                onPlan: () {},
                onNewTaskForPastDate: () {},
              ),
              Expanded(
                child: TimelineLazyRecordList(
                  recordMaps: const [],
                  dateKey: '2020-01-01',
                  selectedDate: DateTime(2020, 1, 1),
                  selectedDateString: '2020-01-01',
                  onStop: (_) async {},
                  onDelete: (_) async {},
                  onEdit: (_) {},
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      final viewport = tester.getRect(
        find.byKey(const ValueKey('timeline-full-width-scroll-viewport')));
      expect(viewport.left, 0);
      expect(viewport.right, 1600);
      final header = tester.getRect(
        find.byKey(const ValueKey('timeline-header-content-frame')));
      expect(header.width, shellReadableContentMaxWidth(1600));
      expect(header.center.dx, closeTo(viewport.center.dx, 0.5));
      final quickEntry = tester.getRect(find.byType(AppQuickEntryRow));
      final divider = tester.getRect(
        find.byKey(const ValueKey('timeline-content-divider')));
      expect(divider.left, closeTo(quickEntry.left, 0.5));
      expect(divider.right, closeTo(quickEntry.right, 0.5));
      expect(quickEntry.height, AppControlTokens.height);
      expect(tester.takeException(), isNull);
    });

    test('Timeline cards use centered content frames without narrowing list',
        () {
      final list = File('lib/features/timeline/timeline_day_page.dart')
          .readAsStringSync();
      expect(list, contains('timeline-record-content-frame-'));
      expect(list, contains('shellReadableContentMaxWidth(viewportWidth)'));
      expect(list, contains('horizontal: desktop ? 0 : 12'));
      final history =
          File('lib/features/timeline/timeline_continuous_history.dart')
              .readAsStringSync();
      expect(history, contains('shellReadableContentMaxWidth(viewportWidth)'));
    });

    testWidgets('Menu scroll viewport reaches the far-right page edge',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: appLightTheme,
        home: Scaffold(body: AppSettingsPageBody(
          children: [
            for (var i = 0; i < 25; i++)
              SizedBox(height: 64, child: Text('Row $i')),
          ],
        )),
      ));
      final list = find.descendant(
          of: find.byType(AppSettingsPageBody),
          matching: find.byType(ListView));
      expect(list, findsOneWidget);
      final scrollRect = tester.getRect(list);
      expect(scrollRect.left, closeTo(0, 1));
      expect(scrollRect.right, closeTo(1600, 1));
      final row = tester.getRect(find.text('Row 0'));
      expect(row.left, greaterThan(200));
      expect(row.right, lessThan(1400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings stay within a readable desktop content column',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSettingsPageBody(
              children: [Text('Settings column')],
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.text('Settings column'));
      expect(rect.left, greaterThan(160));
      expect(rect.right, lessThan(1440));
      expect(tester.takeException(), isNull);
    });
  });
}
