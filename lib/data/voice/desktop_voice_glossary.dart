import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice/voice_command_parser.dart';

/// Live + static vocabulary for STT context and postprocess validation.
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

  /// Builds from in-memory Brain category rules — no network on hot path.
  static DesktopVoiceGlossaryPack buildFromCategoryRules(
    List<CategoryRule> rules, {
    List<String> extraTaskTitles = const [],
  }) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_LIVE_GLOSSARY_BUILT');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_GSA_TERMS_INCLUDED');

    final termSet = <String>{...kGsaVoiceGlossaryTerms};
    final paths = <String>[];
    final clients = <String>[];
    final tasks = <String>{...extraTaskTitles};

    void walk(CategoryRule node, List<String> parts) {
      if (node.isArchived) return;
      final name = node.name.trim();
      if (name.isNotEmpty) {
        termSet.add(name);
        final path = [...parts, name].join(' > ');
        if (parts.isNotEmpty) {
          paths.add(path);
        }
        if (parts.length >= 2) {
          clients.add(name);
        }
      }
      final kids = node.children;
      if (kids == null) return;
      for (final c in kids) {
        walk(c, [...parts, name]);
      }
    }

    for (final root in rules) {
      walk(root, const []);
    }

    final index = VoiceCommandCategoryIndex.fromCategoryRules(rules);
    if (index != null) {
      for (final scope in index.roots) {
        termSet.add(scope.rootLabel);
        for (final c in scope.candidates) {
          termSet.add(c.displayName);
          paths.add(c.displayPath);
          for (final p in c.normalizedPhrases) {
            if (p.length >= 3) termSet.add(p);
          }
        }
      }
    }

    for (final t in kGsaTaskTokenGlossary) {
      tasks.add(t);
      termSet.add(t);
    }

    final sorted = termSet.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_GLOSSARY_TERMS_COUNT',
      '${sorted.length}',
    );
    if (sorted.isNotEmpty) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_GLOSSARY_TOP_TERMS',
        sorted.take(8).join(' · '),
      );
    }

    return DesktopVoiceGlossaryPack(
      terms: sorted,
      categoryPaths: paths,
      clientNames: clients.toSet().toList(),
      taskTitles: tasks.where((t) => t.trim().isNotEmpty).toList(),
    );
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
