import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart' show debugPrint;
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
/// **Web:** `ru-RU` and other primaries use stable hyphen tags from [webListenLocaleIdBcp47].
/// **English on Web (voice sheet only):** [webVoiceListenLocaleId] returns **hardcoded**
/// `en-US` so [listen] maps directly to Web Speech `lang` without consulting an engine
/// locale list (often empty `(0)` until after the first session).
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

  /// Bilingual STT partner: **always** UI English (`en`). Primary ⟷ English only.
  /// Call sites pass the resolved primary code for a stable API; the UI hides the toggle when primary is `en`.
  static String speechSttAlternateUiCode(String _) => 'en';

  /// Hard **en-US** tag for Web English sessions: never consult [SpeechToText.locales]; Chrome
  /// may omit `en` in the synthetic list while still accepting this `lang` on [listen].
  static const String webEnglishForcedLocaleId = 'en-US';

  /// Web Speech API `lang` (BCP-47, hyphens). **Does not** call [SpeechToText.locales] —
  /// use on **web** when the plugin reports an empty locale list so [listen] still gets a valid tag.
  static String webListenLocaleIdBcp47(String speechUiCode) {
    final p = _primaryLanguageCode(speechUiCode);
    switch (p) {
      case 'en':
        return webEnglishForcedLocaleId;
      case 'ru':
        return 'ru-RU';
      case 'de':
        return 'de-DE';
      case 'es':
        return 'es-ES';
      case 'fr':
        return 'fr-FR';
      case 'it':
        return 'it-IT';
      case 'ar':
        return 'ar-SA';
      case 'ko':
        return 'ko-KR';
      case 'zh':
        return 'zh-CN';
      default:
        return p;
    }
  }

  /// Web **VoiceInputSheet** only: English uses fixed **`en-US`** (Web Speech API);
  /// other languages use [webListenLocaleIdBcp47] — **no** dependency on [locales].
  static String webVoiceListenLocaleId(String speechUiCode) {
    if (kIsWeb && _primaryLanguageCode(speechUiCode) == 'en') {
      return webEnglishForcedLocaleId;
    }
    return webListenLocaleIdBcp47(speechUiCode);
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

  /// First-attempt locale for [listen].
  ///
  /// [speechUiCode] is the **speech session** language (may differ from app UI via toggle).
  ///
  /// On **web**, returns [webListenLocaleIdBcp47] **without** calling [SpeechToText.locales]
  /// first — Chrome often reports `(0)` until after the first interaction; resolution must
  /// not depend on a non-empty list. [listen] still receives a valid BCP-47 [localeId].
  ///
  /// On **mobile/desktop**, uses engine [locales] / [systemLocale] ids (often underscores).
  static Future<String?> resolveListenLocaleId({
    required stt.SpeechToText speech,
    required String speechUiCode,
  }) async {
    if (kIsWeb) {
      return webListenLocaleIdBcp47(speechUiCode);
    }

    final available = await speech.locales();
    final systemLc = await speech.systemLocale();
    final platformLocale = PlatformDispatcher.instance.locale;
    final platformTag = platformLocale.toLanguageTag();
    final appPrimary = _primaryLanguageCode(speechUiCode);

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

  /// After [SpeechToText.initialize] on web: optional warm-up; never required for [listen].
  static Future<void> warmUpWebLocalesForDebug(stt.SpeechToText speech) async {
    if (!kIsWeb) return;
    try {
      final list = await speech.locales();
      if (kDebugMode) {
        debugPrint('[STT] web locales (${list.length}) (warm-up; listen optional)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[STT] web locales() warm-up failed (ignored): $e');
      }
    }
  }
}
