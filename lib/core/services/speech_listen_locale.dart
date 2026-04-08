import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Shared [SpeechToText.listen] locale resolution for Voice + Smart Plan.
///
/// **Single language per session:** [SpeechToText.listen] accepts one [localeId].
/// The platform speech APIs used on Android ([SpeechRecognizer]) and iOS
/// ([SFSpeechRecognizer]) do **not** expose true simultaneous bilingual dictation
/// in one recognition pass. If the app UI is `ru` but the user mixes English words,
/// the engine may still run in Russian and garble Latin words (or the reverse).
///
/// **Dual-locale (not implemented):** options would be (a) two sequential
/// [listen] sessions with different [localeId]s and merged text, (b) an OS-level
/// “multilingual keyboard” that still reports one primary language to the engine,
/// or (c) a cloud STT that declares multiple expected languages. The
/// `speech_to_text` plugin does not surface Android 13+ optional extras beyond
/// [localeId] for standard use.
///
/// **Fallback:** On mobile, if the app UI language has **no** installed STT pack,
/// [resolveListenLocaleId] falls back to [SpeechToText.systemLocale] then the
/// process [PlatformDispatcher] locale (see implementation).
///
/// **Web:** the Web Speech `lang` attribute expects **BCP-47 with hyphens**
/// (e.g. `ru-RU`). Underscore ids from the plugin (e.g. `ru_RU`) often trigger
/// `language-not-supported`. The **first** [listen] uses an explicit hyphen tag
/// derived from the app UI locale and [Locale.toLanguageTag]; reactive retry
/// with `localeId: null` stays in the widgets.
abstract final class SpeechListenLocale {
  static bool messageIndicatesLanguageUnsupported(String raw) {
    final msg = raw.toLowerCase().trim();
    if (msg.contains('language-not-supported') ||
        msg.contains('language_not_supported') ||
        msg.contains('error_language_not_supported')) {
      return true;
    }
    return msg.contains('language') &&
        msg.contains('not') &&
        msg.contains('support');
  }

  static String _primaryLanguageCode(String appLoc) {
    final i = appLoc.indexOf(RegExp(r'[-_]'));
    return (i < 0 ? appLoc : appLoc.substring(0, i)).toLowerCase();
  }

  static String _normalizeLocaleToken(String id) =>
      id.replaceAll('-', '_').toLowerCase();

  static String _toBcp47Hyphens(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      return t;
    }
    return t.replaceAll('_', '-');
  }

  /// UI locale code → [Locale] with a typical region for STT (hyphen tag via
  /// [Locale.toLanguageTag]).
  static Locale _localeForAppUi(String appLoc) {
    final primary = _primaryLanguageCode(appLoc);
    switch (primary) {
      case 'ru':
        return const Locale('ru', 'RU');
      case 'en':
        return const Locale('en', 'US');
      case 'fr':
        return const Locale('fr', 'FR');
      case 'de':
        return const Locale('de', 'DE');
      case 'es':
        return const Locale('es', 'ES');
      case 'it':
        return const Locale('it', 'IT');
      case 'ar':
        return const Locale('ar');
      case 'ko':
        return const Locale('ko', 'KR');
      case 'zh':
        return const Locale('zh', 'CN');
      case 'ja':
        return const Locale('ja', 'JP');
      case 'pt':
        return const Locale('pt', 'BR');
      case 'hi':
        return const Locale('hi', 'IN');
      case 'pl':
        return const Locale('pl', 'PL');
      case 'tr':
        return const Locale('tr', 'TR');
      case 'uk':
        return const Locale('uk', 'UA');
      case 'nl':
        return const Locale('nl', 'NL');
      case 'vi':
        return const Locale('vi', 'VN');
      case 'th':
        return const Locale('th', 'TH');
      case 'id':
        return const Locale('id', 'ID');
      case 'he':
        return const Locale('he', 'IL');
      case 'el':
        return const Locale('el', 'GR');
      case 'cs':
        return const Locale('cs', 'CZ');
      case 'sv':
        return const Locale('sv', 'SE');
      case 'da':
        return const Locale('da', 'DK');
      case 'fi':
        return const Locale('fi', 'FI');
      case 'nb':
        return const Locale('nb', 'NO');
      case 'ro':
        return const Locale('ro', 'RO');
      case 'hu':
        return const Locale('hu', 'HU');
      case 'ms':
        return const Locale('ms', 'MY');
      default:
        return Locale(primary);
    }
  }

  static String? _findBestLocaleIdForLanguage(
    List<stt.LocaleName> available,
    String appPrimary,
  ) {
    final p = appPrimary.toLowerCase();
    String? regional;
    for (final l in available) {
      final n = _normalizeLocaleToken(l.localeId);
      if (n == p) {
        return l.localeId;
      }
      if (regional == null && n.startsWith('${p}_')) {
        regional = l.localeId;
      }
    }
    return regional;
  }

  static bool _languageAvailableInList(
    List<stt.LocaleName> available,
    String appPrimary,
  ) {
    return _findBestLocaleIdForLanguage(available, appPrimary) != null;
  }

  static String? _resolveWebExplicitTag({
    required List<stt.LocaleName> available,
    required String appLoc,
    required String appPrimary,
    required String platformTag,
  }) {
    final fromList = _findBestLocaleIdForLanguage(available, appPrimary);
    if (fromList != null) {
      return _toBcp47Hyphens(fromList);
    }
    final uiTag = _localeForAppUi(appLoc).toLanguageTag();
    if (uiTag.isNotEmpty) {
      return _toBcp47Hyphens(uiTag);
    }
    if (platformTag.isNotEmpty) {
      return _toBcp47Hyphens(platformTag);
    }
    return null;
  }

  /// First-attempt locale for [listen]. On **web**, always a **hyphenated**
  /// BCP-47 string when possible. On **mobile/desktop**, uses engine [locales]
  /// / [systemLocale] ids as provided by the platform (often underscores).
  static Future<String?> resolveListenLocaleId({
    required stt.SpeechToText speech,
    required String appLoc,
  }) async {
    final available = await speech.locales();
    final systemLc = await speech.systemLocale();
    final platformLocale = PlatformDispatcher.instance.locale;
    final platformTag = platformLocale.toLanguageTag();
    final appPrimary = _primaryLanguageCode(appLoc);

    if (kIsWeb) {
      return _resolveWebExplicitTag(
        available: available,
        appLoc: appLoc,
        appPrimary: appPrimary,
        platformTag: platformTag,
      );
    }

    if (available.isNotEmpty) {
      if (!_languageAvailableInList(available, appPrimary)) {
        return systemLc?.localeId ??
            (platformTag.isEmpty ? null : platformTag);
      }
      final picked = _findBestLocaleIdForLanguage(available, appPrimary);
      if (picked != null) {
        return picked;
      }
      return systemLc?.localeId ??
          (platformTag.isEmpty ? null : platformTag);
    }

    return systemLc?.localeId ??
        (platformTag.isEmpty ? null : platformTag);
  }
}
