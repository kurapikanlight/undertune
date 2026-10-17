import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/widgets/playlist_cover.dart';

void main() {
  test('playlist name, custom image and track order survive restart', () async {
    SharedPreferences.setMockInitialValues({});
    final library = await Library.load();
    final id = await library.createPlaylist('Test');
    final tracks = List.generate(
      5,
      (i) => Track(url: '$i', title: '$i', artist: 'A'),
    );
    await library.addTracksToPlaylist(id, tracks);
    await library.addTracksToPlaylist(id, tracks);
    await library.editPlaylist(
      id,
      name: 'Night',
      coverPath: '/saved/cover.jpg',
    );
    await library.reorderPlaylist(id, 0, 5);
    await library.removeFromPlaylist(id, tracks[1]);
    final restored = await Library.load();
    final playlist = restored.playlists.single;
    expect(playlist.name, 'Night');
    expect(playlist.coverPath, '/saved/cover.jpg');
    expect(playlist.tracks.map((t) => t.url), ['2', '3', '4', '0']);
    await restored.editPlaylist(id, name: 'Night', coverPath: null);
    expect((await Library.load()).playlists.single.coverPath, isNull);
  });

  testWidgets('automatic covers follow contents while Liked keeps its heart', (
    tester,
  ) async {
    final tracks = List.generate(
      5,
      (i) => Track(
        url: '$i',
        title: '$i',
        artist: 'A',
        artwork: 'https://example.com/$i.jpg',
      ),
    );
    Future<void> show(List<Track> contents, {bool liked = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: PlaylistCover(tracks: contents, size: 96, liked: liked),
          ),
        ),
      );
      await tester.pump();
    }

    await show([]);
    expect(find.byType(Image), findsNothing);
    expect(
      tester.widget<ColoredBox>(find.byType(ColoredBox).last).color,
      Colors.black,
    );
    await show(tracks.take(1).toList());
    expect(find.byType(Image), findsOneWidget);
    await show(tracks.take(3).toList());
    expect(find.byType(Image), findsNWidgets(2));
    await show(tracks);
    expect(find.byType(Image), findsNWidgets(4));
    await show(tracks.reversed.toList());
    final first = tester.widget<Image>(find.byType(Image).first);
    final decoded = first.image as ResizeImage;
    expect((decoded.imageProvider as NetworkImage).url, tracks.last.artwork);
    expect(decoded.width, (48 * tester.view.devicePixelRatio).round());
    await show(tracks, liked: true);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
