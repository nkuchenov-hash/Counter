import 'package:counter/data/voice/desktop_voice_command_normalize.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _scwDelModTree() {
  return CategoryRule(
    id: 10,
    name: 'Work',
    backendRowId: 'workroot1234567',
    children: [
      CategoryRule(
        id: 100,
        name: 'Price Reporter',
        backendRowId: 'prroot123456789',
        children: [
          CategoryRule(
            id: 103,
            name: 'Southern Computer Warehouse',
            backendRowId: 'scwclient123456',
            keywords: {
              'en': ['southern computer warehouse', 'scw'],
            },
            children: [
              CategoryRule(
                id: 104,
                name: 'DEL MOD',
                backendRowId: 'scwdelmod123456',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

CategoryRule _scwLeafOnlyTree() {
  return CategoryRule(
    id: 10,
    name: 'Work',
    backendRowId: 'workroot1234567',
    children: [
      CategoryRule(
        id: 100,
        name: 'Price Reporter',
        backendRowId: 'prroot123456789',
        children: [
          CategoryRule(
            id: 103,
            name: 'SOUTHERN COMPUTER WAREHOUSE',
            backendRowId: 'scwclient123456',
            keywords: {
              'en': ['southern computer warehouse', 'scw'],
            },
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('SCW DEL MOD Submit — exact comma-segment grammar', () {
    final delModRules = [_scwDelModTree()];
    final leafRules = [_scwLeafOnlyTree()];

    const exactComma =
        'Southern Computer Warehouse, DEL MOD, Submit.';
    const noComma = 'Southern Computer Warehouse DEL MOD submit';
    const mixedCase = 'Southern Computer Warehouse Del Mod submit';

    test('comma variant parses to deepest DEL MOD + Submit title', () {
      final r = parseVoiceCommand(rules: delModRules, transcript: exactComma);
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.isSafeToStart, isTrue);
      expect(
        r.matchedCategoryDisplayPath,
        'Work > Price Reporter > Southern Computer Warehouse > DEL MOD',
      );
      expect(r.recordTitle, 'Submit');
      expect(normalizeDesktopVoiceCommand(r), isNotNull);
    });

    test('no-comma variant parses', () {
      final r = parseVoiceCommand(rules: delModRules, transcript: noComma);
      expect(r.isSafeToStart, isTrue);
      expect(r.recordTitle.toLowerCase(), contains('submit'));
    });

    test('mixed-case variant parses', () {
      final r = parseVoiceCommand(rules: delModRules, transcript: mixedCase);
      expect(r.isSafeToStart, isTrue);
    });

    test('leaf-only SCW without parent prefix — deepest safe path', () {
      final r = parseVoiceCommand(rules: leafRules, transcript: exactComma);
      expect(r.isSafeToStart, isTrue);
      expect(
        r.matchedCategoryDisplayPath?.toLowerCase(),
        contains('southern computer warehouse'),
      );
      expect(r.recordTitle, 'DEL MOD Submit');
      expect(normalizeDesktopVoiceCommand(r), isNotNull);
    });

    test('pending lines show full command without one-line ellipsis path', () {
      final r = parseVoiceCommand(rules: delModRules, transcript: exactComma);
      final lines = voiceCommandPendingConfirmationLines(r, localeCode: 'ru');
      expect(lines.first, 'Запустить');
      expect(lines.any((l) => l.contains('Southern Computer Warehouse')), isTrue);
      expect(lines.any((l) => l.contains('DEL MOD') || l.contains('Submit')),
          isTrue);
      expect(lines.join('\n'), isNot(contains('Price Repo...')));
    });

    test('splitVoiceCommandSegments handles commas', () {
      final segs = splitVoiceCommandSegments(exactComma);
      expect(segs.length, 3);
      expect(segs[0], 'Southern Computer Warehouse');
      expect(segs[1], 'DEL MOD');
      expect(segs[2], 'Submit');
    });
  });
}
