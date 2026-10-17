import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/downloads.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/playback.dart';
import 'package:undertune/screens/home.dart';
import 'package:undertune/screens/library.dart';
import 'package:undertune/screens/player.dart';
import 'package:undertune/screens/playlist.dart';
import 'package:undertune/theme.dart';
import 'package:undertune/widgets/loading.dart';
import 'package:undertune/widgets/track_row.dart';
import 'package:undertune/widgets/video_card.dart';

const song = Track(
  url: 'one',
  title:
      'A very long track title with multiple words that must remain inside its row',
  artist: 'A long artist name and collaborators',
  duration: 234,
);
void main() {
  for (final viewport in [
    const Size(320, 568),
    const Size(412, 915),
    const Size(740, 360),
  ]) {
    testWidgets(
      'all themes retain compact rows and usable screens at $viewport',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final library = await Library.load();
        final id = await library.createPlaylist(
          'A playlist with a very long custom title',
        );
        await library.addToPlaylist(id, song);
        await library.toggleLike(song);
        final playback = Playback(Extractor(), library)..current = song;
        final downloads = Downloads();
        Widget row(Track track, List<Track> queue) => TrackRow(
          track: track,
          onTap: () {},
          onLike: () {},
          onMore: () {},
          liked: true,
          downloaded: true,
          artworkSize: 57.6,
          horizontalPadding: 20,
          artworkGap: 10,
          titleLines: 2,
          showDuration: true,
          verticalPadding: 4,
        );
        final scale = viewport.width == 320 ? 2.0 : 1.3;
        Future<void> show(
          Atmosphere atmosphere,
          Widget body,
          String label,
        ) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: atmosphere.data,
              home: MediaQuery(
                data: MediaQueryData(
                  size: viewport,
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: Scaffold(body: body),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${atmosphere.name}: $label, $viewport / $scale',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }

        for (final atmosphere in Atmosphere.all) {
          await library.setTheme(atmosphere.id);
          await show(
            atmosphere,
            SingleChildScrollView(
              child: Column(
                children: [
                  row(song, [song]),
                  VideoCard(
                    track: song.asVideo(true),
                    onTap: () {},
                    onMore: () {},
                  ),
                  const ContentSkeleton(
                    artworkSize: 64,
                    titleLines: 2,
                    horizontalPadding: 20,
                    verticalPadding: 4,
                    artworkGap: 10,
                  ),
                  const ContentSkeleton(video: true, count: 1),
                ],
              ),
            ),
            'shared rows/loading',
          );
          await show(
            atmosphere,
            HomeScreen(
              library: library,
              extractor: Extractor(),
              active: false,
              onCollection: (_) {},
              onVideos: () {},
              onSearch: () {},
              onPlay: (_, _) {},
              suggestionRow: row,
            ),
            'Home',
          );
          await show(
            atmosphere,
            LibraryScreen(
              library: library,
              onCollection: (_) {},
              onVideos: () {},
              onDownloads: () {},
              trackRow: row,
            ),
            'Library',
          );
          await show(
            atmosphere,
            PlaylistScreen(
              id: id,
              library: library,
              extractor: Extractor(),
              playback: playback,
              downloads: downloads,
              onPlay: (_, _) {},
              onActions: (_) {},
              onDeleted: () {},
            ),
            'Playlist',
          );
          await show(
            atmosphere,
            PlayerScreen(
              playback: playback,
              library: library,
              onAdd: (_) async {},
              onActions: (_) async {},
              onPlay: (_) async {},
            ),
            'Now Playing',
          );
        }
        playback.dispose();
        downloads.dispose();
      },
    );
  }
}
