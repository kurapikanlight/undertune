import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/music_collections.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'imported albums persist source metadata and audio tracks without video-library entries',
    () async {
      final library = await Library.load();
      const album = MusicCollection(
        id: 'OLAK1',
        url: 'https://music.youtube.com/playlist?list=OLAK1',
        name: 'Caméléon',
        artist: 'ElGrandeToto',
        kind: 'album',
        artwork: 'https://art.test/cover',
      );
      final id = await library.saveMusicCollection(album, [
        const Track(url: 'song', title: 'Song', artist: 'Toto', video: true),
      ]);
      expect(library.playlists.single.tracks.single.video, isFalse);
      expect(library.videoPlaylists, isEmpty);
      expect(library.liked, isEmpty);
      final restored = await Library.load();
      expect(restored.playlists.single.id, id);
      expect(restored.playlists.single.sourceUrl, album.url);
      expect(restored.playlists.single.sourceArtwork, album.artwork);
      expect(restored.playlists.single.collectionKind, 'album');
      expect(await restored.saveMusicCollection(album, []), id);
      expect(restored.playlists.single.tracks, hasLength(1));
    },
  );
}
