import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';
import 'package:undertune/media/downloads.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/playback.dart';

class PreparingDownload extends Downloads {
  var pending = Completer<void>();
  int requests = 0;
  @override
  Future<void> enqueue(
    Track track,
    Extractor extractor, {
    Library? preferences,
  }) {
    requests++;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'download preparation stays contextual and failure offers an explicit retry',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      await library.saveTrack(
        const Track(url: 'song', title: 'Saved song', artist: 'Artist'),
      );
      final downloads = PreparingDownload();
      final extractor = Extractor();
      final playback = Playback(extractor, library);
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
      await tester.tap(find.text('Your Library'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Tracks').last);
      await tester.pump();
      await tester.tap(find.byTooltip('Track actions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Download audio'));
      await tester.tap(find.text('Download audio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Preparing download…'), findsOneWidget);
      await tester.tap(find.text('Home').last);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Your collection'), findsOneWidget);
      downloads.pending.completeError(StateError('native failure details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Preparing download…'), findsNothing);
      expect(find.text('Download couldn’t start.'), findsOneWidget);
      expect(find.textContaining('native failure details'), findsNothing);
      downloads.pending = Completer<void>();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Retry').hitTestable());
      await tester.pump();
      expect(downloads.requests, 2);
      downloads.pending.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Download started'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      playback.dispose();
      downloads.dispose();
    },
  );
}
