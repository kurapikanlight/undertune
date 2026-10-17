import 'package:flutter/services.dart';

String mediaTime(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds ~/ 60) % 60;
  final tail = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$tail'
      : '$minutes:$tail';
}

class Track {
  const Track({
    required this.url,
    required this.title,
    required this.artist,
    this.artwork = '',
    this.duration = 0,
    this.serviceId = 0,
    this.video = false,
    this.live = false,
    this.channelUrl = '',
    this.channelArtwork = '',
    this.publishedAt = 0,
    this.views = -1,
  });
  final String url, title, artist, artwork, channelUrl, channelArtwork;
  final int publishedAt, views;
  final int duration, serviceId;
  final bool video, live;
  String get key => '$serviceId:$url';
  Track asVideo(bool value, {bool? live}) => Track(
    url: url,
    title: title,
    artist: artist,
    artwork: artwork,
    duration: duration,
    serviceId: serviceId,
    video: value,
    live: live ?? this.live,
    channelUrl: channelUrl,
    channelArtwork: channelArtwork,
    publishedAt: publishedAt,
    views: views,
  );
  factory Track.fromJson(Map<dynamic, dynamic> json) => Track(
    url: json['url'] as String,
    title: json['title'] as String? ?? 'Untitled',
    artist: json['artist'] as String? ?? '',
    artwork: json['artwork'] as String? ?? '',
    duration: (json['duration'] as num?)?.toInt() ?? 0,
    serviceId: (json['serviceId'] as num?)?.toInt() ?? 0,
    video: json['video'] == true,
    channelUrl: json['channelUrl'] as String? ?? '',
    channelArtwork: json['channelArtwork'] as String? ?? '',
    publishedAt: (json['publishedAt'] as num?)?.toInt() ?? 0,
    views: (json['views'] as num?)?.toInt() ?? -1,
    live:
        json['live'] == true ||
        (json['live'] == null && ((json['duration'] as num?) ?? 0) < 0),
  );
  Map<String, Object> toJson() => {
    'url': url,
    'title': title,
    'artist': artist,
    'artwork': artwork,
    'duration': duration,
    'serviceId': serviceId,
    'video': video,
    'live': live,
    if (channelUrl.isNotEmpty) 'channelUrl': channelUrl,
    if (channelArtwork.isNotEmpty) 'channelArtwork': channelArtwork,
    if (publishedAt > 0) 'publishedAt': publishedAt,
    if (views >= 0) 'views': views,
  };
}

class SearchPage {
  SearchPage(this.tracks, this.nextPage);
  final List<Track> tracks;
  final String? nextPage;
  factory SearchPage.fromJson(Map<dynamic, dynamic> json) => SearchPage(
    (json['items'] as List).map((e) => Track.fromJson(e as Map)).toList(),
    json['nextPage'] as String?,
  );
}

class Extractor {
  static const channel = MethodChannel('undertune/extractor');
  Future<SearchPage> search(String query, {String? page}) async =>
      SearchPage.fromJson(
        (await channel.invokeMapMethod<String, dynamic>('search', {
          'query': query,
          'page': page,
        }))!,
      );
  Future<List<String>> suggestions(String query) async =>
      (await channel.invokeListMethod<String>('suggestions', {
        'query': query,
      })) ??
      [];
  Future<Map<String, dynamic>> resolve(Track track) async =>
      Map<String, dynamic>.from(
        (await channel.invokeMapMethod('resolve', {
          'url': track.url,
          'serviceId': track.serviceId,
          'video': track.video,
        }))!,
      );
}
