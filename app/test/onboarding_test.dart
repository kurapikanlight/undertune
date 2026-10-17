import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';
import 'package:undertune/screens/onboarding.dart';
import 'package:undertune/theme.dart';

void main() {
  testWidgets('welcome uses Enter Sandman before the first theme selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = await Library.load();
    await tester.pumpWidget(UndertuneApp(library: library));
    await tester.pump();
    final background = tester.widget<AtmosphericBackground>(
      find.byType(AtmosphericBackground).first,
    );
    expect(background.theme.id, 'obsidian');
    expect(background.theme.canvas, Colors.black);
    expect(find.byKey(const ValueKey('welcome-command')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'an unfinished library with no saved theme uses Enter Sandman',
    () async {
      SharedPreferences.setMockInitialValues({
        'undertune.library.v1': '{"onboardingComplete":false}',
      });
      final library = await Library.load();
      expect(library.themeId, 'obsidian');
      expect(library.onboardingComplete, isFalse);
    },
  );
  testWidgets(
    'terminal welcome types in while Start stays available at the bottom right',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(library: library)),
      );
      await tester.pump();
      expect(find.text('Start').hitTestable(), findsOneWidget);
      final start = tester.getCenter(find.text('Start'));
      expect(start.dx, greaterThan(400));
      expect(start.dy, greaterThan(450));
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      final partial = tester.widget<Text>(
        find.byKey(const ValueKey('welcome-command')),
      );
      expect(partial.data, startsWith('Wel'));
      expect(partial.data, isNot(contains('>')));
      expect(partial.data, isNot(contains('Welcome to')));
      expect(partial.style?.fontFamily, 'monospace');
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('welcome-command'))).data,
        contains('Welcome to'),
      );
      final middleZoom = tester
          .widget<Transform>(find.byKey(const ValueKey('welcome-zoom')))
          .transform
          .storage[0];
      expect(middleZoom, greaterThan(1 / 1.2));
      expect(middleZoom, lessThan(1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('welcome-zoom')))
            .transform
            .storage[0],
        lessThan(1),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('welcome-zoom')))
            .transform
            .storage[0],
        closeTo(1, .001),
      );
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Choose your preferred theme'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'reduced motion makes Start immediately available and skips the fade',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(library: library)),
      );
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('Choose your preferred theme'), findsOneWidget);
      expect(library.themeId, 'obsidian');
      expect(find.byKey(const ValueKey('welcome-command')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'first install defaults to Enter Sandman, saves an unfinished choice, and completes once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      expect(library.themeId, 'obsidian');
      expect(library.onboardingComplete, isFalse);
      await library.setTheme('daydream');
      final unfinished = await Library.load();
      expect(unfinished.onboardingComplete, isFalse);
      expect(unfinished.themeId, 'daydream');
      await unfinished.completeOnboarding();
      final restored = await Library.load();
      expect(restored.onboardingComplete, isTrue);
      expect(restored.themeId, 'daydream');
    },
  );
  test(
    'existing installations skip welcome and retain their saved theme',
    () async {
      SharedPreferences.setMockInitialValues({
        'undertune.library.v1':
            '{"theme":"pastelghost","liked":[],"playlists":[]}',
      });
      final library = await Library.load();
      expect(library.onboardingComplete, isTrue);
      expect(library.themeId, 'pastelghost');
    },
  );
  testWidgets(
    'welcome leads to a responsive theme picker and persists completion',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(UndertuneApp(library: library));
      await tester.pump();
      expect(find.byKey(const ValueKey('welcome-command')), findsOneWidget);
      expect(find.text('Undertune'), findsOneWidget);
      expect(find.text('Your Library'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester.widget<Text>(find.text('Start')).style?.fontFamily,
        'Feelfree',
      );
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Choose your preferred theme'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Bad Romance').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Bad Romance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(library.themeId, 'daydream');
      expect(
        Theme.of(tester.element(find.text('Bad Romance'))).brightness,
        Brightness.light,
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('welcome-command')), findsNothing);
      expect(find.text('Your Library'), findsOneWidget);
      expect((await Library.load()).onboardingComplete, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
