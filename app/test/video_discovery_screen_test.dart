import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/video_catalog.dart';
import 'package:undertune/screens/video_channel.dart';
import 'package:undertune/screens/video_playlist.dart';
import 'package:undertune/screens/search.dart';
import 'package:undertune/screens/library.dart';
import 'package:undertune/theme.dart';
import 'package:undertune/widgets/branding.dart';

const source = VideoChannel(
  id: 'UCone',
  url: 'https://youtube.com/channel/UCone',
  name: 'Creator',
);
const videoPlaylist = RemoteVideoPlaylist(
  id: 'PLone',
  url: 'https://youtube.com/playlist?list=PLone',
  name: 'Video collection',
  count: 2,
);
const video = Track(
  url: 'watch',
  title: 'A real video',
  artist: 'Creator',
  video: true,
);
Widget row(Track t, List<Track> _) => ListTile(title: Text(t.title));
Widget host(Widget child, [Atmosphere? theme]) => MaterialApp(
  theme: (theme ?? Atmosphere.all[3]).data,
  home: Scaffold(body: child),
);

class Catalog extends VideoCatalog {
  final requests = <String>[];
  Completer<VideoCatalogPage>? popular;
  bool fail = false, empty = false;
  @override
  Future<VideoChannel> channel(
    VideoChannel source, {
    bool refresh = false,
  }) async => VideoChannel(
    id: source.id,
    url: source.url,
    name: source.name,
    description: 'Channel description',
    tabs: ['videos', 'playlists'],
    sorts: ['latest', 'popular'],
  );
  @override
  Future<VideoCatalogPage> channelItems(
    VideoChannel source, {
    String tab = 'videos',
    String sort = 'latest',
    String? page,
    bool refresh = false,
  }) async {
    requests.add('$tab:$sort:${page ?? 'first'}');
    if (fail) throw StateError('Network');
    if (sort == 'popular' && popular != null) return popular!.future;
    return VideoCatalogPage(
      videos: empty || tab == 'playlists' ? [] : [video],
      playlists: tab == 'playlists' ? [videoPlaylist] : [],
      nextPage: page == null ? 'next' : null,
    );
  }

  @override
  Future<VideoCatalogPage> playlist(
    RemoteVideoPlaylist source, {
    String? page,
    bool refresh = false,
  }) async {
    if (fail) throw StateError('Private');
    return VideoCatalogPage(videos: empty ? [] : [video], playlist: source);
  }

  @override
  Future<VideoCatalogPage> search(
    String query,
    String kind, {
    String? page,
    bool refresh = false,
  }) async => VideoCatalogPage(
    channels: kind == 'Channels' ? [source] : [],
    playlists: kind == 'Playlists' ? [videoPlaylist] : [],
  );
}

class OfflineChannelCatalog extends Catalog {
  @override
  Future<VideoChannel> channel(VideoChannel source, {bool refresh = false}) => Future.error(StateError('Offline'));
}
class Videos extends Extractor {
  @override
  Future<SearchPage> search(String query, {String? page}) async =>
      SearchPage([video], null);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'provider title numerals use readable fallback without changing lettering',
    (tester) async {
      await tester.pumpWidget(host(const MediaHeading('Retro Tech S2')));
      final text = tester.widget<Text>(find.text('Retro Tech S2'));
      final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(text.style!.fontFamily, 'Feelfree');
      expect(spans.last.text, '2');
      expect(spans.last.style!.fontFamily, isNot('Feelfree'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'channel follows, lists playlists, and discards a late Popular response',
    (tester) async {
      final library = await Library.load();
      final catalog = Catalog();
      RemoteVideoPlaylist? opened;
      await tester.pumpWidget(
        host(
          VideoChannelScreen(
            channel: source,
            library: library,
            catalog: catalog,
            row: row,
            onPlaylist: (p) => opened = p,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('A real video'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Latest'))
            .showCheckmark,
        isFalse,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Popular'))
            .showCheckmark,
        isFalse,
      );
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(find.text('Following'), findsOneWidget);
      expect((await Library.load()).followedChannels.single.id, source.id);
      catalog.popular = Completer<VideoCatalogPage>();
      await tester.tap(find.text('Popular'));
      await tester.pump();
      await tester.tap(find.text('Latest'));
      await tester.pump();
      await tester.pump();
      catalog.popular!.complete(
        const VideoCatalogPage(
          videos: [
            Track(
              url: 'stale',
              title: 'Stale popular',
              artist: 'C',
              video: true,
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Stale popular'), findsNothing);
      expect(find.text('A real video'), findsOneWidget);
      await tester.tap(find.text('Playlists'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Video collection'));
      expect(opened?.id, videoPlaylist.id);
      expect(
        catalog.requests,
        containsAll([
          'videos:latest:first',
          'videos:popular:first',
          'playlists:latest:first',
        ]),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('known followed channels can unfollow and refollow without a network', (tester) async {
    final library = await Library.load();
    await library.setFollowing(source, true);
    await tester.pumpWidget(host(VideoChannelScreen(channel: source, library: library, catalog: OfflineChannelCatalog(), row: row, onPlaylist: (_) {})));
    await tester.pump();
    await tester.tap(find.text('Following')); await tester.pump();
    expect(library.isFollowing(source), isFalse);
    await tester.tap(find.text('Follow')); await tester.pump();
    expect(library.isFollowing(source), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('video playlist saves/removes and stays out of music tracks', (
    tester,
  ) async {
    final library = await Library.load();
    final catalog = Catalog();
    Track? played;
    await tester.pumpWidget(
      host(
        VideoPlaylistScreen(
          playlist: videoPlaylist,
          library: library,
          catalog: catalog,
          row: row,
          onPlay: (t) => played = t,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add to Your Library'));
    await tester.pump();
    expect(library.videoPlaylists, hasLength(1));
    expect(library.tracks, isEmpty);
    await tester.tap(find.text('Play'));
    expect(played?.video, isTrue);
    await tester.tap(find.text('Remove from Your Library'));
    await tester.pump();
    expect(library.videoPlaylists, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'channel and playlist headers fit all current themes at narrow large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final library = await Library.load();
      for (final theme in Atmosphere.all) {
        final catalog = Catalog()..empty = true;
        await tester.pumpWidget(
          host(
            VideoChannelScreen(
              key: ValueKey('c${theme.id}'),
              channel: source,
              library: library,
              catalog: catalog,
              row: row,
              onPlaylist: (_) {},
            ),
            theme,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull, reason: theme.name);
        await tester.pumpWidget(
          host(
            VideoPlaylistScreen(
              key: ValueKey('p${theme.id}'),
              playlist: videoPlaylist,
              library: library,
              catalog: catalog,
              row: row,
              onPlay: (_) {},
            ),
            theme,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: theme.name);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'private video playlists show short error and retry to empty state',
    (tester) async {
      final library = await Library.load();
      final catalog = Catalog()..fail = true;
      await tester.pumpWidget(
        host(
          VideoPlaylistScreen(
            playlist: videoPlaylist,
            library: library,
            catalog: catalog,
            row: row,
            onPlay: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Retry'), 180);
      expect(find.textContaining('private or unavailable'), findsOneWidget);
      catalog
        ..fail = false
        ..empty = true;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.textContaining('No playable videos'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Videos discovers channels and playlists without focusing keyboard',
    (tester) async {
      final library = await Library.load();
      VideoChannel? opened;
      await tester.pumpWidget(
        host(
          SearchScreen(
            library: library,
            extractor: Videos(),
            catalog: Catalog(),
            video: true,
            row: row,
            onChannel: (c) => opened = c,
          ),
        ),
      );
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.text('Channels'));
      await tester.pump();
      await tester.tap(find.text('Creator'));
      expect(opened?.id, source.id);
      await tester.tap(find.text('Playlists'));
      await tester.pump();
      expect(find.text('Video collection'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Liked videos has its own local Videos area and filters separately',
    (tester) async {
      final library = await Library.load();
      await library.toggleLike(video);
      await tester.pumpWidget(
        host(
          SearchScreen(
            library: library,
            extractor: Videos(),
            catalog: Catalog(),
            video: true,
            row: row,
          ),
        ),
      );
      await tester.pump();
      final chip = find.widgetWithText(ChoiceChip, 'Liked videos');
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
      expect(find.text('A real video'), findsOneWidget);
      expect(find.text('Search liked videos'), findsOneWidget);
      expect(library.liked, isEmpty);
      expect(library.tracks, isEmpty);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.text('No matching liked videos.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Library labels saved video playlists without changing track counts',
    (tester) async {
      final library = await Library.load();
      await library.saveVideoPlaylist(videoPlaylist);
      RemoteVideoPlaylist? opened;
      await tester.pumpWidget(
        host(
          LibraryScreen(
            library: library,
            onCollection: (_) {},
            onVideos: () {},
            onDownloads: () {},
            trackRow: row,
            onVideoPlaylist: (p) => opened = p,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('2 playlists · 0 tracks'), findsOneWidget);
      await tester.ensureVisible(find.text('Video collection'));
      await tester.tap(find.text('Video collection'));
      expect(opened?.id, videoPlaylist.id);
      expect(find.text('Video playlist · 2 videos'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
