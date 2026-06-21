import 'dart:async';
import 'dart:io';

import 'package:counter/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final List<String> _perfLogs = [];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full app — Timeline date swipe perf capture', (tester) async {
    await runZoned(
      () async {
        _perfLogs.clear();
        app.main();
        // Boot + optional auth + initial data load.
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(PageView).evaluate().isNotEmpty) break;
        }

        final pageViews = find.byType(PageView);
        if (pageViews.evaluate().isEmpty) {
          File('integration_perf_capture.txt').writeAsStringSync(
            'NO_PAGEVIEW_FOUND after 60s\n${_perfLogs.join('\n')}',
          );
          return;
        }

        await tester.fling(pageViews.first, const Offset(-600, 0), 2200);
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.fling(pageViews.first, const Offset(600, 0), 2200);
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        File('integration_perf_capture.txt').writeAsStringSync(
          _perfLogs.join('\n'),
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (line.startsWith('PERF_') ||
              line.startsWith('DATE_SWIPE') ||
              line.startsWith('PB_')) {
            _perfLogs.add(line);
          }
          parent.print(zone, line);
        },
      ),
    );
  });
}
