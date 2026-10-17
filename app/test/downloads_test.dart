import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/downloads.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/screens/downloads.dart';

class Sources extends Extractor {
  @override
  Future<Map<String, dynamic>> resolve(Track track) async => {
    'audio': [
      {'url': 'https://source/audio', 'extension': 'm4a', 'bitrate': 128},
      {'url': 'https://source/best', 'extension': 'webm', 'bitrate': 256},
      {
        'url': 'https://source/manifest',
        'extension': 'm4a',
        'bitrate': 320,
        'hls': true,
      },
    ],
    'videoOnly': [
      {
        'url': 'https://source/video',
        'extension': 'mp4',
        'quality': '720p',
        'codec': 'avc1',
      },
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('undertune/downloads');
  final calls = <MethodCall>[];
  List<Map<String, Object>> records = [];
  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    records = [
      {
        'id': 1,
        'track': const Track(
          url: 'item',
          title: 'Song',
          artist: 'Artist',
        ).toJson(),
        'status': 'complete',
        'bytes': 100,
        'total': 100,
        'localUrl': 'file:///audio',
      },
      {
        'id': 2,
        'track': const Track(
          url: 'item',
          title: 'Song',
          artist: 'Artist',
          video: true,
        ).toJson(),
        'kind': 'video',
        'status': 'complete',
        'bytes': 100,
        'total': 100,
        'localUrl': 'file:///video',
      },
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'list') return records;
          if (call.method == 'remove') {
            records.removeWhere(
              (r) => r['id'] == (call.arguments as Map)['id'],
            );
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  testWidgets('download tabs isolate audio and video playback and removal', (
    tester,
  ) async {
    final library = await Library.load();
    final downloads = Downloads();
    DownloadEntry? played;
    await tester.pumpWidget(
      MaterialApp(
        home: DownloadsScreen(
          downloads: downloads,
          library: library,
          onPlay: (entry) => played = entry,
        ),
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(Tab, 'Audio'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Video'), findsOneWidget);
    expect(find.text('Song'), findsOneWidget);
    await tester.tap(find.text('Song'));
    expect(played?.localUrl, 'file:///audio');
    await tester.tap(find.widgetWithText(Tab, 'Video'));
    await tester.pumpAndSettle();
    expect(find.text('Song'), findsOneWidget);
    await tester.tap(find.text('Song'));
    expect(played?.localUrl, 'file:///video');
    await tester.tap(find.byTooltip('Remove download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(
      (calls.lastWhere((c) => c.method == 'remove').arguments as Map)['id'],
      2,
    );
    expect(find.text('No video downloads yet.'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Audio'));
    await tester.pumpAndSettle();
    expect(find.text('Song'), findsOneWidget);
    await tester.tap(find.text('Song'));
    expect(played?.localUrl, 'file:///audio');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    downloads.dispose();
  });
  test(
    'download bridge keeps audio/video separate, pairs AAC, and reads old audio records',
    () async {
      final library = await Library.load();
      final downloads = Downloads();
      const track = Track(url: 'item', title: 'Song', artist: 'Artist');
      await downloads.enqueue(track, Sources(), preferences: library);
      expect(
        (calls.first.arguments as Map)['streamUrl'],
        'https://source/best',
      );
      await library.setDownloadPreferences(type: 'video', videoHeight: 720);
      await downloads.enqueue(track, Sources(), preferences: library);
      final request =
          calls.lastWhere((c) => c.method == 'enqueue').arguments as Map;
      expect(request['streamUrl'], 'https://source/video');
      expect(request['audioUrl'], 'https://source/audio');
      expect(request['quality'], '720p');
      expect(downloads.localFor(track), 'file:///audio');
      expect(downloads.videoFor(track), 'file:///video');
      downloads.dispose();
    },
  );
  testWidgets('download settings persist a new type and fit a narrow display', (
    tester,
  ) async {
    final library = await Library.load();
    final downloads = Downloads();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: DownloadsScreen(
          downloads: downloads,
          library: library,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Download settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video').last);
    await tester.pumpAndSettle();
    expect((await Library.load()).downloadType, 'video');
    expect(find.text('Video quality'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    downloads.dispose();
  });
}
