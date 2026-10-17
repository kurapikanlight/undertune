import 'package:flutter/services.dart';
import 'extractor.dart';

class MusicCollection {
  const MusicCollection({
    required this.id,
    required this.url,
    required this.name,
    this.artist = '',
    this.artwork = '',
    this.serviceId = 0,
    this.kind = 'playlist',
    this.count = -1,
  });
  final String id, url, name, artist, artwork, kind;
  final int serviceId, count;
  String get key => 'music:$serviceId:$id';
  factory MusicCollection.fromJson(Map json, {String kind = 'playlist'}) {
    var artwork = json['artwork'] as String? ?? '';
    final uri = Uri.tryParse(artwork);
    if (uri?.host.endsWith('googleusercontent.com') == true) {
      artwork = artwork.replaceFirst(RegExp(r'=w\d+-h\d+'), '=w600-h600');
    }
    return MusicCollection(
      id: json['id'] as String,
      url: json['url'] as String,
      name: json['name'] as String? ?? 'Playlist',
      artist: json['artist'] as String? ?? '',
      artwork: artwork,
      serviceId: (json['serviceId'] as num?)?.toInt() ?? 0,
      kind: kind,
      count: (json['count'] as num?)?.toInt() ?? -1,
    );
  }
}

class MusicCollectionPage {
  const MusicCollectionPage({
    this.collections = const [],
    this.tracks = const [],
    this.nextPage,
  });
  final List<MusicCollection> collections;
  final List<Track> tracks;
  final String? nextPage;
  factory MusicCollectionPage.fromJson(Map json, {String kind = 'playlist'}) =>
      MusicCollectionPage(
        collections: (json['playlists'] as List? ?? [])
            .map((e) => MusicCollection.fromJson(e as Map, kind: kind))
            .toList(),
        tracks: (json['items'] as List? ?? [])
            .map((e) => Track.fromJson(e as Map).asVideo(false))
            .where((t) => !t.live)
            .toList(),
        nextPage: json['nextPage'] as String?,
      );
}

class MusicCatalog {
  static const _channel = MethodChannel('undertune/extractor');
  Future<MusicCollectionPage> search(
    String query, {
    String kind = 'album',
    String? page,
  }) async => MusicCollectionPage.fromJson(
    (await _channel.invokeMapMethod(
      kind == 'album' ? 'musicAlbums' : 'musicPlaylists',
      {'query': query, 'serviceId': 0, 'page': page},
    ))!,
    kind: kind,
  );
  Future<MusicCollectionPage> collection(
    MusicCollection source, {
    String? page,
  }) async => MusicCollectionPage.fromJson(
    (await _channel.invokeMapMethod('musicPlaylist', {
      'url': source.url,
      'serviceId': source.serviceId,
      'page': page,
    }))!,
    kind: source.kind,
  );
}
