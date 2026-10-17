import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';
import 'package:undertune/screens/library.dart';

void main() {
  testWidgets('small screen and large text retain usable navigation and menu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = await Library.load();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await library.completeOnboarding();
    await tester.pumpWidget(UndertuneApp(library: library));
    await tester.pump();
    await tester.tap(find.text('Your Library'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scrollUntilVisible(
      find.text('Search playlists'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(LibraryScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Search playlists'), findsOneWidget);
    await tester.tap(find.text('Tracks').last);
    await tester.pump();
    expect(find.text('Search Tracks'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.text('About Undertune'),
      200,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('About Undertune'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('About Undertune'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Kafeyn'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
