import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/screens/player.dart';
import 'player_controls_test.dart' show Controls, song;

class CountedTrack extends Track {
  CountedTrack(int index)
    : super(url: 'queue-$index', title: 'Song $index', artist: 'Artist');
  static int titleReads = 0;
  @override
  String get title {
    titleReads++;
    return super.title;
  }
}

void main() {
  testWidgets(
    'opening a large queue only prepares visible rows and the last song remains selectable',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final queue = List.generate(1000, CountedTrack.new);
      final p = Controls(Extractor(), library)
        ..current = song
        ..queue = queue;
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            playback: p,
            library: library,
            onAdd: (_) async {},
            onActions: (_) async {},
            onPlay: p.play,
          ),
        ),
      );
      await tester.pump();
      CountedTrack.titleReads = 0;
      await tester.ensureVisible(find.text('Queue · 1000'));
      await tester.tap(find.text('Queue · 1000'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        CountedTrack.titleReads,
        lessThan(30),
        reason:
            'Offscreen song widgets must not all be allocated when opening the queue',
      );
      final list = find.byType(ListView).last;
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      // Lazy variable-height lists refine their extent estimate as rows appear.
      for (var i = 0; i < 4 && find.text('Song 999').evaluate().isEmpty; i++) {
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
      }
      await tester.tap(find.text('Song 999'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(p.current?.key, queue.last.key);
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
  );
}
