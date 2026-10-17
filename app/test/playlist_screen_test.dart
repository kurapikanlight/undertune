import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/downloads.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/playback.dart';
import 'package:undertune/screens/playlist.dart';
import 'package:undertune/widgets/playlist_cover.dart';

class PlaylistSearch extends Extractor {
  @override
  Future<SearchPage> search(String query, {String? page}) async => SearchPage(
    List.generate(
      20,
      (i) =>
          Track(url: '$i', title: 'Song $i', artist: 'Artist', duration: 120),
    ),
    null,
  );
}

void main() {
  testWidgets(
    'playlist adds 20 search tracks, edits metadata and removes tracks',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final id = await library.createPlaylist('Test');
      final extractor = PlaylistSearch();
      final playback = Playback(extractor, library);
      final downloads = Downloads();
      String? coverPath;
      Directory? coverDirectory;
      await tester.runAsync(() async {
        coverDirectory = await Directory.systemTemp.createTemp(
          'undertune-cover-test-',
        );
        coverPath = '${coverDirectory!.path}/cover.png';
        final image = await createTestImage(width: 32, height: 32);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(coverPath!).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      addTearDown(() => coverDirectory!.delete(recursive: true));
      const channel = MethodChannel('undertune/playlist_images');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => coverPath);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistScreen(
              id: id,
              library: library,
              extractor: extractor,
              playback: playback,
              downloads: downloads,
              onPlay: (_, _) {},
              onActions: (_) {},
              onDeleted: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      // Preload a real custom-cover fixture before the picker returns it.
      // This test verifies editing/persistence; uncached loading/error behavior
      // is exercised separately with controlled image frames.
      final context = tester.element(find.byType(Scaffold).first);
      await tester.runAsync(() async {
        for (final size in [128, 240]) {
          await precacheImage(
            ResizeImage(
              FileImage(File(coverPath!)),
              width: (size * tester.view.devicePixelRatio).round(),
            ),
            context,
          );
        }
      });
      expect(find.byKey(const ValueKey('playlist-hero')), findsOneWidget);
      expect(tester.getSize(find.byType(PlaylistCover).first).width, 240);
      expect(find.byTooltip('Play playlist'), findsOneWidget);
      expect(
        tester.getSize(find.byTooltip('Play playlist')).width,
        closeTo(51.2, .01),
      );
      expect(
        tester.getCenter(find.byTooltip('Play playlist')).dy,
        closeTo(tester.getCenter(find.byTooltip('Playlist actions')).dy, .01),
      );
      expect(find.text('0 tracks · 0 min'), findsOneWidget);
      await tester.tap(find.text('Add track'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'music');
      await tester.tap(find.byTooltip('Find tracks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pump();
      await tester.tap(find.text('Add 20 tracks'));
      await tester.pumpAndSettle();
      expect(library.playlists.single.tracks, hasLength(20));
      expect(find.text('20 tracks · 40 min'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Night test');
      expect(find.text('Follow app theme'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButton<String>));
      await tester.pump();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sienna').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await Library.load()).playlists.single.name, 'Night test');
      expect((await Library.load()).playlists.single.coverPath, coverPath);
      expect(
        (await Library.load()).playlists.single.toJson()['themeId'],
        'midnight_bloom',
      );
      expect(library.themeId, 'obsidian');
      await tester.tap(find.byTooltip('Edit playlist'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButton<String>));
      await tester.pump();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Follow app theme').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        (await Library.load()).playlists.single.toJson()['themeId'],
        isNull,
      );
      await tester.tap(find.byTooltip('Edit tracks'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byTooltip('Remove Song 0').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Remove Song 0'));
      await tester.pumpAndSettle();
      expect(library.playlists.single.tracks, hasLength(19));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      playback.dispose();
      downloads.dispose();
    },
  );

  testWidgets(
    'playlist header and track editing fit small screens at large text',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final id = await library.createPlaylist(
        'A very long playlist name with many words',
      );
      await library.addToPlaylist(
        id,
        const Track(
          url: 'a',
          title: 'A long song name that wraps',
          artist: 'An artist',
        ),
      );
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final extractor = PlaylistSearch();
      final playback = Playback(extractor, library);
      final downloads = Downloads();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistScreen(
              id: id,
              library: library,
              extractor: extractor,
              playback: playback,
              downloads: downloads,
              onPlay: (_, _) {},
              onActions: (_) {},
              onDeleted: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.drag(
        find.byType(ReorderableListView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit tracks'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byTooltip('Remove A long song name that wraps').hitTestable(),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      playback.dispose();
      downloads.dispose();
    },
  );
}
