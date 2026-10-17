import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/widgets/favorite_icon.dart';

void main() {
  testWidgets(
    'favorite feedback settles into the new state and respects reduced motion',
    (tester) async {
      Widget view(bool liked, {bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: FavoriteIcon(liked: liked),
        ),
      );
      await tester.pumpWidget(view(false));
      await tester.pumpWidget(view(true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      await tester.pumpWidget(view(false, reduced: true));
      await tester.pump();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
