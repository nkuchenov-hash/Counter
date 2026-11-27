import 'package:counter/core/theme.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'editor_lab.dart';

/// Separate entry point. Never calls application bootstrap, auth or storage.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  currentLocale.value = 'ru';
  runApp(const EditorDesignLabApp());
}

class EditorDesignLabApp extends StatelessWidget {
  const EditorDesignLabApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LIFE OS / Design Lab',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: appLightTheme,
    darkTheme: appDarkTheme,
    home: const EditorDesignLab(),
  );
}
