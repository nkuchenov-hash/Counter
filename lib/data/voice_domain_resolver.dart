part of 'voice_command_parser.dart';

/// Outcome of fuzzy domain resolution against the live category index.
enum VoiceDomainResolverStatus {
  accepted,
  rejectedLowConfidence,
  rejectedAmbiguous,
  noCandidates,
  comparedWithLiteral,
}

/// One scored phrase built from an existing category path + optional title.
class VoiceDomainMatchCandidate {
  const VoiceDomainMatchCandidate({
    required this.displayPath,
    required this.normalizedPhrase,
    required this.localCategoryId,
    required this.pocketBaseId,
    required this.rootLabel,
    required this.recordTitle,
    required this.score,
    required this.adjustedScore,
    required this.isExact,
    required this.depth,
    this.matchReason,
  });

  final String displayPath;
  final String normalizedPhrase;
  final int localCategoryId;
  final String pocketBaseId;
  final String rootLabel;
  final String recordTitle;
  final double score;
  final double adjustedScore;
  final bool isExact;
  final int depth;
  final String? matchReason;

  String get diagnosticLine =>
      '$displayPath score=${score.toStringAsFixed(3)} adj=${adjustedScore.toStringAsFixed(3)} depth=$depth title=$recordTitle';
}

/// Diagnostics snapshot from the last [VoiceDomainResolver.resolve] call.
class VoiceDomainResolution {
  const VoiceDomainResolution({
    required this.rawTranscript,
    required this.normalizedTranscript,
    required this.repairedTranscript,
    required this.status,
    required this.topCandidates,
    this.accepted,
    this.parseResult,
    this.topScore,
    this.secondScore,
    this.margin,
    this.literalCandidatePath,
    this.literalCandidateScore,
    this.selectedCandidatePath,
    this.selectedCandidateReason,
    this.rejectedParentCandidate,
    this.blinkInCandidates = false,
    this.blinkCandidateScore,
    this.blinkRejectReason,
  });

  final String rawTranscript;
  final String normalizedTranscript;
  final String repairedTranscript;
  final VoiceDomainResolverStatus status;
  final List<VoiceDomainMatchCandidate> topCandidates;
  final VoiceDomainMatchCandidate? accepted;
  final VoiceCommandParseResult? parseResult;
  final double? topScore;
  final double? secondScore;
  final double? margin;
  final String? literalCandidatePath;
  final double? literalCandidateScore;
  final String? selectedCandidatePath;
  final String? selectedCandidateReason;
  final String? rejectedParentCandidate;
  final bool blinkInCandidates;
  final double? blinkCandidateScore;
  final String? blinkRejectReason;

  String get domainResolverStatusLabel {
    switch (status) {
      case VoiceDomainResolverStatus.accepted:
        return 'accepted';
      case VoiceDomainResolverStatus.rejectedLowConfidence:
        return 'rejected_low_confidence';
      case VoiceDomainResolverStatus.rejectedAmbiguous:
        return 'rejected_ambiguous';
      case VoiceDomainResolverStatus.noCandidates:
        return 'no_candidates';
      case VoiceDomainResolverStatus.comparedWithLiteral:
        return 'compared_with_literal';
    }
  }

  String get finalStateLabel {
    if (status == VoiceDomainResolverStatus.accepted) {
      return 'record_ready';
    }
    return 'not_matched';
  }
}

/// Comparison outcome between literal parser and domain resolver candidates.
class VoiceCommandParseComparison {
  static String? literalCandidatePath;
  static double? literalCandidateScore;
  static String? domainTopCandidatePath;
  static String? selectedCandidatePath;
  static String? selectedCandidateReason;
  static String? rejectedParentCandidate;

  static void clear() {
    literalCandidatePath = null;
    literalCandidateScore = null;
    domainTopCandidatePath = null;
    selectedCandidatePath = null;
    selectedCandidateReason = null;
    rejectedParentCandidate = null;
  }

  static void logToAttemptLog(void Function(String key, String value) mark) {
    mark('literal_candidate_path', literalCandidatePath ?? '—');
    mark('literal_candidate_score', literalCandidateScore?.toStringAsFixed(3) ?? '—');
    mark('domain_top_candidate', domainTopCandidatePath ?? '—');
    mark('selected_candidate_path', selectedCandidatePath ?? '—');
    mark('selected_candidate_reason', selectedCandidateReason ?? '—');
    mark('rejected_parent_candidate', rejectedParentCandidate ?? '—');
  }
}

class _CategoryPathEntry {
  const _CategoryPathEntry({
    required this.displayPath,
    required this.pathParts,
    required this.localCategoryId,
    required this.pocketBaseId,
    required this.categoryName,
    required this.depth,
  });

  final String displayPath;
  final List<String> pathParts;
  final int localCategoryId;
  final String pocketBaseId;
  final String categoryName;
  final int depth;
}

/// Fuzzy-match STT transcripts against existing category paths before rejection.
abstract final class VoiceDomainResolver {
  static const acceptScore = 0.86;
  static const acceptMargin = 0.08;
  static const suggestMinScore = 0.75;

  static VoiceDomainResolution? lastResolution;

  /// Token-level ASR confusions applied during scoring (tactical layer).
  static const Map<String, String> _asrTokenRepairs = {
    'rice': 'price',
    'prize': 'price',
    'press': 'price',
    'right': 'price',
    'porter': 'reporter',
    'importer': 'reporter',
    'plenty': 'planning',
    'plentie': 'planning',
    'play': 'planning',
    'plane': 'planning',
    'planing': 'planning',
    'plaming': 'planning',
    'scene': 'sin',
    'seen': 'sin',
    'sim': 'sin',
    'bling': 'blink',
  };

  static VoiceDomainResolution resolve({
    required String transcript,
    required String repairedTranscript,
    required VoiceCommandCategoryIndex index,
    required List<CategoryRule> rules,
    List<String> taskTitleHints = const [],
    VoiceCommandParseResult? literalCandidate,
  }) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_DOMAIN_RESOLVER_STARTED');
    final raw = transcript.trim();
    final repaired = repairedTranscript.trim();
    final normalized = normalizeCategoryLabel(repaired);
    final asrNormalized = _applyAsrTokenRepairs(normalized);

    if (taskTitleHints.isNotEmpty) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_TASK_HINTS_AVAILABLE',
        '${taskTitleHints.length}',
      );
    } else {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_TASK_HINTS_AVAILABLE', '0');
    }

    final built = _buildCandidates(
      index,
      rules,
      taskTitleHints: taskTitleHints,
    );
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_CATEGORY_CANDIDATE_BUILT',
      '${built.length}',
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_DEEPEST_CATEGORY_CANDIDATE');

    final scored = <VoiceDomainMatchCandidate>[];
    for (final c in built) {
      var score = _scoreTranscriptAgainstPhrase(asrNormalized, c.normalizedPhrase);
      if (score <= 0) continue;

      final normTitle = normalizeCategoryLabel(c.recordTitle);
      if (taskTitleHints.isNotEmpty) {
        final hintMatch = taskTitleHints.any(
          (h) => normalizeCategoryLabel(h) == normTitle,
        );
        if (hintMatch && score >= suggestMinScore) {
          score = min(1.0, score + 0.04);
          DesktopVoicePipeline.mark(
            'DESKTOP_VOICE_TASK_HINT_BOOST_APPLIED',
            c.recordTitle,
          );
        } else if (hintMatch) {
          DesktopVoicePipeline.mark(
            'DESKTOP_VOICE_TASK_HINT_IGNORED_LOW_CONFIDENCE',
            c.recordTitle,
          );
        }
      }

      scored.add(
        VoiceDomainMatchCandidate(
          displayPath: c.displayPath,
          normalizedPhrase: c.normalizedPhrase,
          localCategoryId: c.localCategoryId,
          pocketBaseId: c.pocketBaseId,
          rootLabel: c.rootLabel,
          recordTitle: c.recordTitle,
          score: score,
          adjustedScore: score,
          isExact: score >= 0.999,
          depth: c.depth,
        ),
      );
    }

    for (var i = 0; i < scored.length; i++) {
      final c = scored[i];
      final adjusted = _adjustedScore(c, scored, asrNormalized);
      scored[i] = VoiceDomainMatchCandidate(
        displayPath: c.displayPath,
        normalizedPhrase: c.normalizedPhrase,
        localCategoryId: c.localCategoryId,
        pocketBaseId: c.pocketBaseId,
        rootLabel: c.rootLabel,
        recordTitle: c.recordTitle,
        score: c.score,
        adjustedScore: adjusted,
        isExact: c.isExact,
        depth: c.depth,
        matchReason: c.matchReason,
      );
    }

    scored.sort((a, b) {
      final byAdj = b.adjustedScore.compareTo(a.adjustedScore);
      if (byAdj != 0) return byAdj;
      return b.depth.compareTo(a.depth);
    });

    final top = scored.take(5).toList(growable: false);
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_DOMAIN_RESOLVER_CANDIDATES',
      top.isEmpty ? 'none' : top.map((c) => c.diagnosticLine).join(' | '),
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_TOP_CANDIDATES_LOGGED');

    final blinkCandidates = scored
        .where((c) => c.displayPath.toUpperCase().contains('BLINK'))
        .toList(growable: false);
    final blinkInCandidates = blinkCandidates.isNotEmpty;
    double? blinkScore;
    String? blinkRejectReason;
    if (blinkInCandidates) {
      blinkScore = blinkCandidates.first.adjustedScore;
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_BLINK_TOP_CANDIDATES_LOGGED',
        blinkCandidates.take(3).map((c) => c.diagnosticLine).join(' | '),
      );
    }

    if (top.isEmpty) {
      final resolution = VoiceDomainResolution(
        rawTranscript: raw,
        normalizedTranscript: normalized,
        repairedTranscript: repaired,
        status: VoiceDomainResolverStatus.noCandidates,
        topCandidates: const [],
        literalCandidatePath: literalCandidate?.matchedCategoryDisplayPath,
        blinkInCandidates: blinkInCandidates,
        blinkCandidateScore: blinkScore,
      );
      lastResolution = resolution;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_DOMAIN_RESOLVER_REJECTED_LOW_CONFIDENCE');
      return resolution;
    }

    final topScore = top.first.adjustedScore;
    final secondScore = top.length > 1 ? top[1].adjustedScore : 0.0;
    final margin = topScore - secondScore;

    VoiceDomainResolverStatus status;
    VoiceDomainMatchCandidate? accepted;
    VoiceCommandParseResult? parseResult;
    String? rejectedParent;

    if (top.first.isExact ||
        (topScore >= acceptScore && margin >= acceptMargin)) {
      accepted = top.first;
      status = VoiceDomainResolverStatus.accepted;
      parseResult = _parseResultFromCandidate(accepted, raw);
      for (final c in top) {
        if (c.displayPath == accepted.displayPath) continue;
        if (accepted.displayPath.startsWith('${c.displayPath} > ')) {
          rejectedParent = c.displayPath;
          break;
        }
      }
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CATEGORY_MATCH_ACCEPTED', accepted.displayPath);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_DOMAIN_RESOLVER_MATCHED', accepted.displayPath);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CHILD_MATCH_ACCEPTED', accepted.displayPath);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_ACCEPTED_CATEGORY_PB_ID', accepted.pocketBaseId);
      if (accepted.displayPath.toUpperCase().contains('BLINK')) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_BLINK_MATCH_ACCEPTED', accepted.displayPath);
      }
      if (accepted.depth >= 3) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_DEEPEST_MATCH_SELECTED', accepted.displayPath);
      }
    } else if (topScore >= suggestMinScore && margin < acceptMargin) {
      status = VoiceDomainResolverStatus.rejectedAmbiguous;
      blinkRejectReason = 'ambiguous_margin';
      DesktopVoicePipeline.mark('DESKTOP_VOICE_CATEGORY_MATCH_REJECTED_AMBIGUOUS');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_AMBIGUOUS_NO_RECORD');
    } else {
      status = VoiceDomainResolverStatus.rejectedLowConfidence;
      blinkRejectReason = 'low_confidence';
      DesktopVoicePipeline.mark('DESKTOP_VOICE_DOMAIN_RESOLVER_REJECTED_LOW_CONFIDENCE');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_LOW_CONFIDENCE_NO_RECORD');
    }

    if (blinkInCandidates && accepted == null) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_BLINK_MATCH_REJECTED_REASON',
        blinkRejectReason ?? 'not_top_candidate',
      );
    }

    if (literalCandidate != null) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_DOMAIN_CANDIDATE', top.first.displayPath);
    }

    final resolution = VoiceDomainResolution(
      rawTranscript: raw,
      normalizedTranscript: normalized,
      repairedTranscript: repaired,
      status: status,
      topCandidates: top,
      accepted: accepted,
      parseResult: parseResult,
      topScore: topScore,
      secondScore: secondScore,
      margin: margin,
      literalCandidatePath: literalCandidate?.matchedCategoryDisplayPath,
      rejectedParentCandidate: rejectedParent,
      blinkInCandidates: blinkInCandidates,
      blinkCandidateScore: blinkScore,
      blinkRejectReason: blinkRejectReason,
    );
    lastResolution = resolution;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_DOMAIN_DIAGNOSTICS_READY');
    return resolution;
  }

  static void logDomainDiagnosticsToAttemptLog(void Function(String key, String value) mark) {
    final r = lastResolution;
    if (r == null) return;
    mark('raw_transcript', r.rawTranscript);
    mark('normalized_transcript', r.normalizedTranscript);
    mark('repaired_transcript', r.repairedTranscript);
    mark('domain_resolver_status', r.domainResolverStatusLabel);
    mark(
      'domain_top_candidates',
      r.topCandidates.isEmpty
          ? '—'
          : r.topCandidates.map((c) => c.diagnosticLine).join('; '),
    );
    mark('top_candidate_score', r.topScore?.toStringAsFixed(3) ?? '—');
    mark('second_candidate_score', r.secondScore?.toStringAsFixed(3) ?? '—');
    mark('confidence_margin', r.margin?.toStringAsFixed(3) ?? '—');
    mark('literal_candidate_path', r.literalCandidatePath ?? '—');
    mark('literal_candidate_score', r.literalCandidateScore?.toStringAsFixed(3) ?? '—');
    mark('selected_candidate_path', r.selectedCandidatePath ?? r.accepted?.displayPath ?? '—');
    mark('selected_candidate_reason', r.selectedCandidateReason ?? '—');
    mark('rejected_parent_candidate', r.rejectedParentCandidate ?? '—');
    mark('accepted_candidate_path', r.accepted?.displayPath ?? '—');
    mark('accepted_category_id', r.accepted?.localCategoryId.toString() ?? '—');
    mark('accepted_category_pb_id', r.accepted?.pocketBaseId ?? '—');
    mark('blink_in_candidates', r.blinkInCandidates ? 'yes' : 'no');
    mark('blink_candidate_score', r.blinkCandidateScore?.toStringAsFixed(3) ?? '—');
    mark('blink_reject_reason', r.blinkRejectReason ?? '—');
    mark('final_state', r.finalStateLabel);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_MATCH_REASON_LOGGED');
    if (r.rejectedParentCandidate != null) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_PARENT_REJECTION_LOGGED');
    }
    VoiceCommandParseComparison.logToAttemptLog(mark);
  }

  static String _applyAsrTokenRepairs(String normalized) {
    if (normalized.isEmpty) return normalized;
    final tokens = normalized.split(' ').where((t) => t.isNotEmpty);
    return tokens.map((t) => _asrTokenRepairs[t] ?? t).join(' ');
  }

  static double _scoreTranscriptAgainstPhrase(
    String normInput,
    String normCandidate,
  ) {
    if (normInput.isEmpty || normCandidate.isEmpty) return 0;
    if (normInput == normCandidate) return 1.0;

    final ratio = levenshteinSimilarityRatio(normInput, normCandidate);
    final seqLen = fuzzySequentialPhraseScore(normCandidate, normInput);
    final tokenScore = seqLen > 0
        ? (seqLen / max(normCandidate.length, normInput.length)).clamp(0.0, 1.0)
        : 0.0;

    var best = 0.55 * ratio + 0.45 * tokenScore;
    final inputTokens = normInput.split(' ').where((t) => t.isNotEmpty).length;
    final candidateTokens =
        normCandidate.split(' ').where((t) => t.isNotEmpty).length;
    final inputCoversCandidate = inputTokens >= candidateTokens;
    if (inputCoversCandidate &&
        (normInput.startsWith(normCandidate) ||
            normCandidate.startsWith(normInput))) {
      best = max(best, 0.88);
    }
    if (fuzzyNormalizedTokensMatch(normInput, normCandidate, minSimilarity: 0.86)) {
      best = max(best, 0.9);
    }
    final inputList = normInput.split(' ').where((t) => t.isNotEmpty).toList();
    final candidateList = normCandidate.split(' ').where((t) => t.isNotEmpty).toList();
    if (_tokensAppearInOrder(inputList, candidateList)) {
      best = max(best, 0.87 + min(0.1, candidateList.length * 0.02));
    }
    return best.clamp(0.0, 1.0);
  }

  static bool _tokensAppearInOrder(List<String> input, List<String> want) {
    if (want.isEmpty) return false;
    var matched = 0;
    for (final token in input) {
      if (matched < want.length && token == want[matched]) {
        matched++;
      }
    }
    return matched == want.length;
  }

  static bool _tokensStartWith(List<String> input, List<String> prefix) {
    if (prefix.length > input.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (input[i] != prefix[i]) return false;
    }
    return true;
  }

  static double _adjustedScore(
    VoiceDomainMatchCandidate candidate,
    List<VoiceDomainMatchCandidate> all,
    String asrNormalized,
  ) {
    var score = candidate.score;
    score += min(candidate.depth * 0.015, 0.06);

    final inputTokens =
        asrNormalized.split(' ').where((t) => t.isNotEmpty).toList();
    final phraseTokens = candidate.normalizedPhrase
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
    if (phraseTokens.isNotEmpty && inputTokens.length >= phraseTokens.length) {
      final coverage =
          phraseTokens.length / max(inputTokens.length, phraseTokens.length);
      score += 0.05 * coverage;
    }

    if (inputTokens.length > phraseTokens.length &&
        _tokensStartWith(inputTokens, phraseTokens)) {
      final leftover = inputTokens.length - phraseTokens.length;
      score -= 0.12 * leftover;
    }

    for (final other in all) {
      if (identical(other, candidate)) continue;
      if (!other.displayPath.startsWith('${candidate.displayPath} > ')) {
        continue;
      }
      if (other.score >= score - 0.05) {
        score -= 0.14;
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_PARENT_MATCH_PENALIZED',
          candidate.displayPath,
        );
        break;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  static List<_CategoryPathEntry> _collectCategoryPathEntries(
    List<CategoryRule> rules,
  ) {
    final out = <_CategoryPathEntry>[];

    void walk(CategoryRule rule, List<String> pathParts) {
      if (rule.isArchived) return;
      final name = rule.name.trim();
      if (name.isEmpty) return;
      final nextPath = [...pathParts, name];
      final pb = (rule.backendRowId ?? '').trim();
      if (pb.isNotEmpty && _isLikelyPocketBaseRowId(pb)) {
        out.add(
          _CategoryPathEntry(
            displayPath: nextPath.join(' > '),
            pathParts: nextPath,
            localCategoryId: rule.id,
            pocketBaseId: pb,
            categoryName: name,
            depth: nextPath.length,
          ),
        );
      }
      for (final child in rule.children ?? const <CategoryRule>[]) {
        walk(child, nextPath);
      }
    }

    for (final rule in rules) {
      walk(rule, const []);
    }
    return out;
  }

  static List<_BuiltCandidate> _buildCandidates(
    VoiceCommandCategoryIndex index,
    List<CategoryRule> rules, {
    required List<String> taskTitleHints,
  }) {
    final out = <_BuiltCandidate>[];
    final bestByKey = <String, _BuiltCandidate>{};

    void consider(_BuiltCandidate candidate) {
      final norm = candidate.normalizedPhrase;
      if (norm.isEmpty) return;
      if (!_isLikelyPocketBaseRowId(candidate.pocketBaseId)) return;
      if (candidate.recordTitle.trim().isEmpty) return;
      final key =
          '${candidate.displayPath}|${candidate.localCategoryId}|${candidate.recordTitle}|$norm';
      bestByKey[key] = candidate;
    }

    void add({
      required String phrase,
      required String displayPath,
      required int localCategoryId,
      required String pocketBaseId,
      required String rootLabel,
      required String recordTitle,
      required int depth,
    }) {
      consider(
        _BuiltCandidate(
          displayPath: displayPath,
          normalizedPhrase: normalizeCategoryLabel(phrase),
          localCategoryId: localCategoryId,
          pocketBaseId: pocketBaseId,
          rootLabel: rootLabel,
          recordTitle: recordTitle.trim(),
          depth: depth,
        ),
      );
      if (displayPath.toUpperCase().contains('BLINK')) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_BLINK_CANDIDATE_BUILT', displayPath);
      }
    }

    void addPathPhrases(_CategoryPathEntry entry) {
      final fullPhrase = entry.pathParts.map(normalizeCategoryLabel).join(' ');
      add(
        phrase: fullPhrase,
        displayPath: entry.displayPath,
        localCategoryId: entry.localCategoryId,
        pocketBaseId: entry.pocketBaseId,
        rootLabel: entry.pathParts.first,
        recordTitle: entry.categoryName,
        depth: entry.depth,
      );
      for (var skip = 1; skip < entry.pathParts.length; skip++) {
        final suffix = entry.pathParts
            .skip(skip)
            .map(normalizeCategoryLabel)
            .join(' ');
        if (suffix.isEmpty) continue;
        add(
          phrase: suffix,
          displayPath: entry.displayPath,
          localCategoryId: entry.localCategoryId,
          pocketBaseId: entry.pocketBaseId,
          rootLabel: entry.pathParts.first,
          recordTitle: entry.categoryName,
          depth: entry.depth,
        );
      }
    }

    for (final entry in _collectCategoryPathEntries(rules)) {
      addPathPhrases(entry);

      // Path + known task title suffixes (Submit, ADD MOD, …) for comma-segment STT.
      final pathNorm =
          entry.pathParts.map(normalizeCategoryLabel).join(' ');
      for (final taskNorm in kVoiceCommandTaskTitleNorms) {
        add(
          phrase: '$pathNorm $taskNorm',
          displayPath: entry.displayPath,
          localCategoryId: entry.localCategoryId,
          pocketBaseId: entry.pocketBaseId,
          rootLabel: entry.pathParts.first,
          recordTitle: repairPriceReporterRecordTitle(
            taskNorm == 'add mod'
                ? 'ADD MOD'
                : taskNorm == 'add sin'
                    ? 'ADD SIN'
                    : taskNorm[0].toUpperCase() + taskNorm.substring(1),
          ),
          depth: entry.depth,
        );
      }

      final isPlanningLeaf =
          normalizeCategoryLabel(entry.categoryName) == 'planning';
      final underPriceReporter = entry.pathParts.any(
        (p) => normalizeCategoryLabel(p) == kPriceReporterScopeCanonical,
      );
      if (underPriceReporter && isPlanningLeaf) {
        for (final alias in kPriceReporterTitleSttAliases.entries) {
          for (var skip = 0; skip < entry.pathParts.length; skip++) {
            final prefix = entry.pathParts
                .skip(skip)
                .map(normalizeCategoryLabel)
                .join(' ');
            if (prefix.isEmpty) continue;
            add(
              phrase: '$prefix ${alias.key}',
              displayPath: entry.displayPath,
              localCategoryId: entry.localCategoryId,
              pocketBaseId: entry.pocketBaseId,
              rootLabel: entry.pathParts.first,
              recordTitle: alias.value,
              depth: entry.depth,
            );
          }
        }
      }
    }

    for (final scope in index.roots) {
      if (scope.rootLabelNormalised == kPriceReporterScopeCanonical) {
        final rootPhrases = <String>{
          scope.rootLabelNormalised,
          ...kPriceReporterScopeNormPrefixes,
        };
        for (final rootPhrase in rootPhrases) {
          for (final alias in kPriceReporterTitleSttAliases.entries) {
            add(
              phrase: '$rootPhrase ${alias.key}',
              displayPath: scope.rootLabel,
              localCategoryId: scope.rootLocalCategoryId,
              pocketBaseId: scope.rootPocketBaseId,
              rootLabel: scope.rootLabel,
              recordTitle: alias.value,
              depth: 1,
            );
          }
        }
      }

      for (final client in scope.candidates) {
        final pathPhrase =
            client.displayPath.split(' > ').map(normalizeCategoryLabel).join(' ');
        add(
          phrase: pathPhrase,
          displayPath: client.displayPath,
          localCategoryId: client.localCategoryId,
          pocketBaseId: client.pocketBaseId,
          rootLabel: scope.rootLabel,
          recordTitle: client.displayName,
          depth: client.displayPath.split(' > ').length,
        );
        for (final p in client.normalizedPhrases) {
          add(
            phrase: p,
            displayPath: client.displayPath,
            localCategoryId: client.localCategoryId,
            pocketBaseId: client.pocketBaseId,
            rootLabel: scope.rootLabel,
            recordTitle: client.displayName,
            depth: client.displayPath.split(' > ').length,
          );
          final underPriceReporter = client.displayPath
              .toLowerCase()
              .contains('price reporter');
          if (underPriceReporter) {
            for (final alias in kPriceReporterTitleSttAliases.entries) {
              add(
                phrase: '$p ${alias.key}',
                displayPath: client.displayPath,
                localCategoryId: client.localCategoryId,
                pocketBaseId: client.pocketBaseId,
                rootLabel: scope.rootLabel,
                recordTitle: alias.value,
                depth: client.displayPath.split(' > ').length,
              );
            }
          }
        }
      }
    }

    for (final hint in taskTitleHints) {
      final normHint = normalizeCategoryLabel(hint);
      if (normHint.isEmpty) continue;
      for (final scope in index.roots) {
        add(
          phrase: '${scope.rootLabelNormalised} $normHint',
          displayPath: scope.rootLabel,
          localCategoryId: scope.rootLocalCategoryId,
          pocketBaseId: scope.rootPocketBaseId,
          rootLabel: scope.rootLabel,
          recordTitle: repairPriceReporterRecordTitle(hint),
          depth: 1,
        );
      }
    }

    out.addAll(bestByKey.values);
    return out;
  }

  static VoiceCommandParseResult _parseResultFromCandidate(
    VoiceDomainMatchCandidate c,
    String originalTranscript,
  ) {
    return VoiceCommandParseResult(
      rootLabel: c.rootLabel,
      matchedCategoryPocketBaseId: c.pocketBaseId,
      matchedCategoryDisplayPath: c.displayPath,
      matchedLocalCategoryId: c.localCategoryId,
      recordTitle: repairPriceReporterRecordTitle(c.recordTitle),
      confidence: VoiceCommandMatchConfidence.exact,
      originalTranscript: originalTranscript,
    );
  }

  static bool _isLikelyPocketBaseRowId(String id) {
    final t = id.trim();
    return t.length == 15 && RegExp(r'^[a-z0-9]+$').hasMatch(t);
  }
}

class _BuiltCandidate {
  const _BuiltCandidate({
    required this.displayPath,
    required this.normalizedPhrase,
    required this.localCategoryId,
    required this.pocketBaseId,
    required this.rootLabel,
    required this.recordTitle,
    required this.depth,
  });

  final String displayPath;
  final String normalizedPhrase;
  final int localCategoryId;
  final String pocketBaseId;
  final String rootLabel;
  final String recordTitle;
  final int depth;
}

int _pathDepth(String? displayPath) {
  if (displayPath == null || displayPath.trim().isEmpty) return 0;
  return displayPath.split('>').length;
}

double _literalCandidateScore(
  VoiceCommandParseResult literal,
  String repairedTranscript,
) {
  if (literal.confidence != VoiceCommandMatchConfidence.exact) return 0;
  final path = literal.matchedCategoryDisplayPath ?? literal.rootLabel;
  final phrase = normalizeCategoryLabel(
    '$path ${literal.recordTitle}'.replaceAll('>', ' '),
  );
  return VoiceDomainResolver._scoreTranscriptAgainstPhrase(
    VoiceDomainResolver._applyAsrTokenRepairs(
      normalizeCategoryLabel(repairedTranscript),
    ),
    phrase,
  );
}

bool _isAncestorPath(String? ancestor, String? descendant) {
  if (ancestor == null || descendant == null) return false;
  final a = ancestor.trim();
  final d = descendant.trim();
  if (a.isEmpty || d.isEmpty) return false;
  return d.startsWith('$a > ') && d.length > a.length;
}

VoiceCommandParseResult _selectBestParseCandidate({
  required VoiceCommandParseResult literal,
  required VoiceDomainResolution domain,
  required String raw,
  required String repaired,
}) {
  VoiceCommandParseComparison.clear();
  DesktopVoicePipeline.mark('DESKTOP_VOICE_LITERAL_CANDIDATE');
  DesktopVoicePipeline.mark('DESKTOP_VOICE_CANDIDATE_COMPARISON');

  final literalPath = literal.matchedCategoryDisplayPath;
  final literalScore = _literalCandidateScore(literal, repaired);
  VoiceCommandParseComparison.literalCandidatePath = literalPath;
  VoiceCommandParseComparison.literalCandidateScore = literalScore;

  final domainResult = domain.parseResult;
  final domainTopPath = domain.accepted?.displayPath ??
      (domain.topCandidates.isNotEmpty ? domain.topCandidates.first.displayPath : null);
  VoiceCommandParseComparison.domainTopCandidatePath = domainTopPath;

  if (raw.trim().isEmpty) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_GARBAGE_RECORD');
    return literal;
  }

  if (domain.status == VoiceDomainResolverStatus.accepted) {
    if (domainResult != null && domainResult.isSafeToStart) {
      final literalDepth = _pathDepth(literalPath);
      final domainDepth = _pathDepth(domainResult.matchedCategoryDisplayPath);

      final literalExact = literal.confidence == VoiceCommandMatchConfidence.exact &&
          literal.isSafeToStart;

      // Prefer deeper segmented/literal exact over shallow domain fuzzy match.
      if (literalExact && domainDepth < literalDepth) {
        VoiceCommandParseComparison.selectedCandidatePath = literalPath;
        VoiceCommandParseComparison.selectedCandidateReason = 'literal_deeper_than_domain';
        return literal;
      }

      if (literalExact &&
          domainDepth > literalDepth &&
          _isAncestorPath(literalPath, domainResult.matchedCategoryDisplayPath)) {
        VoiceCommandParseComparison.selectedCandidatePath =
            domainResult.matchedCategoryDisplayPath;
        VoiceCommandParseComparison.selectedCandidateReason =
            'deeper_path_with_leaf_token';
        VoiceCommandParseComparison.rejectedParentCandidate = literalPath;
        VoiceDomainResolver.lastResolution = VoiceDomainResolution(
          rawTranscript: domain.rawTranscript,
          normalizedTranscript: domain.normalizedTranscript,
          repairedTranscript: domain.repairedTranscript,
          status: domain.status,
          topCandidates: domain.topCandidates,
          accepted: domain.accepted,
          parseResult: domainResult,
          topScore: domain.topScore,
          secondScore: domain.secondScore,
          margin: domain.margin,
          literalCandidatePath: literalPath,
          literalCandidateScore: literalScore,
          selectedCandidatePath: domainResult.matchedCategoryDisplayPath,
          selectedCandidateReason: 'deeper_path_with_leaf_token',
          rejectedParentCandidate: literalPath,
          blinkInCandidates: domain.blinkInCandidates,
          blinkCandidateScore: domain.blinkCandidateScore,
          blinkRejectReason: domain.blinkRejectReason,
        );
        DesktopVoicePipeline.mark('DESKTOP_VOICE_SHALLOW_EXACT_OVERRIDDEN');
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_DEEPEST_MATCH_SELECTED',
          domainResult.matchedCategoryDisplayPath ?? '',
        );
        DesktopVoicePipeline.mark('DESKTOP_VOICE_PRICE_REPORTER_PLANNING_MATCHED_CHILD');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_PRICE_REPORTER_PARENT_NOT_SELECTED');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_PARENT_REJECTION_LOGGED');
        return domainResult;
      }

      if (!literalExact) {
        VoiceCommandParseComparison.selectedCandidatePath =
            domainResult.matchedCategoryDisplayPath;
        VoiceCommandParseComparison.selectedCandidateReason = 'domain_resolver_accepted';
        return domainResult;
      }

      if (literalExact && domainDepth == literalDepth) {
        VoiceCommandParseComparison.selectedCandidatePath = literalPath;
        VoiceCommandParseComparison.selectedCandidateReason = 'literal_exact_same_depth';
        return literal;
      }

      if (literalExact && domainDepth < literalDepth) {
        VoiceCommandParseComparison.selectedCandidatePath = literalPath;
        VoiceCommandParseComparison.selectedCandidateReason = 'literal_deeper';
        return literal;
      }
    }
  }

  if (literal.confidence == VoiceCommandMatchConfidence.exact && literal.isSafeToStart) {
    final titleNorm = normalizeCategoryLabel(literal.recordTitle);
    if (titleNorm.isNotEmpty) {
      final branchPrefix = literal.matchedCategoryDisplayPath ?? '';
      VoiceDomainMatchCandidate? titleChild;
      for (final c in domain.topCandidates) {
        if (normalizeCategoryLabel(c.recordTitle) != titleNorm) continue;
        if (c.adjustedScore < VoiceDomainResolver.suggestMinScore) continue;
        if (c.displayPath == branchPrefix) continue;
        if (branchPrefix.isNotEmpty &&
            c.displayPath.startsWith('$branchPrefix > ')) {
          titleChild = c;
          break;
        }
        if (literal.rootLabel.isNotEmpty &&
            c.displayPath.startsWith('${literal.rootLabel} > ') &&
            c.displayPath != branchPrefix) {
          titleChild = c;
          break;
        }
      }
      if (titleChild != null) {
        final childResult =
            VoiceDomainResolver._parseResultFromCandidate(titleChild, raw);
        VoiceCommandParseComparison.selectedCandidatePath =
            childResult.matchedCategoryDisplayPath;
        VoiceCommandParseComparison.selectedCandidateReason =
            'title_matches_deeper_category';
        VoiceCommandParseComparison.rejectedParentCandidate = branchPrefix;
        DesktopVoicePipeline.mark('DESKTOP_VOICE_CHILD_MATCH_ACCEPTED', childResult.matchedCategoryDisplayPath ?? '');
        return childResult;
      }
    }
    VoiceCommandParseComparison.selectedCandidatePath = literalPath;
    VoiceCommandParseComparison.selectedCandidateReason = 'literal_exact';
    return literal;
  }

  if (domainResult != null && domainResult.isSafeToStart) {
    VoiceCommandParseComparison.selectedCandidatePath =
        domainResult.matchedCategoryDisplayPath;
    VoiceCommandParseComparison.selectedCandidateReason = 'domain_resolver_fallback';
    return domainResult;
  }

  DesktopVoicePipeline.mark('DESKTOP_VOICE_CURRENT_RECORD_UNCHANGED_ON_FAILURE');
  if (literal.confidence == VoiceCommandMatchConfidence.ambiguous) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_AMBIGUOUS_NO_RECORD');
  } else if (literal.confidence == VoiceCommandMatchConfidence.noMatch) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_LOW_CONFIDENCE_NO_RECORD');
  }
  DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_GARBAGE_RECORD');
  return literal;
}
