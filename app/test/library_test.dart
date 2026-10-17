import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';

void main() {
  test(
    'saving to Tracks persists without liking or playlist membership and stays unique',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      const track = Track(
        url: 'saved-alone',
        title: 'Saved song',
        artist: 'Artist',
      );
      await library.saveTrack(track);
      await library.saveTrack(track.asVideo(true));
      expect(library.tracks, hasLength(1));
      expect(library.liked, isEmpty);
      expect(library.playlists, isEmpty);
      final restored = await Library.load();
      expect(restored.isSaved(track), isTrue);
      expect(restored.savedTracks.single.video, isFalse);
      final id = await restored.createPlaylist('Other');
      await restored.addToPlaylist(id, track);
      await restored.toggleLike(track);
      expect(restored.tracks, hasLength(1));
      await restored.toggleLike(track);
      await restored.deletePlaylist(id);
      expect((await Library.load()).tracks.single.key, track.key);
    },
  );

  test(
    'SponsorBlock defaults on for new libraries and preserves a saved opt-out',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      expect(library.sponsorBlock, isTrue);
      await library.setSponsorBlock(false);
      expect((await Library.load()).sponsorBlock, isFalse);
      SharedPreferences.setMockInitialValues({
        'undertune.library.v1': '{"theme":"daydream"}',
      });
      expect((await Library.load()).sponsorBlock, isTrue);
    },
  );

  test(
    'likes and playlist membership persist independently with canonical identity',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      const track = Track(
        url: 'https://www.youtube.com/watch?v=a',
        title: 'A',
        artist: 'Artist',
      );
      final id = await library.createPlaylist('Road');
      await library.addToPlaylist(id, track);
      await library.toggleLike(track);
      await library.toggleLike(track);
      await library.setTheme('daydream');
      await library.setGenres(['Ambient', 'Rock']);
      await library.setSponsorBlock(true);
      final restored = await Library.load();
      expect(restored.liked, isEmpty);
      expect(restored.playlists.single.tracks.single.key, track.key);
      expect(restored.themeId, 'daydream');
      expect(restored.genres, ['Ambient', 'Rock']);
      expect(restored.sponsorBlock, true);
      await restored.addToPlaylist(id, track);
      expect(restored.playlists.single.tracks.length, 1);
    },
  );
}
