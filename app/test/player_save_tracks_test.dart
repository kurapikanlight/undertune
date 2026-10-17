import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/playback.dart';
import 'package:undertune/screens/player.dart';

void main() {
  testWidgets(
    'Now Playing keeps save actions in overflow and plus at large text on a small screen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      const track = Track(
        url: 'independent-save',
        title: 'A saved song',
        artist: 'Artist',
      );
      final playback = Playback(Extractor(), library)..current = track;
      Track? actionsTrack, playlistTrack;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            playback: playback,
            library: library,
            onAdd: (t) async {
              playlistTrack = t;
            },
            onActions: (t) async {
              actionsTrack = t;
            },
            onPlay: (_) async {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Track actions'));
      await tester.pump();
      expect(actionsTrack?.key, track.key);
      await tester.scrollUntilVisible(
        find.byTooltip('Add to playlist').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Add to playlist'));
      await tester.pump();
      expect(playlistTrack?.key, track.key);
      expect(library.liked, isEmpty);
      expect(library.playlists, isEmpty);
      expect(find.text('Add to Tracks'), findsNothing);
      expect(find.text('Added to Tracks'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      playback.dispose();
    },
  );
}
