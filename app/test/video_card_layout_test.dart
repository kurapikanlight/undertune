import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/theme.dart';
import 'package:undertune/widgets/video_card.dart';

void main() {
  testWidgets('video frame surrounds the thumbnail and its information', (
    tester,
  ) async {
    for (final width in [320.0, 412.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                VideoCard(
                  track: const Track(
                    url: 'video',
                    title: 'Video title',
                    artist: 'Channel',
                  ),
                  onTap: () {},
                  onMore: () {},
                ),
              ],
            ),
          ),
        ),
      );
      final card = find.byType(VideoCard);
      final frame = tester.getRect(
        find.descendant(of: card, matching: find.byType(Material)).first,
      );
      final thumbnail = tester.getRect(
        find.descendant(of: card, matching: find.byType(AspectRatio)),
      );
      expect(thumbnail.left, greaterThan(frame.left));
      expect(thumbnail.right, lessThan(frame.right));
      expect(thumbnail.top, greaterThan(frame.top));
      expect(thumbnail.width / thumbnail.height, closeTo(16 / 9, .001));
      expect(
        tester.getRect(find.text('Video title')).top,
        greaterThan(thumbnail.bottom),
      );
      expect(
        tester.getRect(find.text('Channel')).bottom,
        lessThan(frame.bottom),
      );
      expect(
        tester.getRect(find.byTooltip('Video actions')).bottom,
        lessThanOrEqualTo(frame.bottom),
      );
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets(
    'video cards separate metadata and never overlap at large text in either theme',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final atmosphere in [Atmosphere.all.first, Atmosphere.all.last]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: atmosphere.data,
            home: Scaffold(
              body: ListView(
                children: [
                  for (var i = 0; i < 2; i++)
                    VideoCard(
                      key: ValueKey(i),
                      track: Track(
                        url: '$i',
                        title:
                            'A very long video title that must wrap without covering another video',
                        artist:
                            'A very long channel name that must stay inside its own information area',
                        duration: 123,
                      ),
                      onTap: () {},
                      onMore: () {},
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        final first = tester.getRect(find.byKey(const ValueKey(0)));
        final second = tester.getRect(find.byKey(const ValueKey(1)));
        expect(second.top, greaterThanOrEqualTo(first.bottom));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
