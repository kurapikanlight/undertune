import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/widgets/loading.dart';
import 'package:undertune/widgets/track_row.dart';

void main() {
  testWidgets(
    'music skeleton reserves the same row height as incoming tracks',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const ContentSkeleton(count: 1),
                TrackRow(
                  track: const Track(
                    url: 'one',
                    title: 'Song',
                    artist: 'Artist',
                  ),
                  onTap: () {},
                  onLike: () {},
                  onMore: () {},
                  liked: false,
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(ContentSkeleton)).height,
        tester.getSize(find.byType(TrackRow)).height,
      );
    },
  );
  testWidgets(
    'loading breathes quietly and stops when motion is disabled or offstage',
    (tester) async {
      Widget build({bool disabled = false, bool active = true}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disabled),
          child: TickerMode(
            enabled: active,
            child: const ContentSkeleton(count: 1),
          ),
        ),
      );
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(build(disabled: true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(build(active: false));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('new loading views stay quiet when created in the background', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpWidget(const MaterialApp(home: ContentSkeleton(count: 1)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FadeTransition), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
