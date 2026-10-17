import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';
import 'package:undertune/media/downloads.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/playback.dart';
import 'package:undertune/screens/home.dart';
import 'package:undertune/widgets/loading.dart';

class PendingFeed extends Extractor {
  final requests = <Completer<SearchPage>>[];
  @override
  Future<SearchPage> search(String query, {String? page}) {
    final response = Completer<SearchPage>();
    requests.add(response);
    return response.future;
  }
}

void main() {
  testWidgets(
    'hidden tabs pause loading animation without restarting requests',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final extractor = PendingFeed();
      final playback = Playback(extractor, library);
      final downloads = Downloads();
      await tester.pumpWidget(
        MaterialApp(
          home: UndertuneShell(
            library: library,
            extractor: extractor,
            playback: playback,
            downloads: downloads,
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byType(ContentSkeleton),
        180,
        scrollable: find
            .descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final homePulse = find.descendant(
        of: find.byType(HomeScreen, skipOffstage: false),
        matching: find.byType(SkeletonPulse, skipOffstage: false),
        skipOffstage: false,
      );
      final homeFade = find.descendant(
        of: homePulse,
        matching: find.byType(FadeTransition, skipOffstage: false),
        skipOffstage: false,
      );
      expect(homeFade, findsOneWidget);
      final count = extractor.requests.length;
      await tester.tap(find.text('Your Library'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(homeFade, findsNothing);
      await tester.tap(find.text('Home').last);
      await tester.pump();
      expect(homeFade, findsOneWidget);
      expect(extractor.requests.length, count);
      for (final request in extractor.requests) {
        request.complete(SearchPage([], null));
      }
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      playback.dispose();
      downloads.dispose();
    },
  );
}
