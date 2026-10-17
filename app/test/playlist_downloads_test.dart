import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:undertune/widgets/playlist_download_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/downloads.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/playlist_downloads.dart';

const first = Track(url: 'first', title: 'First', artist: 'A');
const second = Track(url: 'second', title: 'Second', artist: 'A');

class AudioSource extends Extractor {
  final requested = <Track>[];
  Completer<Map<String, dynamic>>? pending;
  final fail = <String>{};
  @override
  Future<Map<String, dynamic>> resolve(Track track) async {
    requested.add(track);
    if (pending != null) return pending!.future;
    if (fail.contains(track.url)) throw StateError('Unavailable');
    return {
      'audio': [
        {
          'url': 'https://media.test/${track.url}',
          'extension': 'opus',
          'bitrate': 160,
          'hls': false,
        },
      ],
    };
  }
}

Future<void> settled(PlaylistDownloads controller) async {
  for (var i = 0; i < 100 && controller.busy; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(controller.busy, isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('undertune/downloads');
  late List<Map<String, dynamic>> entries;
  late List<String> enqueued;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    entries = [];
    enqueued = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'list') return entries;
          if (call.method == 'remove') {
            entries.removeWhere((e) => e['id'] == call.arguments['id']);
            return null;
          }
          if (call.method == 'enqueue') {
            final args = call.arguments as Map;
            expect(args['kind'], 'audio');
            final track = args['track'] as Map;
            enqueued.add(track['url'] as String);
            entries.add({
              'id': entries.length + 1,
              'track': track,
              'kind': 'audio',
              'status': 'complete',
              'bytes': 1,
              'total': 1,
              'localUrl': 'file:///audio/${track['url']}',
            });
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, null),
  );
  test(
    'download all persists auto-download and picks up later additions from every route',
    () async {
      final library = await Library.load();
      final id = await library.createPlaylist('Offline');
      await library.addToPlaylist(id, first);
      await library.setDownloadPreferences(type: 'video');
      final downloads = Downloads(), source = AudioSource();
      final controller = PlaylistDownloads(library, downloads, source);
      addTearDown(() {
        controller.dispose();
        downloads.dispose();
      });
      expect(enqueued, isEmpty);
      await controller.downloadAll(id);
      await settled(controller);
      expect(enqueued, ['first']);
      expect(source.requested.every((t) => !t.video), isTrue);
      expect((await Library.load()).autoDownloadPlaylists, contains(id));
      await library.addToPlaylist(id, second);
      await settled(controller);
      expect(enqueued, ['first', 'second']);
      await library.setTheme('afterglow');
      await settled(controller);
      expect(enqueued, ['first', 'second']);
      await controller.setAutomatic(id, false);
      await library.addToPlaylist(
        id,
        const Track(url: 'third', title: 'Third', artist: 'A'),
      );
      await settled(controller);
      expect(enqueued, ['first', 'second']);
      expect(downloads.entries, hasLength(2));
    },
  );
  test(
    'existing completed and queued audio is skipped and shared songs download once',
    () async {
      final library = await Library.load();
      final a = await library.createPlaylist('A'),
          b = await library.createPlaylist('B');
      await library.addTracksToPlaylist(a, [first, second]);
      await library.addTracksToPlaylist(b, [first, second]);
      entries.add({
        'id': 1,
        'track': first.toJson(),
        'kind': 'audio',
        'status': 'downloading',
        'bytes': 0,
        'total': 1,
      });
      final downloads = Downloads(), source = AudioSource();
      final controller = PlaylistDownloads(library, downloads, source);
      addTearDown(() {
        controller.dispose();
        downloads.dispose();
      });
      await controller.downloadAll(a);
      await controller.downloadAll(b);
      await settled(controller);
      expect(enqueued, ['second']);
      expect(source.requested.map((t) => t.url), ['second']);
    },
  );
  test(
    'failures do not block remaining songs or retry on unrelated changes',
    () async {
      final library = await Library.load();
      final id = await library.createPlaylist('A');
      await library.addTracksToPlaylist(id, [first, second]);
      final downloads = Downloads(), source = AudioSource()..fail.add('first');
      final controller = PlaylistDownloads(library, downloads, source);
      addTearDown(() {
        controller.dispose();
        downloads.dispose();
      });
      await controller.downloadAll(id);
      await settled(controller);
      expect(enqueued, ['second']);
      expect(controller.failedCount(id), 1);
      await library.setTheme('daydream');
      await settled(controller);
      expect(source.requested, hasLength(2));
      source.fail.clear();
      await controller.downloadAll(id);
      await settled(controller);
      expect(enqueued, ['second', 'first']);
      expect(controller.failedCount(id), 0);
    },
  );
  test(
    'disabling during resolution prevents enqueue and keeps saved files',
    () async {
      final library = await Library.load();
      final id = await library.createPlaylist('A');
      await library.addToPlaylist(id, first);
      final downloads = Downloads(),
          source = AudioSource()..pending = Completer<Map<String, dynamic>>();
      final controller = PlaylistDownloads(library, downloads, source);
      addTearDown(() {
        controller.dispose();
        downloads.dispose();
      });
      await controller.downloadAll(id);
      for (var i = 0; i < 20 && source.requested.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await controller.setAutomatic(id, false);
      source.pending!.complete({
        'audio': [
          {
            'url': 'https://media.test/first',
            'extension': 'opus',
            'bitrate': 160,
          },
        ],
      });
      await settled(controller);
      expect(enqueued, isEmpty);
    },
  );
  test(
    'Liked auto-download ignores video likes and resumes missing songs after restart',
    () async {
      final library = await Library.load();
      await library.toggleLike(first);
      final downloads = Downloads(), source = AudioSource();
      var controller = PlaylistDownloads(library, downloads, source);
      await controller.setAutomatic('liked', true);
      await settled(controller);
      await library.toggleLike(second.asVideo(true));
      await settled(controller);
      expect(enqueued, ['first']);
      controller.dispose();
      await library.toggleLike(second);
      final restored = await Library.load();
      controller = PlaylistDownloads(restored, downloads, source);
      await settled(controller);
      expect(enqueued, ['first', 'second']);
      expect(restored.likedVideos, hasLength(1));
      controller.dispose();
      downloads.dispose();
    },
  );
  test('disposing during resolution prevents a late native enqueue', () async {
    final library = await Library.load();
    final id = await library.createPlaylist('A');
    await library.addToPlaylist(id, first);
    final downloads = Downloads(),
        source = AudioSource()..pending = Completer<Map<String, dynamic>>();
    final controller = PlaylistDownloads(library, downloads, source);
    await controller.downloadAll(id);
    for (var i = 0; i < 20 && source.requested.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    controller.dispose();
    source.pending!.complete({
      'audio': [
        {
          'url': 'https://media.test/first',
          'extension': 'opus',
          'bitrate': 160,
        },
      ],
    });
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(enqueued, isEmpty);
    downloads.dispose();
  });
  testWidgets(
    'one download icon enables automatic additions and toggles off without deleting files',
    (tester) async {
      final library = await Library.load();
      final id = await library.createPlaylist('Offline');
      await library.addToPlaylist(id, first);
      final downloads = Downloads(), source = AudioSource();
      final controller = PlaylistDownloads(library, downloads, source);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistDownloadControls(id: id, downloads: controller),
          ),
        ),
      );
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.text('Auto-download new tracks'), findsNothing);
      await tester.tap(find.byTooltip('Download all'));
      await tester.pumpAndSettle();
      expect(library.autoDownloadPlaylists, contains(id));
      expect(enqueued, ['first']);
      expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);
      expect(find.byTooltip('Turn off playlist downloads'), findsOneWidget);
      await library.addToPlaylist(id, second);
      await tester.runAsync(() => settled(controller));
      await tester.pumpAndSettle();
      expect(enqueued, ['first', 'second']);
      await tester.tap(find.byTooltip('Turn off playlist downloads'));
      await tester.pumpAndSettle();
      expect(library.autoDownloadPlaylists, isNot(contains(id)));
      expect(downloads.entries, hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      downloads.dispose();
    },
  );
}
