/// User-visible, privacy-safe diagnostic of dictation failures.
///
/// Never expose exception contents (which can include URLs or credentials)
/// verbatim. Callers identify the stage so a microphone problem is not
/// mislabeled as a SpeechKit provider failure.
String viktorVoiceErrorText(Object error, {String stage = 'recognition'}) {
  final value = error.toString().toLowerCase();
  if (value.contains('permission') || value.contains('not-allowed') ||
      value.contains('notallowed')) {
    return 'Браузер запретил доступ к микрофону. Разрешите запись '
        'звука для LIFE OS и проверьте выбранное устройство.';
  }
  if (value.contains('recording_too_short') ||
      value.contains('no_speech_detected')) {
    return 'Речь не обнаружена. Запишите голосовую команду ещё раз.';
  }
  if (value.contains('voice_capture_failed') ||
      value.contains('audio_recorder') ||
      value.contains('unsupported') ||
      value.contains('notimplemented') ||
      value.contains('not implemented')) {
    return 'Ошибка захвата звука браузером. Проверьте микрофон и '
        'разрешение сайта; попробуйте повторить запись.';
  }
  if (value.contains('speech_api_key_required')) {
    return 'Для распознавания речи требуется API-ключ. Проверьте '
        'настройки голоса Виктора.';
  }
  if (value.contains('yandex_folder_id_required')) {
    return 'Укажите ID каталога Yandex Cloud в настройках Виктора.';
  }
  if (value.contains('speech_provider_rejected')) {
    if (value.contains('http 401') || value.contains('http 403')) {
      return 'Yandex SpeechKit отклонил авторизацию. Проверьте API-ключ '
          'и роль ai.speechkit-stt.user.';
    }
    if (value.contains('http 429')) {
      return 'SpeechKit: достигнут лимит запросов. Проверьте квоту.';
    }
    if (value.contains('http 400') || value.contains('http 415')) {
      return 'SpeechKit отклонил аудиоформат (HTTP 400/415). '
          'Это ошибка интеграции, а не голосовой команды.';
    }
    return 'Сервис распознавания отклонил аудио. Проверьте '
        'доступ и квоты SpeechKit.';
  }
  if (value.contains('invalid_audio_encoding') ||
      value.contains('invalid_audio_format')) {
    return 'Ошибка формата WAV при передаче в SpeechKit.';
  }
  if (value.contains('invalid_speech_response') ||
      value.contains('invalid_speech_operation')) {
    return 'SpeechKit вернул ответ, который LIFE OS не смог разобрать. '
        'Ошибка формата ответа сервиса.';
  }
  if (value.contains('speech_request_failed') ||
      value.contains('speech_missing_error_code')) {
    return 'Сервер распознавания вернул ошибку без кода. '
        'Это сбой интеграции SpeechKit, а не голосовой команды.';
  }
  if (value.contains('invalid_or_oversized_audio') ||
      value.contains('invalid_audio_duration')) {
    return 'Неподдерживаемая длительность аудио. Запишите команду '
        'длительностью 2–30 секунд.';
  }
  if (value.contains('auth_required')) {
    return 'Для голосового ввода войдите в LIFE OS.';
  }
  if (value.contains('timeout') || value.contains('unreachable') ||
      value.contains('network') || value.contains('clientexception') ||
      value.contains('socketexception')) {
    return 'Сервис распознавания не ответил. Проверьте сеть и '
        'доступность PocketBase.';
  }
  if (stage == 'capture') {
    return 'Ошибка при записи с микрофона. Проверьте устройство и '
        'разрешения браузера.';
  }
  return 'Непредвиденный сбой на этапе распознавания речи. '
      'Команда не была отправлена Виктору.';
}
