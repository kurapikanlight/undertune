import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';

void main() {
  for (final dismiss in [false, true]) {
    testWidgets(
      'theme picker preserves Home when ${dismiss ? 'dismissed during save' : 'selected repeatedly'}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(411, 914));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({
          'undertune.library.v1': jsonEncode({
            'theme': 'afterglow',
            'onboardingComplete': true,
          }),
        });
        final library = await Library.load();
        final store = DelayedStore();
        SharedPreferencesStorePlatform.instance = store;
        await tester.pumpWidget(UndertuneApp(library: library));
        await tester.pump();
        await tester.tap(find.byTooltip('Open menu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Themes'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Amethyst'));
        if (dismiss) {
          await tester.binding.handlePopRoute();
        } else {
          // A second tap can arrive while the native preference write is pending.
          await tester.tap(find.text('Goth'));
        }
        store.ready.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(library.themeId, dismiss ? 'pastelghost' : 'sidewalks');
        expect((await Library.load()).themeId, library.themeId);
        expect(find.byTooltip('Open menu'), findsOneWidget);
        expect(find.text('Home'), findsWidgets);
        await tester.tap(find.byTooltip('Open menu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Themes'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

// Keep real Library persistence and UI; delay only the native disk boundary.
class DelayedStore extends InMemorySharedPreferencesStore {
  DelayedStore() : super.empty();
  final ready = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await ready.future;
    return super.setValue(valueType, key, value);
  }
}
