import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/screens/home.dart';

class EmptyDiscovery extends Extractor {
  @override
  Future<SearchPage> search(String query, {String? page}) async =>
      SearchPage([], null);
}

void main() {
  testWidgets(
    'Home keeps horizontal shelves before the bottom suggestions section',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      await library.createPlaylist('Night');
      for (var i = 0; i < 8; i++) {
        await library.played(
          Track(url: '$i', title: 'History $i', artist: 'Artist'),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              library: library,
              extractor: EmptyDiscovery(),
              onCollection: (_) {},
              onVideos: () {},
              onSearch: () {},
              onPlay: (t, q) {},
              suggestionRow: (t, q) => Text(t.title),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Night')).dx,
        lessThan(tester.getTopLeft(find.text('Tracks')).dx),
      );
      expect(
        tester.getTopLeft(find.text('Tracks')).dx,
        lessThan(tester.getTopLeft(find.text('Liked')).dx),
      );
      expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
      expect(find.text('A space for\nyour sound.'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Music suggestions'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Genre'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Recently played')).dy,
        lessThan(tester.getTopLeft(find.text('Music suggestions')).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
