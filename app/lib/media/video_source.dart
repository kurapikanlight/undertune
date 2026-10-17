import 'dart:convert';
import 'dart:io';
import 'package:video_player/video_player.dart';

VideoPlayerController videoControllerFrom(
  Map<String, dynamic> info, {
  bool silent = false,
  bool background = false,
}) {
  final local = info['localUrl'] as String?;
  if (local != null) {
    return VideoPlayerController.file(
      File.fromUri(Uri.parse(local)),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: silent,
        allowBackgroundPlayback: background,
      ),
    );
  }
  final streams = info['video'] as List? ?? [];
  final dash = info['dash'] as String?;
  final hls = info['hls'] as String?;
  final options = VideoPlayerOptions(
    mixWithOthers: silent,
    allowBackgroundPlayback: background,
  );
  if (streams.isEmpty && dash != null && dash.isNotEmpty) {
    return VideoPlayerController.networkUrl(
      Uri.dataFromString(
        dash,
        mimeType: 'application/dash+xml',
        encoding: utf8,
      ),
      formatHint: VideoFormat.dash,
      videoPlayerOptions: options,
    );
  }
  final url = streams.isNotEmpty ? streams.first['url'] as String : hls;
  if (url == null || url.isEmpty) throw StateError('Video unavailable');
  return VideoPlayerController.networkUrl(
    Uri.parse(url),
    videoPlayerOptions: options,
  );
}
