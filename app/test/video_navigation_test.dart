import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';
import 'package:undertune/screens/video_channel.dart';
import 'package:undertune/screens/library.dart';
import 'package:undertune/screens/video_playlist.dart';

void main() {
  testWidgets(
    'Videos channel to playlist back stack preserves shell and music library',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      await library.completeOnboarding();
      const bridge = MethodChannel('undertune/extractor');
      final requests = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, (call) async {
            requests.add(call.method);
            switch (call.method) {
              case 'search':
                return {'items': [], 'nextPage': null};
              case 'videoChannels':
                return {
                  'channels': [
                    {
                      'id': 'UCone',
                      'url': 'https://youtube.com/channel/UCone',
                      'name': 'Creator',
                    },
                  ],
                };
              case 'videoChannel':
                return {
                  'id': 'UCone',
                  'url': 'https://youtube.com/channel/UCone',
                  'name': 'Creator',
                  'tabs': ['videos', 'playlists'],
                  'sorts': ['latest', 'popular'],
                };
              case 'videoChannelItems':
                return call.arguments['tab'] == 'playlists'
                    ? {
                        'playlists': [
                          {
                            'id': 'PLone',
                            'url': 'https://youtube.com/playlist?list=PLone',
                            'name': 'Remote collection',
                          },
                        ],
                      }
                    : {'items': []};
              case 'videoPlaylist':
                return {
                  'items': [],
                  'playlist': {
                    'id': 'PLone',
                    'url': 'https://youtube.com/playlist?list=PLone',
                    'name': 'Remote collection',
                  },
                };
              default:
                return null;
            }
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(bridge, null),
      );
      await tester.pumpWidget(UndertuneApp(library: library));
      await tester.pump();
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Videos').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Channels'));
      await tester.pump();
      await tester.tap(find.text('Creator'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.byType(VideoChannelScreen), findsOneWidget);
      await tester.tap(find.text('Playlists'));
      await tester.pump();
      await tester.tap(find.text('Remote collection'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(VideoPlaylistScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Add to Your Library'));
      await tester.pump();
      await tester.tap(find.text('Add to Your Library'));
      await tester.pump();
      expect(library.tracks, isEmpty);
      expect(library.videoPlaylists, hasLength(1));
      final before = requests.where((r) => r == 'videoChannel').length;
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(VideoPlaylistScreen), findsNothing);
      expect(find.byType(VideoChannelScreen), findsOneWidget);
      expect(requests.where((r) => r == 'videoChannel').length, before);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(VideoChannelScreen), findsNothing);
      expect(find.text('Creator'), findsOneWidget);
      await tester.tap(find.text('Your Library'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.scrollUntilVisible(
        find.text('Remote collection'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(LibraryScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Remote collection'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(VideoPlaylistScreen), findsOneWidget);
      expect(find.byType(VideoChannelScreen), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
