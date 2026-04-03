import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Shared [SpeechToText.listen] locale resolution for Voice + Smart Plan.
///
/// On **Flutter Web**, [SpeechToText.locales] is driven by a tiny, often-stale
/// list from the browser API; passing those ids (e.g. `ru_RU`) frequently
/// triggers immediate `language-not-supported` even when the user’s UI is
/// Russian. Returning [null] leaves the Web Speech `lang` attribute unset so
/// the browser picks its default engine language.
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

  /// **Web:** always [null]. **Mobile/desktop:** [locales], [systemLocale], and
  /// [PlatformDispatcher.instance.locale] when the device list is empty.
  static Future<String?> resolveListenLocaleId({
    required stt.SpeechToText speech,
    required String appLoc,
  }) async {
    if (kIsWeb) {
      return null;
    }

    final available = await speech.locales();
    final systemLc = await speech.systemLocale();
    final platformLocale = PlatformDispatcher.instance.locale;
    final platformTag = platformLocale.toLanguageTag();
    final appPrimary = _primaryLanguageCode(appLoc);

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
