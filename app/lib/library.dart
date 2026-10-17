import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'media/extractor.dart';
import 'media/video_catalog.dart';
import 'media/music_collections.dart';

class Playlist {
  Playlist(
    this.id,
    this.name,
    this.tracks, {
    this.coverPath,
    this.themeId,
    this.sourceUrl,
    this.sourceArtwork,
    this.collectionKind,
    this.sourceArtist,
    this.serviceId = 0,
  });
  final String id;
  String name;
  final List<Track> tracks;
  String? coverPath;
  String? themeId;
  final String? sourceUrl, sourceArtwork, collectionKind, sourceArtist;
  final int serviceId;
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'tracks': tracks.map((e) => e.toJson()).toList(),
    if (coverPath != null) 'coverPath': coverPath!,
    if (themeId != null) 'themeId': themeId!,
    if (sourceUrl != null) 'sourceUrl': sourceUrl!,
    if (sourceArtwork != null) 'sourceArtwork': sourceArtwork!,
    if (collectionKind != null) 'collectionKind': collectionKind!,
    if (sourceArtist != null) 'sourceArtist': sourceArtist!,
    'serviceId': serviceId,
  };
}

class Library extends ChangeNotifier {
  Library._(this._prefs);
  final SharedPreferences _prefs;
  String themeId = 'obsidian';
  bool onboardingComplete = false;
  final List<String> genres = [];
  bool sponsorBlock = true;
  String downloadType = 'audio';
  int downloadAudioBitrate = 0, downloadVideoHeight = 0;
  final List<Track> liked = [], history = [], savedTracks = [];
  final List<Track> liveStreams = [];
  final List<Playlist> playlists = [];
  final List<String> searches = [];
  final Set<String> autoDownloadPlaylists = {};
  final List<VideoChannel> followedChannels = [];
  final List<RemoteVideoPlaylist> videoPlaylists = [];
  final List<Track> likedVideos = [];
  String? videoStorageError;
  String? storageError;
  static Future<Library> load() async {
    final prefs = await SharedPreferences.getInstance();
    final library = Library._(prefs);
    final raw = prefs.getString('undertune.library.v1');
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map;
        library.themeId = json['theme'] as String? ?? 'obsidian';
        library.onboardingComplete =
            json['onboardingComplete'] as bool? ?? true;
        library.autoDownloadPlaylists.addAll(
          (json['autoDownloadPlaylists'] as List? ?? []).cast<String>(),
        );
        library.genres.addAll((json['genres'] as List? ?? []).cast<String>());
        library.sponsorBlock = (json['sponsorBlock'] as bool?) ?? true;
        library.downloadType = json['downloadType'] == 'video'
            ? 'video'
            : 'audio';
        final bitrate = (json['downloadAudioBitrate'] as num?)?.toInt() ?? 0;
        final height = (json['downloadVideoHeight'] as num?)?.toInt() ?? 0;
        library.downloadAudioBitrate = {0, 64, 128, 160}.contains(bitrate)
            ? bitrate
            : 0;
        library.downloadVideoHeight = {0, 360, 480, 720, 1080}.contains(height)
            ? height
            : 0;
        library.liked.addAll(
          (json['liked'] as List? ?? []).map((e) => Track.fromJson(e as Map)),
        );
        library.savedTracks.addAll(
          (json['savedTracks'] as List? ?? []).map(
            (e) => Track.fromJson(e as Map).asVideo(false),
          ),
        );
        library.history.addAll(
          (json['history'] as List? ?? []).map((e) => Track.fromJson(e as Map)),
        );
        library.searches.addAll(
          (json['searches'] as List? ?? []).cast<String>(),
        );
        for (final p in json['playlists'] as List? ?? []) {
          library.playlists.add(
            Playlist(
              p['id'] as String,
              p['name'] as String,
              (p['tracks'] as List)
                  .map((e) => Track.fromJson(e as Map))
                  .toList(),
              coverPath: p['coverPath'] as String?,
              themeId: p['themeId'] as String?,
              sourceUrl: p['sourceUrl'] as String?,
              sourceArtwork: p['sourceArtwork'] as String?,
              collectionKind: p['collectionKind'] as String?,
              sourceArtist: p['sourceArtist'] as String?,
              serviceId: (p['serviceId'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      } catch (_) {
        library.storageError =
            'Saved data could not be read. The original data has been preserved.';
      }
    }
    final legacyLive = [
      ...library.liked,
      ...library.savedTracks,
      ...library.history,
      ...library.playlists.expand((p) => p.tracks),
    ].where((t) => t.live).toList();
    try {
      final seen = <String>{};
      library.liveStreams.addAll(
        [
          ...(jsonDecode(prefs.getString('undertune.live.v1') ?? '[]') as List)
              .map((e) => Track.fromJson(e as Map)),
          ...legacyLive,
        ].where((t) => t.live && seen.add(t.key)).map((t) => t.asVideo(true)),
      );
      library.liked.removeWhere((t) => t.live);
      library.savedTracks.removeWhere((t) => t.live);
      library.history.removeWhere((t) => t.live);
      for (final p in library.playlists) {
        p.tracks.removeWhere((t) => t.live);
      }
      if (legacyLive.isNotEmpty && library.storageError == null) {
        await library._save();
      }
    } catch (_) {
      library.storageError =
          'Saved live streams could not be read. The original data has been preserved.';
    }
    var legacyLikesMigrated = false;
    try {
      final rawVideo = prefs.getString('undertune.video-library.v1');
      if (rawVideo != null) {
        final data = jsonDecode(rawVideo) as Map;
        legacyLikesMigrated = data['legacyLikesMigrated'] == true;
        library.likedVideos.addAll(
          (data['liked'] as List? ?? [])
              .map((e) => Track.fromJson(e as Map).asVideo(true))
              .where((t) => !t.live),
        );
        library.followedChannels.addAll(
          (data['channels'] as List? ?? []).map(
            (e) => VideoChannel.fromJson(e as Map),
          ),
        );
        library.videoPlaylists.addAll(
          (data['playlists'] as List? ?? []).map(
            (e) => RemoteVideoPlaylist.fromJson(e as Map),
          ),
        );
      }
    } catch (_) {
      library.videoStorageError =
          'Saved videos could not be read. The original data has been preserved.';
    }
    final legacyVideoLikes = library.liked.where((t) => t.video).toList();
    if (legacyVideoLikes.isNotEmpty) {
      try {
        if (library.videoStorageError != null) {
          throw StateError(library.videoStorageError!);
        }
        // Save the separate copy before removing anything from the music record.
        if (!legacyLikesMigrated) {
          await library._changeVideos(() {
            final keys = library.likedVideos.map((t) => t.key).toSet();
            library.likedVideos.addAll(
              legacyVideoLikes.where((t) => keys.add(t.key)),
            );
          });
        }
        library.liked.removeWhere((t) => t.video);
        await library._save();
      } catch (_) {
        library.storageError =
            'Video likes could not be migrated. The original data has been preserved.';
      }
    }
    return library;
  }

  Future<void> _videoWrites = Future.value();
  bool isFollowing(VideoChannel channel) =>
      followedChannels.any((c) => c.key == channel.key);
  bool hasVideoPlaylist(RemoteVideoPlaylist playlist) =>
      videoPlaylists.any((p) => p.key == playlist.key);
  Future<void> _changeVideos(void Function() change) {
    final result = _videoWrites.then((_) async {
      if (videoStorageError != null) throw StateError(videoStorageError!);
      final oldChannels = [...followedChannels];
      final oldPlaylists = [...videoPlaylists];
      final oldLikes = [...likedVideos];
      change();
      notifyListeners();
      try {
        final saved = await _prefs.setString(
          'undertune.video-library.v1',
          jsonEncode({
            'channels': followedChannels.map((c) => c.toJson()).toList(),
            'playlists': videoPlaylists.map((p) => p.toJson()).toList(),
            'liked': likedVideos.map((t) => t.toJson()).toList(),
            'legacyLikesMigrated': true,
          }),
        );
        if (!saved) throw StateError('Couldn’t save videos. Please try again.');
      } catch (_) {
        followedChannels
          ..clear()
          ..addAll(oldChannels);
        videoPlaylists
          ..clear()
          ..addAll(oldPlaylists);
        likedVideos
          ..clear()
          ..addAll(oldLikes);
        notifyListeners();
        rethrow;
      }
    });
    _videoWrites = result.catchError((Object _) {});
    return result;
  }

  Future<void> setFollowing(VideoChannel channel, bool value) =>
      _changeVideos(() {
        followedChannels.removeWhere((c) => c.key == channel.key);
        if (value) followedChannels.insert(0, channel);
      });
  Future<void> saveVideoPlaylist(RemoteVideoPlaylist playlist) =>
      _changeVideos(() {
        final index = videoPlaylists.indexWhere((p) => p.key == playlist.key);
        if (index < 0) {
          videoPlaylists.insert(0, playlist);
        } else {
          videoPlaylists[index] = playlist;
        }
      });
  Future<void> removeVideoPlaylist(String key) =>
      _changeVideos(() => videoPlaylists.removeWhere((p) => p.key == key));

  Future<void> _save() async {
    if (storageError != null) throw StateError(storageError!);
    final data = jsonEncode({
      'theme': themeId,
      'onboardingComplete': onboardingComplete,
      'genres': genres,
      'sponsorBlock': sponsorBlock,
      'downloadType': downloadType,
      'downloadAudioBitrate': downloadAudioBitrate,
      'downloadVideoHeight': downloadVideoHeight,
      'liked': liked.map((e) => e.toJson()).toList(),
      'savedTracks': savedTracks.map((e) => e.toJson()).toList(),
      'history': history.map((e) => e.toJson()).toList(),
      'searches': searches,
      'playlists': playlists.map((e) => e.toJson()).toList(),
      'autoDownloadPlaylists': autoDownloadPlaylists.toList(),
    });
    if (!await _prefs.setString('undertune.library.v1', data)) {
      throw StateError('Could not save your library.');
    }
    if (!await _prefs.setString(
      'undertune.live.v1',
      jsonEncode(liveStreams.map((t) => t.toJson()).toList()),
    )) {
      throw StateError('Could not save live streams.');
    }
    notifyListeners();
  }

  Future<void> addLive(Track track) async {
    if (!track.live) throw ArgumentError('This stream is not live.');
    if (liveStreams.any((t) => t.key == track.key)) return;
    liveStreams.insert(0, track.asVideo(true));
    await _save();
  }

  Future<void> removeLive(Track track) async {
    liveStreams.removeWhere((t) => t.key == track.key);
    await _save();
  }

  Future<void> checkLegacyLive(Extractor extractor) async {
    final candidates = [
      ...tracks,
      ...history,
    ].where((t) => !t.live && t.duration <= 0);
    final seen = <String>{};
    for (final track in candidates.where((t) => seen.add(t.key)).toList()) {
      try {
        if ((await extractor.resolve(track))['live'] != true) continue;
        liked.removeWhere((t) => t.key == track.key);
        savedTracks.removeWhere((t) => t.key == track.key);
        history.removeWhere((t) => t.key == track.key);
        for (final p in playlists) {
          p.tracks.removeWhere((t) => t.key == track.key);
        }
        if (!liveStreams.any((t) => t.key == track.key)) {
          liveStreams.add(track.asVideo(true, live: true));
        }
        await _save();
      } catch (_) {
        /* Preserve unverified entries and retry on next launch. */
      }
    }
  }

  List<Track> get tracks {
    final seen = <String>{};
    return [
      ...savedTracks,
      ...liked,
      ...playlists.expand((p) => p.tracks),
    ].where((t) => seen.add(t.key)).toList();
  }

  bool isSaved(Track track) => savedTracks.any((e) => e.key == track.key);
  Future<void> saveTrack(Track track) => saveTracks([track]);
  Future<void> saveTracks(Iterable<Track> items) async {
    final input = items.toList();
    if (input.any((t) => t.live)) {
      throw ArgumentError('Add live streams to Live instead.');
    }
    final seen = savedTracks.map((t) => t.key).toSet();
    savedTracks.insertAll(
      0,
      input.where((t) => seen.add(t.key)).map((t) => t.asVideo(false)),
    );
    await _save();
  }

  bool isLiked(Track track) =>
      (track.video ? likedVideos : liked).any((e) => e.key == track.key);
  Future<void> toggleLike(Track track) async {
    if (track.live) throw ArgumentError('Add live streams to Live instead.');
    if (track.video) {
      return _changeVideos(() {
        if (isLiked(track)) {
          likedVideos.removeWhere((t) => t.key == track.key);
        } else {
          likedVideos.insert(0, track.asVideo(true));
        }
      });
    }
    if (isLiked(track)) {
      liked.removeWhere((e) => e.key == track.key);
    } else {
      liked.insert(0, track);
    }
    await _save();
  }

  Future<String> createPlaylist(String name, {String? themeId}) async {
    if (name.trim().isEmpty) throw ArgumentError('Enter a playlist name');
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    playlists.add(Playlist(id, name.trim(), [], themeId: themeId));
    await _save();
    return id;
  }

  Future<void> renamePlaylist(String id, String name) async {
    if (name.trim().isEmpty) throw ArgumentError('Enter a playlist name');
    playlists.firstWhere((p) => p.id == id).name = name.trim();
    await _save();
  }

  Future<void> editPlaylist(
    String id, {
    required String name,
    String? coverPath,
    String? themeId,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Enter a playlist name');
    final playlist = playlists.firstWhere((p) => p.id == id);
    playlist.name = name.trim();
    playlist.coverPath = coverPath;
    playlist.themeId = themeId;
    await _save();
  }

  Future<void> reorderPlaylist(String id, int oldIndex, int newIndex) async {
    final tracks = id == 'liked'
        ? liked
        : playlists.firstWhere((p) => p.id == id).tracks;
    RangeError.checkValidIndex(oldIndex, tracks);
    RangeError.checkValueInInterval(newIndex, 0, tracks.length);
    final track = tracks.removeAt(oldIndex);
    tracks.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, track);
    await _save();
  }

  Future<void> sortPlaylist(String id, String order) async {
    final tracks = id == 'liked'
        ? liked
        : playlists.firstWhere((p) => p.id == id).tracks;
    if (order == 'Reverse order') {
      final reversed = tracks.reversed.toList();
      tracks
        ..clear()
        ..addAll(reversed);
    } else {
      tracks.sort(
        (a, b) => (order == 'Artist A–Z' ? a.artist : a.title)
            .toLowerCase()
            .compareTo(
              (order == 'Artist A–Z' ? b.artist : b.title).toLowerCase(),
            ),
      );
    }
    await _save();
  }

  Future<String> saveMusicCollection(
    MusicCollection source,
    List<Track> tracks,
  ) async {
    final id = source.key;
    if (playlists.any((p) => p.id == id)) return id;
    final seen = <String>{};
    final playlist = Playlist(
      id,
      source.name,
      tracks
          .where((t) => !t.live && seen.add(t.key))
          .map((t) => t.asVideo(false))
          .toList(),
      sourceUrl: source.url,
      sourceArtwork: source.artwork,
      collectionKind: source.kind,
      sourceArtist: source.artist,
      serviceId: source.serviceId,
    );
    playlists.add(playlist);
    try {
      await _save();
    } catch (_) {
      playlists.remove(playlist);
      rethrow;
    }
    return id;
  }

  List<Track> playlistTracks(String id) => id == 'liked'
      ? liked
      : id == 'tracks'
      ? tracks
      : playlists.where((p) => p.id == id).firstOrNull?.tracks ?? [];

  Future<void> setPlaylistAutoDownload(String id, bool enabled) async {
    if (id != 'liked' && id != 'tracks' && !playlists.any((p) => p.id == id)) {
      throw ArgumentError('Playlist no longer exists.');
    }
    final previous = autoDownloadPlaylists.contains(id);
    if (enabled) {
      autoDownloadPlaylists.add(id);
    } else {
      autoDownloadPlaylists.remove(id);
    }
    try {
      await _save();
    } catch (_) {
      if (previous) {
        autoDownloadPlaylists.add(id);
      } else {
        autoDownloadPlaylists.remove(id);
      }
      rethrow;
    }
  }

  Future<void> deletePlaylist(String id) async {
    autoDownloadPlaylists.remove(id);
    playlists.removeWhere((p) => p.id == id);
    await _save();
  }

  Future<void> addToPlaylist(String id, Track track) =>
      addTracksToPlaylist(id, [track]);

  Future<void> addTracksToPlaylist(String id, Iterable<Track> tracks) async {
    final input = tracks.toList();
    if (input.any((t) => t.live)) {
      throw ArgumentError('Add live streams to Live instead.');
    }
    final p = playlists.firstWhere((e) => e.id == id);
    final saved = p.tracks.map((t) => t.key).toSet();
    p.tracks.addAll(input.where((t) => saved.add(t.key)));
    await _save();
  }

  Future<void> removeFromPlaylist(String id, Track track) async {
    playlists
        .firstWhere((e) => e.id == id)
        .tracks
        .removeWhere((e) => e.key == track.key);
    await _save();
  }

  Future<void> played(Track track) async {
    if (track.live) return;
    history.removeWhere((e) => e.key == track.key);
    history.insert(0, track);
    if (history.length > 100) history.removeLast();
    await _save();
  }

  Future<void> searched(String query) async {
    searches.remove(query);
    searches.insert(0, query);
    if (searches.length > 30) searches.removeLast();
    await _save();
  }

  Future<void> setGenres(List<String> values) async {
    genres
      ..clear()
      ..addAll(values.toSet());
    await _save();
  }

  Future<void> setSponsorBlock(bool enabled) async {
    sponsorBlock = enabled;
    await _save();
  }

  Future<void> setDownloadPreferences({
    String? type,
    int? audioBitrate,
    int? videoHeight,
  }) async {
    if (type != null && !{'audio', 'video'}.contains(type)) {
      throw ArgumentError('Invalid download type');
    }
    if (audioBitrate != null && !{0, 64, 128, 160}.contains(audioBitrate)) {
      throw ArgumentError('Invalid audio quality');
    }
    if (videoHeight != null &&
        !{0, 360, 480, 720, 1080}.contains(videoHeight)) {
      throw ArgumentError('Invalid video quality');
    }
    downloadType = type ?? downloadType;
    downloadAudioBitrate = audioBitrate ?? downloadAudioBitrate;
    downloadVideoHeight = videoHeight ?? downloadVideoHeight;
    await _save();
  }

  Future<void> setTheme(String value) async {
    themeId = value;
    await _save();
  }

  Future<void> completeOnboarding() async {
    onboardingComplete = true;
    try {
      await _save();
    } catch (_) {
      onboardingComplete = false;
      notifyListeners();
      rethrow;
    }
  }
}
