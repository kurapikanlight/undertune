import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/music_collections.dart';
import 'package:undertune/screens/search.dart';
import 'package:undertune/screens/music_collection.dart';
import 'package:undertune/widgets/music_search_collections.dart';

const album = MusicCollection(
  id: 'OLAK1',
  url: 'https://music.youtube.com/playlist?list=OLAK1',
  name: 'Caméléon',
  artist: 'ElGrandeToto',
  kind: 'album',
);
const one = Track(url: 'one', title: 'One', artist: 'Toto');
const two = Track(url: 'two', title: 'Two', artist: 'Toto');

class Catalog extends MusicCatalog {
  bool fail = false;
  final searches = <String>[];
  @override
  Future<MusicCollectionPage> search(
    String query, {
    String kind = 'album',
    String? page,
  }) async {
    searches.add(kind);
    return MusicCollectionPage(
      collections: kind == 'album'
          ? [album]
          : [
              const MusicCollection(
                id: 'mix',
                url: 'https://youtube.com/playlist?list=mix',
                name: 'Toto mix',
              ),
            ],
    );
  }

  @override
  Future<MusicCollectionPage> collection(
    MusicCollection source, {
    String? page,
  }) async {
    if (page != null && fail) throw StateError('Offline');
    return page == null
        ? const MusicCollectionPage(tracks: [one], nextPage: 'next')
        : const MusicCollectionPage(tracks: [two]);
  }
}

class Songs extends Extractor {
  @override
  Future<SearchPage> search(String query, {String? page}) async =>
      SearchPage([one, two], null);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'track search includes albums and playlists with collection actions',
    (tester) async {
      final library = await Library.load();
      MusicCollection? opened;
      final catalog = Catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchScreen(
              library: library,
              extractor: Songs(),
              musicCatalog: catalog,
              row: (t, q) => ListTile(title: Text(t.title)),
              onMusicCollection: (source) => opened = source,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'toto cameleon');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Toto mix'),
        120,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(catalog.searches, ['album', 'playlist']);
      expect(find.byTooltip('Actions for Toto mix'), findsOneWidget);
      await tester.tap(find.text('Toto mix'));
      expect(opened?.kind, 'playlist');
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final fail in [false, true]) {
    testWidgets(
      'album import ${fail ? 'preserves library on pagination failure' : 'includes all pages as music'}',
      (tester) async {
        final library = await Library.load();
        String? saved;
        final catalog = Catalog()..fail = fail;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MusicCollectionScreen(
                collection: album,
                catalog: catalog,
                library: library,
                row: (t, q) => ListTile(title: Text(t.title)),
                onSaved: (id) => saved = id,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.widget<Text>(find.text('Caméléon')).style?.fontFamily,
          isNot('Feelfree'),
        );
        await tester.ensureVisible(find.text('Add to Your Library'));
        await tester.pump();
        await tester.tap(find.text('Add to Your Library'));
        await tester.pump();
        await tester.pump();
        if (fail) {
          expect(library.playlists, isEmpty);
          expect(saved, isNull);
          expect(
            find.textContaining('Couldn’t add the collection'),
            findsOneWidget,
          );
        } else {
          expect(saved, album.key);
          expect(library.playlists.single.tracks.map((t) => t.title), [
            'One',
            'Two',
          ]);
          expect(library.videoPlaylists, isEmpty);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final toPlaylist in [false, true]) {
    testWidgets(
      'search album overflow adds all pages to ${toPlaylist ? 'an existing playlist' : 'the library'}',
      (tester) async {
        final library = await Library.load();
        final target = await library.createPlaylist('My mix');
        await library.addToPlaylist(target, one);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MusicSearchCollections(
                  query: 'toto cameleon',
                  catalog: Catalog(),
                  library: library,
                  onOpen: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Actions for Caméléon'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(toPlaylist ? 'Add to playlist' : 'Add to Your Library'),
        );
        await tester.pumpAndSettle();
        if (toPlaylist) {
          await tester.tap(find.text('My mix'));
          await tester.pumpAndSettle();
          expect(library.playlists.single.tracks.map((t) => t.url), [
            'one',
            'two',
          ]);
        } else {
          final imported = library.playlists.singleWhere(
            (p) => p.id == album.key,
          );
          expect(imported.tracks.map((t) => t.url), ['one', 'two']);
        }
        expect(library.videoPlaylists, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
