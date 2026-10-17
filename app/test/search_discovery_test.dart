import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';

void main() {
  testWidgets('Search puts compact recent searches above music suggestions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = await Library.load();
    for (final query in ['oldest', 'ambient', 'jazz', 'darkwave', 'lofi']) {
      await library.searched(query);
    }
    await library.completeOnboarding();
    await tester.pumpWidget(UndertuneApp(library: library));
    await tester.pump();
    await tester.tap(find.text('Search'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('oldest'), findsNothing);
    expect(find.text('Music suggestions'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Recent searches')).dy,
      lessThan(tester.getTopLeft(find.text('Music suggestions')).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
