import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/widgets/discovery.dart';

class PendingDiscovery extends Extractor {
  final requests = <String, Completer<SearchPage>>{};
  @override
  Future<SearchPage> search(String query, {String? page}) =>
      (requests[query] = Completer<SearchPage>()).future;
}

class FullDiscovery extends Extractor {
  @override
  Future<SearchPage> search(String query, {String? page}) async => SearchPage(
    List.generate(
      20,
      (i) => Track(
        url: '$query-$i',
        title: 'Suggested track $i',
        artist: 'Artist',
      ),
    ),
    null,
  );
}

void main() {
  testWidgets('music suggestions display up to 24 unique tracks', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = await Library.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Discovery(
              library: library,
              extractor: FullDiscovery(),
              row: (t, q) => Text(t.title),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Suggested track'), findsNWidgets(24));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'discovery starts honestly and ignores an obsolete genre response',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final extractor = PendingDiscovery();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Discovery(
                library: library,
                extractor: extractor,
                row: (t, queue) => Text(t.title),
              ),
            ),
          ),
        ),
      );
      expect(extractor.requests, isNotEmpty);
      final old = extractor.requests.values.toList();
      expect(find.text('Based on your taste'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      final genreScroll = tester.widgetList<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        genreScroll.any((s) => s.scrollDirection == Axis.horizontal),
        isTrue,
      );
      await library.setGenres(['Jazz']);
      await tester.pump();
      final current = extractor.requests.entries.last;
      expect(current.key.toLowerCase(), contains('jazz'));
      current.value.complete(
        SearchPage([
          const Track(url: 'jazz', title: 'Current music', artist: 'Artist'),
        ], null),
      );
      for (final request in old) {
        request.complete(
          SearchPage([
            const Track(url: 'old', title: 'Obsolete music', artist: 'Artist'),
          ], null),
        );
      }
      await tester.pump();
      await tester.pump();
      expect(find.text('Current music'), findsWidgets);
      expect(find.text('Obsolete music'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
