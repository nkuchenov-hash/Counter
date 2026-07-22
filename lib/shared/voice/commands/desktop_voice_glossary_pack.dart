import 'package:counter/data/models.dart';

/// Live + static vocabulary for STT context and postprocess validation.
///
/// Pack data lives in shared Voice so desktop STT adapters stay Brain-free.
/// Brain registers [buildFromCategoryRules] via [registerBuilder] at app start.
class DesktopVoiceGlossaryPack {
  DesktopVoiceGlossaryPack({
    required this.terms,
    required this.categoryPaths,
    required this.clientNames,
    required this.taskTitles,
  });

  final List<String> terms;
  final List<String> categoryPaths;
  final List<String> clientNames;
  final List<String> taskTitles;

  int get termsCount => terms.length;

  /// Compact prompt for cloud STT / Whisper initial context (≤ ~800 chars).
  String toSttPrompt({int maxTerms = 48}) {
    final buf = <String>[];
    for (final t in terms.take(maxTerms)) {
      final s = t.trim();
      if (s.isEmpty) continue;
      buf.add(s);
    }
    return buf.join(', ');
  }

  List<String> topTermsForDiagnostics({int n = 12}) =>
      terms.take(n).toList(growable: false);

  static DesktopVoiceGlossaryPack Function(
    List<CategoryRule> rules, {
    List<String> extraTaskTitles,
  })? _builder;

  /// Registers Brain-owned glossary construction (category index + GSA terms).
  static void registerBuilder(
    DesktopVoiceGlossaryPack Function(
      List<CategoryRule> rules, {
      List<String> extraTaskTitles,
    }) builder,
  ) {
    _builder = builder;
  }

  /// Builds from in-memory Brain category rules — no network on hot path.
  static DesktopVoiceGlossaryPack buildFromCategoryRules(
    List<CategoryRule> rules, {
    List<String> extraTaskTitles = const [],
  }) {
    final builder = _builder;
    if (builder == null) {
      throw StateError(
        'DesktopVoiceGlossaryPack builder not registered (wire in main.dart)',
      );
    }
    return builder(rules, extraTaskTitles: extraTaskTitles);
  }
}

/// Canonical GSA / Price Reporter vocabulary (always included).
const kGsaVoiceGlossaryTerms = [
  'Price Reporter',
  'Planning',
  'Southern Computer Warehouse',
  'SCW',
  'DEL MOD',
  'DELMOD',
  'ADD MOD',
  'ADD SIN',
  'SIN',
  'Submit',
  'BLINK',
  'Laredo Technical Services',
  'Laredo TS',
  'AGE SOLUTIONS',
];

const kGsaTaskTokenGlossary = [
  'DEL MOD',
  'ADD MOD',
  'ADD SIN',
  'Submit',
  'Planning',
  'SIN',
];
