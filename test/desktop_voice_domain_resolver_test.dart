import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _flatPriceReporterTree() {
  return CategoryRule(
    id: 100,
    name: 'Price Reporter',
    backendRowId: 'prroot123456789',
    children: [
      CategoryRule(
        id: 101,
        name: 'AGE SOLUTIONS',
        backendRowId: 'ageclient123456',
        keywords: {
          'en': ['age solutions'],
        },
      ),
    ],
  );
}

CategoryRule _workPriceReporterPlanningTree() {
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
            id: 102,
            name: 'Planning',
            backendRowId: 'planningcat1234',
          ),
          CategoryRule(
            id: 101,
            name: 'AGE SOLUTIONS',
            backendRowId: 'ageclient123456',
            keywords: {
              'en': ['age solutions'],
            },
          ),
        ],
      ),
    ],
  );
}

CategoryRule _blinkTree() {
  return CategoryRule(
    id: 300,
    name: 'BLINK',
    backendRowId: 'blinkroot123456',
    children: [
      CategoryRule(
        id: 301,
        name: 'Submit',
        backendRowId: 'blinksubmit1234',
      ),
      CategoryRule(
        id: 302,
        name: 'DEL MOD',
        backendRowId: 'blinkdelmod1234',
      ),
    ],
  );
}

CategoryRule _laredoTree() {
  return CategoryRule(
    id: 200,
    name: 'Laredo Technical Services',
    backendRowId: 'laredoroot12345',
    children: [
      CategoryRule(
        id: 201,
        name: 'Laredo TS',
        backendRowId: 'laredotsclient1',
        keywords: {
          'en': ['laredo ts'],
        },
      ),
    ],
  );
}

void main() {
  group('VoiceDomainResolver via parseVoiceCommand — deepest path', () {
    final workRules = [_workPriceReporterPlanningTree(), _laredoTree()];
    final flatRules = [_flatPriceReporterTree(), _laredoTree()];
    final blinkRules = [_blinkTree()];

    test('Price Reporter Planning selects Planning child under Work scope', () {
      final r = parseVoiceCommand(
        rules: workRules,
        transcript: 'Price Reporter Planning',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'Work > Price Reporter > Planning');
      expect(r.matchedLocalCategoryId, 102);
      expect(r.matchedCategoryPocketBaseId, 'planningcat1234');
      expect(r.recordTitle, 'Planning');
      expect(r.recordTitle, isNot('Price Reporter'));
    });

    test('Price reporter Planning. selects child not parent', () {
      final r = parseVoiceCommand(
        rules: workRules,
        transcript: 'Price reporter Planning.',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'Work > Price Reporter > Planning');
      expect(r.matchedLocalCategoryId, 102);
    });

    test('Rice reporter planning. → deepest Planning child', () {
      final r = parseVoiceCommand(
        rules: workRules,
        transcript: 'Rice reporter planning.',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'Work > Price Reporter > Planning');
      expect(r.recordTitle, 'Planning');
    });

    test('Prize reporter planning → deepest Planning child', () {
      final r = parseVoiceCommand(
        rules: workRules,
        transcript: 'Prize reporter planning',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'Work > Price Reporter > Planning');
    });

    test('Porter Plenty. → deepest Planning child', () {
      final r = parseVoiceCommand(
        rules: workRules,
        transcript: 'Porter Plenty.',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'Work > Price Reporter > Planning');
      expect(r.recordTitle, 'Planning');
    });

    test('Importer plenty. → deepest Planning child', () {
      final r = parseVoiceCommand(
        rules: workRules,
        transcript: 'Importer plenty.',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'Work > Price Reporter > Planning');
    });

    test('flat tree without Planning child uses root + Planning title', () {
      final r = parseVoiceCommand(
        rules: flatRules,
        transcript: 'Price Reporter Planning',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'Price Reporter');
      expect(r.recordTitle, 'Planning');
    });

    test('Laredo TS scene → Laredo TS + SIN', () {
      final r = parseVoiceCommand(
        rules: workRules,
        transcript: 'Laredo TS scene',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.recordTitle, 'SIN');
      expect(r.matchedCategoryDisplayPath, contains('Laredo TS'));
    });

    test('Laredo Technical Services add scene → ADD SIN', () {
      final r = parseVoiceCommand(
        rules: workRules,
        transcript: 'Laredo Technical Services add scene',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.recordTitle, 'ADD SIN');
    });

    test('Blink → BLINK category', () {
      final r = parseVoiceCommand(rules: blinkRules, transcript: 'Blink');
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'BLINK');
      expect(r.matchedLocalCategoryId, 300);
      expect(
        VoiceDomainResolver.lastResolution?.blinkInCandidates,
        isTrue,
      );
    });

    test('Bling → BLINK when unambiguous', () {
      final r = parseVoiceCommand(rules: blinkRules, transcript: 'Bling');
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'BLINK');
    });

    test('Blink Submit → BLINK > Submit', () {
      final r = parseVoiceCommand(
        rules: blinkRules,
        transcript: 'Blink Submit',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'BLINK > Submit');
      expect(r.matchedLocalCategoryId, 301);
    });

    test('Blink submit del mod → deepest BLINK path', () {
      final r = parseVoiceCommand(
        rules: blinkRules,
        transcript: 'Blink submit del mod',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'BLINK > DEL MOD');
    });

    test('random unrelated transcript does not start record', () {
      final r = parseVoiceCommand(
        rules: workRules,
        transcript: 'buy milk tomorrow afternoon',
      );
      expect(r.isSafeToStart, isFalse);
      expect(
        VoiceDomainResolver.lastResolution?.status,
        isNot(VoiceDomainResolverStatus.accepted),
      );
    });

    test('domain resolver logs top candidates', () {
      parseVoiceCommand(
        rules: workRules,
        transcript: 'Rice reporter planning.',
      );
      final resolution = VoiceDomainResolver.lastResolution;
      expect(resolution, isNotNull);
      expect(resolution!.topCandidates, isNotEmpty);
      expect(resolution.topScore, isNotNull);
    });

    test('parent rejected when child Planning exists', () {
      parseVoiceCommand(
        rules: workRules,
        transcript: 'Price Reporter Planning',
      );
      final resolution = VoiceDomainResolver.lastResolution;
      expect(
        resolution?.accepted?.displayPath,
        'Work > Price Reporter > Planning',
      );
      expect(
        resolution?.rejectedParentCandidate,
        'Work > Price Reporter',
      );
    });
  });

  group('SCW truncated client — safe reject diagnostics', () {
    final scwRules = [
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
              'en': ['southern computer warehouse'],
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
    ];

    test('df696fc truncated transcript rejects without parent-only record', () {
      const truncated = 'Computer Warehouse, DEL MOD, Submit.';
      final r = parseVoiceCommand(rules: scwRules, transcript: truncated);
      expect(r.isSafeToStart, isFalse);
      final reject = analyzeVoiceCommandReject(transcript: truncated, result: r);
      expect(reject, isNotNull);
      expect(reject!.missingRequiredTokens, contains('Southern'));
      expect(reject.ambiguousLeafMatches, contains('Computer Warehouse'));
      expect(
        reject.rejectedReason,
        contains('truncated_client_computer_warehouse_without_southern'),
      );
      expect(reject.parserRejectReason, contains('missing_required_client_token'));
    });
  });
}
