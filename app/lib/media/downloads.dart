import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'extractor.dart';
import 'stream_selection.dart';
import '../library.dart';

class DownloadEntry {
  DownloadEntry(Map<dynamic, dynamic> json)
    : id = json['id'] as int,
      track = Track.fromJson(json['track'] as Map),
      status = json['status'] as String,
      bytes = json['bytes'] as int,
      total = json['total'] as int,
      localUrl = json['localUrl'] as String?,
      kind = json['kind'] as String? ?? 'audio',
      quality = json['quality'] as String? ?? '';
  final int id, bytes, total;
  final Track track;
  final String status;
  final String? localUrl;
  final String kind, quality;
}

class Downloads extends ChangeNotifier {
  static const _channel = MethodChannel('undertune/downloads');
  List<DownloadEntry> entries = [];
  String? error;
  bool loading = false;
  // Presentation state only; persisted downloads and bridge operations are unchanged.
  bool hasLoaded = false;
  Future<void>? _refreshing;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> refresh() => _refreshing ??= _readEntries().whenComplete(() {
    _refreshing = null;
  });

  Future<void> _readEntries() async {
    loading = true;
    try {
      entries = (await _channel.invokeListMethod<dynamic>('list') ?? [])
          .map((e) => DownloadEntry(e as Map))
          .toList();
      error = null;
    } catch (e) {
      error = '$e';
    }
    loading = false;
    hasLoaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> enqueue(
    Track track,
    Extractor extractor, {
    Library? preferences,
  }) => _enqueue(track, extractor, preferences: preferences);

  Future<void> enqueueAudio(
    Track track,
    Extractor extractor, {
    Library? preferences,
    bool Function()? shouldEnqueue,
  }) => _enqueue(
    track.asVideo(false),
    extractor,
    preferences: preferences,
    audioOnly: true,
    shouldEnqueue: shouldEnqueue,
  );

  Future<void> _enqueue(
    Track track,
    Extractor extractor, {
    Library? preferences,
    bool audioOnly = false,
    bool Function()? shouldEnqueue,
  }) async {
    if (shouldEnqueue != null && !shouldEnqueue()) return;
    if (track.live) throw StateError('Live streams cannot be downloaded.');
    final video = !audioOnly && preferences?.downloadType == 'video';
    final resolved = await extractor.resolve(track.asVideo(video));
    if (shouldEnqueue != null && !shouldEnqueue()) return;
    if (resolved['live'] == true) {
      throw StateError('Live streams cannot be downloaded.');
    }
    final selectedVideo = video
        ? selectDownloadVideo(
            resolved,
            maxHeight: preferences?.downloadVideoHeight ?? 0,
          )
        : null;
    if (video && selectedVideo == null) {
      throw StateError('No compatible MP4 video is available for download.');
    }
    final separate = selectedVideo?['videoOnly'] == true;
    final audio = !video || separate
        ? selectAudio(
            (resolved['audio'] as List? ?? [])
                .where((s) => s['hls'] != true)
                .toList(),
            maxBitrate: preferences?.downloadAudioBitrate ?? 0,
            mp4Only: separate,
          )
        : null;
    if ((!video || separate) && audio == null) {
      throw StateError(
        'No compatible downloadable audio is available for this item.',
      );
    }
    final source = video ? selectedVideo! : audio!;
    final bitrate = (audio?['bitrate'] as num?)?.toInt() ?? 0;
    final quality = video
        ? source['quality'] as String? ?? 'Video'
        : bitrate > 0
        ? '$bitrate kbps'
        : 'Best available';
    await _channel.invokeMethod<void>('enqueue', {
      'streamUrl': source['url'],
      'extension': source['extension'],
      if (separate) 'audioUrl': audio!['url'],
      'kind': video ? 'video' : 'audio',
      'quality': quality,
      'track': track.asVideo(video).toJson(),
    });
    await refresh();
  }

  Future<void> remove(int id) async {
    await _channel.invokeMethod<void>('remove', {'id': id});
    await refresh();
  }

  String? localFor(Track track) => entries
      .where(
        (e) =>
            e.track.key == track.key &&
            e.kind == 'audio' &&
            e.status == 'complete',
      )
      .firstOrNull
      ?.localUrl;
  String? videoFor(Track track) => entries
      .where(
        (e) =>
            e.track.key == track.key &&
            e.kind == 'video' &&
            e.status == 'complete',
      )
      .firstOrNull
      ?.localUrl;
}
