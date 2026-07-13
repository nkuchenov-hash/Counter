import 'package:counter/data/models.dart';

/// Shared category trees for Desktop Voice regression tests.
CategoryRule desktopVoiceLogicalMarketingTree() {
  return CategoryRule(
    id: 10,
    name: 'Work',
    backendRowId: 'workroot1234567',
    children: [
      CategoryRule(
        id: 20,
        name: 'Marketing',
        backendRowId: 'marketingroot123',
        children: [
          CategoryRule(
            id: 21,
            name: 'Logical Marketing',
            backendRowId: 'logicalmkt12345',
            keywords: {
              'en': ['logical marketing'],
            },
          ),
          CategoryRule(
            id: 22,
            name: 'Technical Marketing',
            backendRowId: 'techmkt1234567',
            keywords: {
              'en': ['technical marketing'],
            },
          ),
        ],
      ),
    ],
  );
}

List<CategoryRule> desktopVoiceLogicalMarketingRules() =>
    [desktopVoiceLogicalMarketingTree()];
