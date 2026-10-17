import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/stream_selection.dart';

void main() {
  test(
    'playback gets the highest available audio; download caps choose real sources',
    () {
      final streams = [
        {'url': 'small', 'bitrate': 64, 'extension': 'm4a'},
        {'url': 'best', 'bitrate': 256, 'extension': 'm4a'},
        {'url': 'middle', 'bitrate': 128, 'extension': 'webm'},
      ];
      expect(selectAudio(streams)?['url'], 'best');
      expect(selectAudio(streams, maxBitrate: 128)?['url'], 'middle');
      expect(selectAudio(streams, maxBitrate: 32)?['url'], 'small');
      expect(
        selectAudio(streams, maxBitrate: 128, mp4Only: true)?['url'],
        'small',
      );
      final video = selectDownloadVideo({
        'video': [
          {'url': 'muxed', 'extension': 'mp4', 'quality': '360p'},
        ],
        'videoOnly': [
          {
            'url': '720',
            'extension': 'mp4',
            'codec': 'avc1',
            'quality': '720p60',
          },
          {
            'url': '1080',
            'extension': 'mp4',
            'codec': 'avc1',
            'quality': '1080p',
          },
          {'url': 'webm', 'extension': 'webm', 'quality': '2160p'},
        ],
      }, maxHeight: 720);
      expect(video?['url'], '720');
      expect(video?['videoOnly'], isTrue);
    },
  );
  test(
    'download type and quality persist independently of playback preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      expect(library.downloadType, 'audio');
      expect(library.downloadAudioBitrate, 0);
      await library.setDownloadPreferences(
        type: 'video',
        audioBitrate: 128,
        videoHeight: 720,
      );
      final restored = await Library.load();
      expect(restored.downloadType, 'video');
      expect(restored.downloadAudioBitrate, 128);
      expect(restored.downloadVideoHeight, 720);
    },
  );
}
