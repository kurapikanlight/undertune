import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/widgets/corner_video_frame.dart';
import 'package:undertune/widgets/track_row.dart';

void main() {
  testWidgets('compact track actions retain Android sized labeled targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackRow(
            track: const Track(url: 'song', title: 'Song', artist: 'Artist'),
            downloaded: true,
            liked: false,
            onTap: () {},
            onLike: () {},
            onMore: () {},
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byTooltip('Like')).width,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byTooltip('Track actions')).width,
      greaterThanOrEqualTo(48),
    );
    expect(find.bySemanticsLabel(RegExp('Available offline')), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
  testWidgets('floating video can move corners without a dragging gesture', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CornerVideoFrame(
            minimized: true,
            child: ColoredBox(key: ValueKey('video'), color: Colors.black),
          ),
        ),
      ),
    );
    final before = tester.getRect(find.byKey(const ValueKey('video')));
    final node = tester.getSemantics(find.bySemanticsLabel('Floating video'));
    final actions = node.getSemanticsData().customSemanticsActionIds!;
    final topLeft = actions.firstWhere(
      (id) =>
          CustomSemanticsAction.getAction(id)?.label ==
          'Move video to top left',
    );
    tester
        .renderObject(find.byType(CornerVideoFrame))
        .owner!
        .semanticsOwner!
        .performAction(node.id, SemanticsAction.customAction, topLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final after = tester.getRect(find.byKey(const ValueKey('video')));
    expect(after.top, lessThan(before.top));
    expect(after.left, lessThan(before.left));
    expect(after.size, before.size);
    handle.dispose();
  });
}
