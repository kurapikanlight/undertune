import 'package:flutter/services.dart';
import 'extractor.dart';

class VideoChannel {
  const VideoChannel({
    required this.id,
    required this.url,
    required this.name,
    this.serviceId = 0,
    this.artwork = '',
    this.banner = '',
    this.description = '',
    this.subscribers = -1,
    this.tabs = const [],
    this.sorts = const [],
  });
  final String id, url, name, artwork, banner, description;
  final int serviceId, subscribers;
  final List<String> tabs, sorts;
  String get key => '$serviceId:channel:$id';
  factory VideoChannel.fromJson(Map json) => VideoChannel(
    id: json['id'] as String,
    url: json['url'] as String,
    name: json['name'] as String? ?? 'Channel',
    serviceId: (json['serviceId'] as num?)?.toInt() ?? 0,
    artwork: json['artwork'] as String? ?? '',
    banner: json['banner'] as String? ?? '',
    description: json['description'] as String? ?? '',
    subscribers: (json['subscribers'] as num?)?.toInt() ?? -1,
    tabs: (json['tabs'] as List? ?? []).cast<String>(),
    sorts: (json['sorts'] as List? ?? []).cast<String>(),
  );
  Map<String, Object> toJson() => {
    'id': id,
    'url': url,
    'name': name,
    'serviceId': serviceId,
    'artwork': artwork,
    'banner': banner,
    'description': description,
    'subscribers': subscribers,
    'tabs': tabs,
    'sorts': sorts,
  };
}

class RemoteVideoPlaylist {
  const RemoteVideoPlaylist({
    required this.id,
    required this.url,
    required this.name,
    this.serviceId = 0,
    this.artwork = '',
    this.artist = '',
    this.count = -1,
  });
  final String id, url, name, artwork, artist;
  final int serviceId, count;
  String get key => '$serviceId:playlist:$id';
  factory RemoteVideoPlaylist.fromJson(Map json) => RemoteVideoPlaylist(
    id: json['id'] as String,
    url: json['url'] as String,
    name: json['name'] as String? ?? 'Video playlist',
    serviceId: (json['serviceId'] as num?)?.toInt() ?? 0,
    artwork: json['artwork'] as String? ?? '',
    artist: json['artist'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? -1,
  );
  Map<String, Object> toJson() => {
    'id': id,
    'url': url,
    'name': name,
    'serviceId': serviceId,
    'artwork': artwork,
    'artist': artist,
    'count': count,
  };
}

class VideoCatalogPage {
  const VideoCatalogPage({
    this.videos = const [],
    this.channels = const [],
    this.playlists = const [],
    this.nextPage,
    this.playlist,
  });
  final List<Track> videos;
  final List<VideoChannel> channels;
  final List<RemoteVideoPlaylist> playlists;
  final String? nextPage;
  final RemoteVideoPlaylist? playlist;
  factory VideoCatalogPage.fromJson(Map json) => VideoCatalogPage(
    videos: (json['items'] as List? ?? [])
        .map((e) => Track.fromJson(e as Map).asVideo(true))
        .toList(),
    channels: (json['channels'] as List? ?? [])
        .map((e) => VideoChannel.fromJson(e as Map))
        .toList(),
    playlists: (json['playlists'] as List? ?? [])
        .map((e) => RemoteVideoPlaylist.fromJson(e as Map))
        .toList(),
    nextPage: json['nextPage'] as String?,
    playlist: json['playlist'] is Map
        ? RemoteVideoPlaylist.fromJson(json['playlist'] as Map)
        : null,
  );
}

/// First pages only; shared by discovery and details. No theme dependency or
/// background polling. Failed futures are never cached; in-flight calls coalesce.
class VideoCatalog {
  VideoCatalog({DateTime Function()? now}) : _now = now ?? DateTime.now;
  static const _channel = MethodChannel('undertune/extractor');
  final DateTime Function() _now;
  final _cache = <String, ({DateTime time, Map data})>{};
  final _pending = <String, Future<Map>>{};
  int _rotation = 0;
  static const cacheLifetime = Duration(minutes: 10);
  Future<Map> _request(
    String method,
    Map<String, Object?> args, {
    bool refresh = false,
  }) {
    final key = '$method:$args';
    final cached = _cache[key];
    if (!refresh &&
        cached != null &&
        _now().difference(cached.time) < cacheLifetime) {
      return Future.value(cached.data);
    }
    if (_pending.containsKey(key)) return _pending[key]!;
    final request = _channel
        .invokeMapMethod<String, dynamic>(method, args)
        .then<Map>((data) {
          if (data == null) {
            throw StateError('No response from the video service');
          }
          if (args['page'] == null) {
            _cache.remove(key);
            _cache[key] = (time: _now(), data: data);
            if (_cache.length > 48) _cache.remove(_cache.keys.first);
          }
          return data;
        })
        .catchError((Object error, StackTrace stack) {
          if (videoPageExpired(error)) {
            _cache.remove('$method:${{...args, 'page': null}}');
          }
          Error.throwWithStackTrace(error, stack);
        })
        .whenComplete(() {
          _pending.remove(key);
        });
    _pending[key] = request;
    return request;
  }

  Future<VideoChannel> channel(
    VideoChannel source, {
    bool refresh = false,
  }) async => VideoChannel.fromJson(
    await _request('videoChannel', {
      'url': source.url,
      'serviceId': source.serviceId,
    }, refresh: refresh),
  );
  Future<VideoCatalogPage> search(
    String query,
    String kind, {
    String? page,
    bool refresh = false,
  }) async {
    if (!{'Channels', 'Playlists'}.contains(kind)) {
      throw ArgumentError('Unknown video search type');
    }
    return VideoCatalogPage.fromJson(
      await _request(kind == 'Channels' ? 'videoChannels' : 'videoPlaylists', {
        'query': query,
        'page': page,
        'serviceId': 0,
      }, refresh: refresh),
    );
  }

  Future<VideoCatalogPage> channelItems(
    VideoChannel source, {
    String tab = 'videos',
    String sort = 'latest',
    String? page,
    bool refresh = false,
  }) async => VideoCatalogPage.fromJson(
    await _request('videoChannelItems', {
      'url': source.url,
      'serviceId': source.serviceId,
      'tab': tab,
      'sort': sort,
      'page': page,
    }, refresh: refresh),
  );
  Future<VideoCatalogPage> playlist(
    RemoteVideoPlaylist source, {
    String? page,
    bool refresh = false,
  }) async => VideoCatalogPage.fromJson(
    await _request('videoPlaylist', {
      'url': source.url,
      'serviceId': source.serviceId,
      'page': page,
    }, refresh: refresh),
  );

  /// At most three first pages per refresh; rotate for larger follow lists.
  /// Requests run sequentially so leaving a screen stops further network work.
  Future<({List<Track> videos, int failures})> followedVideos(
    List<VideoChannel> followed, {
    required bool Function() active,
  }) async {
    if (followed.isEmpty) return (videos: <Track>[], failures: 0);
    final sources = List.generate(
      followed.length.clamp(0, 3),
      (i) => followed[(_rotation + i) % followed.length],
    );
    _rotation = (_rotation + sources.length) % followed.length;
    final videos = <Track>[];
    var failures = 0;
    for (final source in sources) {
      if (!active()) break;
      try {
        videos.addAll(
          (await channelItems(source)).videos.where((t) => !t.live).take(8),
        );
      } catch (_) {
        failures++;
      }
    }
    return (videos: videos, failures: failures);
  }
}

List<Track> blendVideoSuggestions(
  List<Track> discovery,
  List<Track> followed,
  Set<String> watched,
) {
  if (followed.isEmpty) return discovery;
  final recent = [...followed]
    ..sort((a, b) {
      final seen = (watched.contains(a.key) ? 1 : 0).compareTo(
        watched.contains(b.key) ? 1 : 0,
      );
      return seen != 0 ? seen : b.publishedAt.compareTo(a.publishedAt);
    });
  final result = <Track>[], seen = <String>{};
  void add(Track track) {
    if (seen.add(track.key)) result.add(track.asVideo(true));
  }

  var cursor = 0;
  for (var i = 0; i < discovery.length; i++) {
    if (i % 3 == 0 && cursor < recent.length) add(recent[cursor++]);
    add(discovery[i]);
  }
  while (cursor < recent.length) {
    add(recent[cursor++]);
  }
  return result;
}

bool videoPageExpired(Object error) =>
    error is PlatformException &&
    (error.message ?? '').toLowerCase().contains('expired');
