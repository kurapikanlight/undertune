import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/screens/video.dart';
import 'package:undertune/widgets/minimize_on_swipe.dart';

void main() {
  testWidgets(
    'expanded video hides browsing; swipe preserves its state in the mini-player',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      await library.played(
        const Track(
          url: 'https://example.com/video',
          title: 'Saved video',
          artist: 'Artist',
          video: true,
        ),
      );
      await library.completeOnboarding();
      await tester.pumpWidget(UndertuneApp(library: library));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Saved video').hitTestable(),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Saved video'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Your collection'), findsNothing);
      final state = tester.state(find.byType(VideoScreen));
      await tester.drag(find.byType(MinimizeOnSwipe), const Offset(0, 160));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byTooltip('Close video'), findsOneWidget);
      expect(
        tester.getSize(find.byTooltip('Close video')).width,
        greaterThanOrEqualTo(48),
      );
      expect(identical(state, tester.state(find.byType(VideoScreen))), isTrue);
      final window = tester.getSize(find.byType(VideoScreen));
      expect(window.width, lessThan(tester.view.physicalSize.width * .6));
      expect(window.height, lessThan(150));
      await tester.tapAt(
        tester.getTopLeft(find.byType(VideoScreen)) + const Offset(25, 35),
      );
      await tester.pump();
      expect(find.byType(NavigationBar), findsNothing);
      expect(identical(state, tester.state(find.byType(VideoScreen))), isTrue);
      await tester.drag(find.byType(MinimizeOnSwipe), const Offset(0, 160));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Close video'));
      await tester.pump();
      expect(find.byType(VideoScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
