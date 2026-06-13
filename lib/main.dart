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
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:counter/core/widgets/app_loading.dart';

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
                Intl.defaultLocale = materialLocaleForUiLanguage(
                  locale,
                ).toString();
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
                            onPressed: () => ScaffoldMessenger.of(
                              context,
                            ).hideCurrentMaterialBanner(),
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
                    settings: settings,
                  );
                }
                return MaterialPageRoute(
                  builder: (_) => const RootAuthWrapper(),
                  settings: settings,
                );
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
  String? _authMessageKey;
  bool _handlingSessionInvalid = false;

  Future<void> _postAuthBootstrap({String? failureMessageKey}) async {
    if (mounted) {
      setState(() {
        _checked = false;
        _authMessageKey = null;
      });
    }
    final id = await AuthBridge.checkSession();
    if (id == null || id.isEmpty) {
      if (!mounted) return;
      setState(() {
        _profileId = null;
        _checked = true;
        _authMessageKey = failureMessageKey;
      });
      return;
    }

    DatabaseService.instance.currentProfileId = id;
    final ok = appWearHost
        ? await DatabaseService.instance.loadInitialDataWearLite(id)
        : await DatabaseService.instance.loadInitialData(id);
    if (!mounted) return;
    if (ok && DatabaseService.instance.isInitialized) {
      final lang = DatabaseService.instance.settings.primaryLanguage;
      if (lang.isNotEmpty) {
        currentLocale.value = resolvedUiLanguageCode(lang);
      }
      DatabaseService.instance.offlineSync.resumeAfterAuthIfNeeded();
      setState(() {
        _profileId = id;
        _checked = true;
        _authMessageKey = null;
      });
      return;
    }

    setState(() {
      _profileId = null;
      _checked = true;
      _authMessageKey = failureMessageKey ?? 'auth_session_expired';
    });
  }

  Future<void> _handleSessionInvalid() async {
    if (_handlingSessionInvalid) return;
    _handlingSessionInvalid = true;
    try {
      DatabaseService.instance.offlineSync.setAuthPaused(
        true,
        message: 'session_invalid',
      );
    } catch (_) {}
    if (mounted) {
      setState(() {
        _profileId = null;
        _checked = true;
        _authMessageKey = 'auth_session_expired';
      });
    }
    try {
      await AuthBridge.signOut();
    } catch (_) {}
    try {
      DatabaseService.instance.clearLocalStateOnSignOut();
    } catch (_) {}
    _handlingSessionInvalid = false;
  }

  void _handleOfflineSyncChanged() {
    if (!mounted || _handlingSessionInvalid) return;
    if (_profileId == null || _profileId!.isEmpty) return;
    if (!DatabaseService.instance.offlineSync.authPaused) return;
    unawaited(_handleSessionInvalid());
  }

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.offlineSync.addListener(_handleOfflineSyncChanged);
    DatabaseService.instance.onSessionInvalid = () async {
      await _handleSessionInvalid();
    };
    DatabaseService.instance.onSignOut = clearSession;
    _postAuthBootstrap();
  }

  @override
  void dispose() {
    DatabaseService.instance.offlineSync.removeListener(
      _handleOfflineSyncChanged,
    );
    super.dispose();
  }

  void clearSession() {
    setState(() {
      _profileId = null;
      _checked = true;
      _authMessageKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const _LoadingScreen();
    if (_profileId != null && _profileId!.isNotEmpty) {
      DatabaseService.instance.currentProfileId = _profileId;
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
    return AuthScreen(
      initialMessageKey: _authMessageKey,
      onSignedIn: () async {
        await _postAuthBootstrap(failureMessageKey: 'auth_session_expired');
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: AppLoading());
  }
}

class _BiometricGate extends StatefulWidget {
  const _BiometricGate({required this.child});

  final Widget child;

  @override
  State<_BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<_BiometricGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _checking = true;
  bool _biometricAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _evaluateLockRequirement();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(AuthBridge.markAppBackgrounded());
      return;
    }
    if (state == AppLifecycleState.resumed && _unlocked) {
      unawaited(_evaluateLockRequirement());
    }
  }

  Future<void> _evaluateLockRequirement() async {
    if (kIsWeb) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }
    try {
      final available = await AuthBridge.canUseBiometricAuth();
      if (!mounted) return;
      if (!available) {
        setState(() {
          _unlocked = true;
          _checking = false;
          _biometricAvailable = false;
        });
        return;
      }
      final shouldLock = await AuthBridge.shouldRequireBiometricAppLock();
      if (!mounted) return;
      if (!shouldLock) {
        await AuthBridge.markAppUnlockSuccessful();
        if (!mounted) return;
        setState(() {
          _unlocked = true;
          _checking = false;
          _biometricAvailable = true;
          _error = null;
        });
        return;
      }
      setState(() {
        _unlocked = false;
        _checking = false;
        _biometricAvailable = true;
        _error = null;
      });
      unawaited(_authenticateAppLock());
    } catch (e) {
      if (mounted) {
        setState(() {
          _unlocked = true;
          _checking = false;
          _biometricAvailable = false;
        });
      }
    }
  }

  Future<void> _authenticateAppLock() async {
    if (!_biometricAvailable || _checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await AuthBridge.authenticateAppLock(
      localizedReason: t(currentLocale.value, 'vault_locked_subtitle'),
    );
    if (!mounted) return;
    setState(() {
      _checking = false;
      _unlocked = ok;
      _error = ok ? null : t(currentLocale.value, 'auth_biometric_failed');
    });
  }

  Future<void> _signInAgain() async {
    try {
      await AuthBridge.signOut();
      DatabaseService.instance.clearLocalStateOnSignOut();
    } catch (_) {}
    try {
      await AuthService.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    final root = context.findAncestorStateOfType<_RootAuthWrapperState>();
    if (root != null && root.mounted) {
      root.clearSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  t(currentLocale.value, 'vault_locked'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  t(currentLocale.value, 'vault_locked_subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                if (_checking)
                  const AppLoading()
                else ...[
                  FilledButton.icon(
                    onPressed: _authenticateAppLock,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      t(currentLocale.value, 'unlock_with_biometric'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _signInAgain,
                    child: Text(t(currentLocale.value, 'sign_in_again')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
