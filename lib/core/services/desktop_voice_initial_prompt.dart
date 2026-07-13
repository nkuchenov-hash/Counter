/// Neutral whisper initial_prompt injected at helper build time (no domain names).
abstract final class DesktopVoiceInitialPrompt {
  static const effectivePrompt =
      'Category name, task title. English command.';

  static const markerDomainListRemoved =
      'DESKTOP_VOICE_INITIAL_PROMPT_DOMAIN_LIST_REMOVED';
  static const markerUnspokenNotInjected =
      'DESKTOP_VOICE_UNSPOKEN_CLIENT_NOT_INJECTED';

  static const Set<String> forbiddenDomainTerms = {
    'price reporter',
    'southern computer warehouse',
    'scw',
    'del mod',
    'blink',
    'laredo',
    'technical marketing',
    'logical marketing',
    'submit',
  };

  static bool containsForbiddenDomainList(String prompt) {
    final lower = prompt.toLowerCase();
    var hits = 0;
    for (final term in forbiddenDomainTerms) {
      if (lower.contains(term)) hits++;
    }
    return hits >= 3;
  }
}
