import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/playback.dart';
import 'package:undertune/widgets/audio_mini_player.dart';

class VisualExtractor extends Extractor {
  final requests = <Track>[];
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> resolve(Track track) {
    requests.add(track);
    return pending.future;
  }
}

void main() {
  testWidgets('downloaded audio never creates or requests a video background', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = await Library.load();
    final extractor = VisualExtractor();
    final playback = Playback(extractor, library)
      ..current = const Track(
        url: 'saved',
        title: 'Downloaded song',
        artist: 'Artist',
      )
      ..playingFromFile = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AudioMiniPlayer(
              playback: playback,
              extractor: extractor,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Downloaded song'), findsOneWidget);
    expect(find.byType(AudioVideoBackground), findsNothing);
    expect(extractor.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
  });

  testWidgets(
    'online audio requests explicit video visuals; switching local discards the pending result',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final extractor = VisualExtractor();
      final playback = Playback(extractor, library)
        ..current = const Track(
          url: 'online',
          title: 'Online song',
          artist: 'Artist',
        );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AudioMiniPlayer(
                playback: playback,
                extractor: extractor,
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(extractor.requests, hasLength(1));
      expect(extractor.requests.single.video, isTrue);
      playback.playingFromFile = true;
      playback.notifyListeners();
      await tester.pump();
      extractor.pending.complete({
        'video': [
          {'url': 'https://example.com/stale.mp4'},
        ],
      });
      await tester.pump();
      expect(find.byType(AudioVideoBackground), findsNothing);
      expect(extractor.requests, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      playback.dispose();
    },
  );
}
