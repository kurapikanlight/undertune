import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/downloads.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/screens/downloads.dart';
import 'package:undertune/screens/search.dart';
import 'package:undertune/widgets/loading.dart';

class PendingSuggestions extends Extractor {
  final requests = <String, Completer<List<String>>>{};
  @override
  Future<List<String>> suggestions(String query) =>
      (requests[query] = Completer<List<String>>()).future;
}

void main() {
  testWidgets(
    'downloads distinguish pending, failed, empty and cached refresh',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final downloads = Downloads();
      var response = Completer<List<dynamic>>();
      const channel = MethodChannel('undertune/downloads');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) => response.future);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadsScreen(
            downloads: downloads,
            library: library,
            onPlay: (_) {},
          ),
        ),
      );
      expect(find.text('No audio downloads yet.'), findsNothing);
      expect(find.byType(ContentSkeleton), findsOneWidget);
      response.completeError(PlatformException(code: 'offline'));
      await tester.pump();
      expect(find.byType(ContentSkeleton), findsNothing);
      expect(find.text('No audio downloads yet.'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      response = Completer<List<dynamic>>();
      await tester.tap(find.text('Retry'));
      response.complete([]);
      await tester.pump();
      expect(find.text('No audio downloads yet.'), findsOneWidget);
      response = Completer<List<dynamic>>();
      final refresh = downloads.refresh();
      response.complete([
        {
          'id': 1,
          'track': const Track(
            url: 'one',
            title: 'Saved song',
            artist: 'Artist',
          ).toJson(),
          'status': 'complete',
          'bytes': 1,
          'total': 1,
        },
      ]);
      await tester.pump();
      await refresh;
      response = Completer<List<dynamic>>();
      final cachedRefresh = downloads.refresh();
      await tester.pump();
      expect(find.text('Saved song'), findsOneWidget);
      expect(find.byType(ContentSkeleton), findsNothing);
      response.completeError(PlatformException(code: 'offline'));
      await tester.pump();
      await cachedRefresh;
      await tester.pump();
      expect(find.text('Saved song'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      downloads.dispose();
    },
  );
  testWidgets(
    'suggestions show real pending state, ignore obsolete replies and keep focus deliberate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final extractor = PendingSuggestions();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchScreen(
              library: library,
              extractor: extractor,
              active: false,
              row: (track, queue) => Text(track.title),
            ),
          ),
        ),
      );
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'first');
      await tester.pump(const Duration(milliseconds: 301));
      expect(find.byType(SuggestionSkeleton), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'second');
      await tester.pump(const Duration(milliseconds: 301));
      extractor.requests['first']!.complete(['obsolete']);
      await tester.pump();
      expect(find.text('obsolete'), findsNothing);
      expect(find.byType(SuggestionSkeleton), findsOneWidget);
      extractor.requests['second']!.complete(['current suggestion']);
      await tester.pump();
      expect(find.text('current suggestion'), findsOneWidget);
      expect(find.byType(SuggestionSkeleton), findsNothing);
      expect(extractor.requests.length, 2);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
