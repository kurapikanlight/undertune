import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/widgets/minimize_on_swipe.dart';

void main() {
  testWidgets(
    'downward swipe minimizes once; short and horizontal drags do not',
    (tester) async {
      var minimized = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MinimizeOnSwipe(
              onMinimize: () => minimized++,
              child: const SizedBox(width: 300, height: 400),
            ),
          ),
        ),
      );
      await tester.timedDrag(
        find.byType(MinimizeOnSwipe),
        const Offset(0, 35),
        const Duration(seconds: 1),
      );
      expect(minimized, 0);
      await tester.timedDrag(
        find.byType(MinimizeOnSwipe),
        const Offset(100, 0),
        const Duration(seconds: 1),
      );
      expect(minimized, 0);
      await tester.timedDrag(
        find.byType(MinimizeOnSwipe),
        const Offset(0, 150),
        const Duration(seconds: 1),
      );
      expect(minimized, 1);
    },
  );
}
