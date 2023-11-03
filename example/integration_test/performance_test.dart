import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:example/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('performance test', () {
    testWidgets('trigger a particle system run, measure performance',
      (tester) async {
      final app = MaterialApp(home: MyApp());
      // Load app widget.
      await tester.pumpWidget(app);

      final blastStarsButton = find.byWidgetPredicate(
        (Widget widget) => widget is TextButton && (widget.child as Text).data == 'blast\nstars',
      );
      await tester.tap(blastStarsButton);

      await binding.traceAction(
        () async {
          // Trigger a frame.
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 20)
          );
        },
        reportKey: 'particles_timeline',
      );
    });
  });
}