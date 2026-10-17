import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';

void main() {
  testWidgets(
    'Settings fits landscape and enlarged text without clipping controls',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      await library.completeOnboarding();
      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(UndertuneApp(library: library));
      await tester.pump();
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.text('Settings').hitTestable(),
        100,
        scrollable: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('SponsorBlock for videos'), findsOneWidget);
      await tester.ensureVisible(find.text('Theme'));
      expect(find.text('Theme').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
