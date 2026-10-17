import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/video_catalog.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const channel = VideoChannel(
    id: 'UCtest',
    url: 'https://www.youtube.com/channel/UCtest',
    name: 'Creator',
  );
  const playlist = RemoteVideoPlaylist(
    id: 'PLtest',
    url: 'https://www.youtube.com/playlist?list=PLtest',
    name: 'Video collection',
    count: 20,
  );
  test(
    'follows and remote playlists survive restart without entering music',
    () async {
      final library = await Library.load();
      await library.saveTrack(
        const Track(url: 'song', title: 'Song', artist: 'Artist'),
      );
      await library.setFollowing(channel, true);
      await library.setFollowing(channel, true);
      await library.saveVideoPlaylist(playlist);
      await library.saveVideoPlaylist(playlist);
      final restored = await Library.load();
      expect(restored.followedChannels.map((c) => c.key), [channel.key]);
      expect(restored.videoPlaylists.map((p) => p.key), [playlist.key]);
      expect(restored.tracks.map((t) => t.url), ['song']);
      expect(restored.playlists, isEmpty);
      await restored.setFollowing(channel, false);
      await restored.removeVideoPlaylist(playlist.key);
      final empty = await Library.load();
      expect(empty.followedChannels, isEmpty);
      expect(empty.videoPlaylists, isEmpty);
      expect(empty.savedTracks, hasLength(1));
    },
  );
  test(
    'failed video saves roll back and leave existing music data intact',
    () async {
      final library = await Library.load();
      await library.saveTrack(
        const Track(url: 'song', title: 'Song', artist: 'Artist'),
      );
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString('undertune.library.v1');
      SharedPreferencesStorePlatform.instance = FailedVideoStore();
      await expectLater(library.setFollowing(channel, true), throwsStateError);
      expect(library.followedChannels, isEmpty);
      await expectLater(library.saveVideoPlaylist(playlist), throwsStateError);
      expect(library.videoPlaylists, isEmpty);
      expect(prefs.getString('undertune.library.v1'), before);
      expect(library.tracks.single.url, 'song');
    },
  );
  test(
    'video likes stay separate from music likes for the same source',
    () async {
      final library = await Library.load();
      const music = Track(url: 'same-source', title: 'Song', artist: 'Artist');
      final video = music.asVideo(true);
      await library.toggleLike(video);
      expect(library.likedVideos.map((t) => t.url), ['same-source']);
      expect(library.liked, isEmpty);
      expect(library.tracks, isEmpty);
      expect(library.isLiked(music), isFalse);
      await library.toggleLike(music);
      expect(library.liked, hasLength(1));
      final restored = await Library.load();
      expect(restored.isLiked(music), isTrue);
      expect(restored.isLiked(video), isTrue);
      await restored.toggleLike(video);
      expect(restored.likedVideos, isEmpty);
      expect(restored.liked, hasLength(1));
    },
  );
  test('legacy liked videos migrate without losing music', () async {
    SharedPreferences.setMockInitialValues({
      'undertune.library.v1':
          '{"liked":[{"url":"song","title":"Song"},{"url":"video","title":"Video","video":true}]}',
    });
    final library = await Library.load();
    expect(library.liked.map((t) => t.url), ['song']);
    expect(library.likedVideos.map((t) => t.url), ['video']);
    final restored = await Library.load();
    expect(restored.liked.map((t) => t.url), ['song']);
    expect(restored.likedVideos.map((t) => t.url), ['video']);
  });
  test(
    'a failed legacy migration preserves the original music record',
    () async {
      const original =
          '{"liked":[{"url":"video","title":"Video","video":true}]}';
      SharedPreferences.setMockInitialValues({
        'undertune.library.v1': original,
      });
      final prefs = await SharedPreferences.getInstance();
      SharedPreferencesStorePlatform.instance = FailedVideoStore();
      final library = await Library.load();
      expect(library.storageError, contains('could not be migrated'));
      expect(prefs.getString('undertune.library.v1'), original);
    },
  );
  test('source ids are scoped to service and entity type', () {
    const other = VideoChannel(
      id: 'UCtest',
      url: 'https://other/channel/UCtest',
      name: 'Other',
      serviceId: 1,
    );
    expect(other.key, isNot(channel.key));
    expect(playlist.key, startsWith('0:playlist:'));
    expect(channel.key, startsWith('0:channel:'));
  });
  test('old tracks and new video metadata round-trip', () {
    final old = Track.fromJson({'url': 'old', 'title': 'Old'});
    expect(old.channelUrl, isEmpty);
    final track = Track.fromJson({
      'url': 'v',
      'title': 'Video',
      'video': true,
      'channelUrl': channel.url,
      'publishedAt': 1000,
      'views': 100,
    });
    final restored = Track.fromJson(track.toJson());
    expect(restored.channelUrl, channel.url);
    expect(restored.publishedAt, 1000);
    expect(restored.views, 100);
    expect(restored.asVideo(false).channelUrl, channel.url);
  });
}

class FailedVideoStore extends InMemorySharedPreferencesStore {
  FailedVideoStore() : super.empty();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}
