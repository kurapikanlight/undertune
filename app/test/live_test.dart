import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/screens/live.dart';
import 'package:undertune/widgets/video_card.dart';

class Broadcasts extends Extractor {
  bool ended = false;
  @override
  Future<Map<String, dynamic>> resolve(Track track) async => {
    'live': !ended && track.url == 'on',
  };
}

void main() {
  const on = Track(
    url: 'on',
    title: 'Ongoing',
    artist: 'Station',
    live: true,
    video: true,
  );
  const off = Track(
    url: 'off',
    title: 'Ended',
    artist: 'Station',
    live: true,
    video: true,
  );
  test(
    'legacy streams with unknown duration are verified and moved out of music',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final unknown = on.asVideo(false, live: false);
      await library.saveTrack(unknown);
      await library.checkLegacyLive(Broadcasts());
      expect(library.tracks, isEmpty);
      expect(library.liveStreams.single.live, isTrue);
      expect((await Library.load()).liveStreams.single.key, on.key);
    },
  );
  test(
    'live saves stay separate, reject library paths, and migrate old live items',
    () async {
      SharedPreferences.setMockInitialValues({
        'undertune.library.v1': jsonEncode({
          'liked': [on.toJson()],
          'playlists': [
            {
              'id': 'p',
              'name': 'Test',
              'tracks': [on.toJson()],
            },
          ],
        }),
      });
      final library = await Library.load();
      expect(library.liveStreams.single.key, on.key);
      expect(library.liked, isEmpty);
      expect(library.playlists.single.tracks, isEmpty);
      await expectLater(library.saveTrack(on), throwsArgumentError);
      await expectLater(library.toggleLike(on), throwsArgumentError);
      await expectLater(library.addToPlaylist('p', on), throwsArgumentError);
      await library.played(on);
      expect(library.history, isEmpty);
      expect(library.tracks, isEmpty);
      await library.addLive(off);
      expect((await Library.load()).liveStreams, hasLength(2));
      await library.removeLive(on);
      expect((await Library.load()).liveStreams.single.key, off.key);
    },
  );
  testWidgets(
    'Live shows verified ongoing streams with badge, removes ended streams, and rechecks',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      await library.addLive(on);
      await library.addLive(off);
      final extractor = Broadcasts();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveScreen(
              library: library,
              extractor: extractor,
              onPlay: (_) {},
              onActions: (_) async {},
              onAdd: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VideoCard), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Ended'), findsNothing);
      expect(library.liveStreams.single.key, on.key);
      expect(library.tracks, isEmpty);
      extractor.ended = true;
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.byType(VideoCard), findsNothing);
      expect(library.liveStreams, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
