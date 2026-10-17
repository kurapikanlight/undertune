import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/video_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('undertune/extractor');
  const source = VideoChannel(
    id: 'UC1',
    url: 'https://www.youtube.com/channel/UC1',
    name: 'One',
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, null),
  );
  test(
    'first pages coalesce, cache, expire, and preserve server sort and tokens',
    () async {
      var calls = 0;
      var now = DateTime(2026);
      final requests = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, (call) async {
            calls++;
            requests.add(call);
            return {
              'items': [
                {'url': 'server-$calls', 'title': 'Server result'},
              ],
              'nextPage': 'continuation',
            };
          });
      final catalog = VideoCatalog(now: () => now);
      final both = await Future.wait([
        catalog.channelItems(source),
        catalog.channelItems(source),
      ]);
      expect(calls, 1);
      expect(both.first.videos.first.video, isTrue);
      await catalog.channelItems(source);
      expect(calls, 1);
      await catalog.channelItems(source, sort: 'popular');
      expect(requests.last.arguments['sort'], 'popular');
      await catalog.channelItems(source, sort: 'popular', page: 'continuation');
      expect(requests.last.arguments['page'], 'continuation');
      expect(calls, 3);
      now = now.add(const Duration(minutes: 11));
      await catalog.channelItems(source);
      expect(calls, 4);
    },
  );
  test('follow fetches are capped, rotate, and stop after leaving', () async {
    final calls = <String>[];
    var active = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          calls.add(call.arguments['url'] as String);
          return {'items': []};
        });
    final catalog = VideoCatalog();
    final sources = List.generate(
      8,
      (i) => VideoChannel(
        id: 'UC$i',
        url: 'https://youtube.com/channel/UC$i',
        name: '$i',
      ),
    );
    await catalog.followedVideos(sources, active: () => active);
    expect(calls, hasLength(3));
    await catalog.followedVideos(sources, active: () => active);
    expect(calls.toSet(), hasLength(6));
    active = false;
    await catalog.followedVideos(sources, active: () => active);
    expect(calls, hasLength(6));
  });
  test(
    'failed first pages can retry and never become cached empty results',
    () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, (call) async {
            if (++calls == 1) {
              throw PlatformException(code: 'EXTRACTION_FAILED');
            }
            return {'items': []};
          });
      final catalog = VideoCatalog();
      await expectLater(
        catalog.channelItems(source),
        throwsA(isA<PlatformException>()),
      );
      expect((await catalog.channelItems(source)).videos, isEmpty);
      expect(calls, 2);
    },
  );
  test(
    'expired continuations invalidate the first page so Retry can recover',
    () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, (call) async {
            calls++;
            if (call.arguments['page'] != null) {
              throw PlatformException(
                code: 'EXTRACTION_FAILED',
                message: 'This list expired. Refresh it to continue.',
              );
            }
            return {'items': [], 'nextPage': 'token'};
          });
      final catalog = VideoCatalog();
      await catalog.channelItems(source);
      await expectLater(
        catalog.channelItems(source, page: 'token'),
        throwsA(predicate(videoPageExpired)),
      );
      await catalog.channelItems(source);
      expect(calls, 3);
    },
  );
  test(
    'recommendations blend discovery with unwatched recent uploads, without duplicates',
    () {
      Track video(String id, int date) => Track(
        url: id,
        title: id,
        artist: 'A',
        video: true,
        publishedAt: date,
      );
      final existing = [video('d1', 0), video('duplicate', 0), video('d2', 0)];
      final followed = [
        video('watched', 100),
        video('older', 10),
        video('recent', 20),
        video('duplicate', 0),
      ];
      final result = blendVideoSuggestions(existing, followed, {'0:watched'});
      expect(result.first.url, 'recent');
      expect(result.map((v) => v.url).toSet(), hasLength(result.length));
      expect(
        result.map((v) => v.url),
        containsAll(['d1', 'd2', 'older', 'watched']),
      );
      expect(blendVideoSuggestions(existing, [], {}), same(existing));
    },
  );
}
