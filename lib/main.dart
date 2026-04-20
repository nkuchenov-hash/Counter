import 'dart:async';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/app_shell.dart';
import 'package:counter/features/auth/auth_screen.dart';
import 'package:counter/auth_service.dart';
import 'package:counter/data/auth_bridge.dart';
import 'package:counter/database_service.dart';
import 'package:counter/services/notification_service.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/features/wear/wear_main_wrapper.dart';
import 'package:counter/features/wear/wear_platform.dart';
import 'package:counter/features/wear/wear_runtime.dart';
import 'package:counter/features/wear/wear_timer_screen.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/web_history.dart';
import 'package:counter/core/url_strategy_stub.dart'
    if (dart.library.html) 'package:flutter_web_plugins/url_strategy.dart'
    as url_strategy;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:timezone/data/latest.dart' as tz_data;

String? _startupNetworkErrorMessage;
bool _startupNetworkErrorShown = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    unawaited(NotificationService.instance.ensureInitialized());
    try {
      appWearHost = await WearPlatform.isWearHost();
    } catch (_) {
      appWearHost = false;
    }
  } else {
    appWearHost = false;
  }
  try {
    await DatabaseService.instance.ensurePocketBaseReady();
  } catch (_) {}
  try {
    if (appWearHost) {
      await initializeDateFormatting(
        materialLocaleForUiLanguage(currentLocale.value).toString(),
        null,
      );
    } else {
      for (final loc in kAppSupportedMaterialLocales) {
        await initializeDateFormatting(loc.toString(), null);
      }
    }
  } catch (_) {}
  try {
    tz_data.initializeTimeZones();
  } catch (_) {}
  String? bootProfileId;
  try {
    bootProfileId = await AuthBridge.checkSession();
    if (bootProfileId != null && bootProfileId.isNotEmpty) {
      DatabaseService.instance.currentProfileId = bootProfileId;
    }
  } catch (_) {}
  try {
    await AuthService.instance.initialize();
  } catch (_) {}
  url_strategy.usePathUrlStrategy();
  runApp(const DateTimeTrackerApp());
  if (kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final id = await AuthBridge.checkSession();
        if (id == null || id.isEmpty) {
          clearOAuthParams();
        }
      } catch (_) {}
    });
  }
}

class DateTimeTrackerApp extends StatefulWidget {
  const DateTimeTrackerApp({super.key});

  @override
  State<DateTimeTrackerApp> createState() => _DateTimeTrackerAppState();
}

class _DateTimeTrackerAppState extends State<DateTimeTrackerApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentLocale,
      builder: (context, locale, _) {
        return StreamBuilder<UserSettings>(
          stream: DatabaseService.instance.userSettingsStream,
          initialData: DatabaseService.instance.settings,
          builder: (context, settingsSnap) {
            final s = settingsSnap.data ?? DatabaseService.instance.settings;
            return MaterialApp(
              scaffoldMessengerKey: appSnackMessengerKey,
              title: t(locale, 'app_title'),
              locale: materialLocaleForUiLanguage(locale),
              debugShowCheckedModeBanner: false,
              theme: appLightTheme,
              darkTheme: appDarkTheme,
              themeMode: parseAppThemeMode(s.themeMode),
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                ...FlutterQuillLocalizations.localizationsDelegates,
              ],
              supportedLocales: kAppSupportedMaterialLocales,
              localeResolutionCallback: (deviceLocale, supported) {
                if (supported.isEmpty) {
                  return const Locale('en', 'US');
                }
                if (deviceLocale == null) return supported.first;
                for (final l in supported) {
                  if (l.languageCode == deviceLocale.languageCode) {
                    return l;
                  }
                }
                return supported.first;
              },
              builder: (context, child) {
                Intl.defaultLocale = materialLocaleForUiLanguage(locale).toString();
                if (!_startupNetworkErrorShown &&
                    _startupNetworkErrorMessage != null) {
                  _startupNetworkErrorShown = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final msg = _startupNetworkErrorMessage;
                    if (msg == null) return;
                    ScaffoldMessenger.of(context).showMaterialBanner(
                      MaterialBanner(
                        content: Text(msg),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                ScaffoldMessenger.of(context)
                                    .hideCurrentMaterialBanner(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  });
                }
                var out = child ?? const SizedBox.shrink();
                if (appWearHost) {
                  out = WearMainWrapper(child: out);
                }
                return out;
              },
              onGenerateRoute: (settings) {
                final name = settings.name ?? '/';
                if (name == '/' ||
                    name == '/Counter' ||
                    name.startsWith('/Counter/')) {
                  return MaterialPageRoute(
                      builder: (_) => const RootAuthWrapper(),
                      settings: settings);
                }
                return MaterialPageRoute(
                    builder: (_) => const RootAuthWrapper(), settings: settings);
              },
              home: const RootAuthWrapper(),
            );
          },
        );
      },
    );
  }
}

class RootAuthWrapper extends StatefulWidget {
  const RootAuthWrapper({super.key});

  @override
  State<RootAuthWrapper> createState() => _RootAuthWrapperState();
}

class _RootAuthWrapperState extends State<RootAuthWrapper> {
  String? _profileId;
  bool _checked = false;

  Future<void> _boot() async {
    final id = await AuthBridge.checkSession();
    if (mounted) {
      setState(() {
        _profileId = id;
        _checked = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.onSessionInvalid = () async {
      await AuthBridge.signOut();
    };
    DatabaseService.instance.onSignOut = clearSession;
    _boot();
  }

  void clearSession() {
    setState(() => _profileId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const _LoadingScreen();
    if (_profileId != null && _profileId!.isNotEmpty) {
      DatabaseService.instance.currentProfileId = _profileId;
      return _InitGuard(
        uid: _profileId!,
        onLoadFailed: clearSession,
      );
    }
    return AuthScreen(
      onSignedIn: () async {
        final id = await AuthBridge.checkSession();
        if (mounted && id != null && id.isNotEmpty) {
          setState(() => _profileId = id);
          DatabaseService.instance.currentProfileId = id;
        }
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _InitGuard extends StatefulWidget {
  const _InitGuard({required this.uid, this.onLoadFailed});

  final String uid;
  final VoidCallback? onLoadFailed;

  @override
  State<_InitGuard> createState() => _InitGuardState();
}

class _InitGuardState extends State<_InitGuard> {
  bool _ready = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final ok = appWearHost
          ? await DatabaseService.instance
              .loadInitialDataWearLite(widget.uid.trim())
          : await DatabaseService.instance.loadInitialData(widget.uid.trim());
      if (ok) {
        final lang = DatabaseService.instance.settings.primaryLanguage;
        if (lang.isNotEmpty) {
          currentLocale.value = resolvedUiLanguageCode(lang);
        }
      }
      if (mounted) {
        setState(() {
          _ready = true;
          _loadFailed = !ok;
        });
        if (!ok) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onLoadFailed?.call();
          });
        }
      }
    } catch (e, st) {
      // Boot-only: surfaces parser/init bugs (e.g. legacy PB nulls) that would otherwise hang silently.
      // ignore: avoid_print
      print('_InitGuard._initialize failed: $e\n$st');
      if (mounted) {
        setState(() {
          _ready = true;
          _loadFailed = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onLoadFailed?.call();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const _LoadingScreen();
    }
    if (_loadFailed) {
      final fullError = DatabaseService.instance.loadErrorMessage ??
          t(currentLocale.value, 'please_sign_in_again');
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(
                    fullError,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await AuthBridge.signOut();
                        DatabaseService.instance.clearLocalStateOnSignOut();
                      } catch (_) {}
                      await AuthService.instance.signOut();
                      final root =
                          context.findAncestorStateOfType<_RootAuthWrapperState>();
                      if (root != null && root.mounted) {
                        root.clearSession();
                      }
                    },
                    child: Text(t(currentLocale.value, 'sign_in_again')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (!DatabaseService.instance.isInitialized) {
      return const _LoadingScreen();
    }
    if (appWearHost) {
      return const WearTimerScreen();
    }
    final biometricEnabled =
        DatabaseService.instance.settings.biometricEnabled;
    if (biometricEnabled) {
      return const _BiometricGate(child: LifeOSDashboard());
    }
    return const LifeOSDashboard();
  }
}

class _BiometricGate extends StatefulWidget {
  const _BiometricGate({required this.child});

  final Widget child;

  @override
  State<_BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<_BiometricGate> {
  bool _unlocked = false;
  bool _checking = true;
  bool _biometricAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAndAuthenticate();
  }

  Future<void> _checkAndAuthenticate() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
        _checking = false;
        _biometricAvailable = false;
      });
      }
      return;
    }
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();
      if (!mounted) return;
      if (!canCheck || !isDeviceSupported) {
        setState(() {
          _checking = false;
          _biometricAvailable = false;
        });
        return;
      }
      setState(() {
        _biometricAvailable = true;
        _error = null;
      });
      final authenticated = await auth.authenticate(
        localizedReason: t(currentLocale.value, 'vault_locked_subtitle'),
        options: const AuthenticationOptions(
            biometricOnly: true, stickyAuth: true),
      );
      if (!mounted) return;
      if (authenticated) {
        setState(() => _unlocked = true);
      } else {
        setState(() => _error = t(currentLocale.value, 'invalid_code'));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _biometricAvailable = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    if (!_biometricAvailable && !_checking) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fingerprint_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    t(currentLocale.value, 'biometric_not_available'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      setState(() => _unlocked = true);
                    },
                    child: Text(t(currentLocale.value, 'unlock_with_biometric')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        widget.child,
        Material(
          color: Theme.of(context)
              .colorScheme
              .surface
              .withValues(alpha: 0.95),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      t(currentLocale.value, 'vault_locked'),
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(currentLocale.value, 'vault_locked_subtitle'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    if (_checking)
                      const CircularProgressIndicator()
                    else
                      FilledButton.icon(
                        onPressed: _checkAndAuthenticate,
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: Text(
                            t(currentLocale.value, 'unlock_with_biometric')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
