import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/screens/about.dart';
import 'package:undertune/theme.dart';

void main() {
  testWidgets(
    'About follows dark and light themes while its signature stays black and font terms open',
    (tester) async {
      for (final atmosphere in [Atmosphere.all.first, Atmosphere.all.last]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: atmosphere.data,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showAboutUndertune(context),
                  child: const Text('About'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('About'));
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.text('Kafeyn'))).brightness,
          atmosphere.data.brightness,
        );
        final badge = tester.widget<Container>(
          find.byKey(const ValueKey('kafeyn-signature')),
        );
        expect((badge.decoration as BoxDecoration).color, Colors.black);
        final signature = tester.widget<Image>(
          find.descendant(
            of: find.byKey(const ValueKey('kafeyn-signature')),
            matching: find.byType(Image),
          ),
        );
        expect(
          ((signature.image as ResizeImage).imageProvider as AssetImage)
              .assetName,
          'assets/branding/signature.webp',
        );
        expect(
          tester.widget<Text>(find.text('Kafeyn')).style?.fontFamily,
          'Feelfree',
        );
        await tester.scrollUntilVisible(
          find.text('Feelfree font license').hitTestable(),
          250,
          scrollable: find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text('Feelfree font license'));
        await tester.pumpAndSettle();
        final notice = tester.widget<SelectableText>(
          find.byType(SelectableText),
        );
        expect(notice.data, contains('Designer: Billy Argel'));
        expect(notice.data, contains('free for personal use only'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
}
