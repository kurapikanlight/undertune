import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/widgets/corner_video_frame.dart';

void main() {
  testWidgets(
    'video snaps to all four safe corners and retains corner on expansion',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool minimized = true;
      late StateSetter rebuild;
      const pictureKey = ValueKey('picture');
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.only(top: 24, bottom: 20),
            ),
            child: StatefulBuilder(
              builder: (c, set) {
                rebuild = set;
                return Stack(
                  children: [
                    CornerVideoFrame(
                      minimized: minimized,
                      child: const ColoredBox(
                        key: pictureKey,
                        color: Colors.black,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      for (final destination in [
        const Offset(20, 40),
        const Offset(380, 40),
        const Offset(20, 720),
        const Offset(380, 720),
      ]) {
        await tester.dragFrom(
          tester.getCenter(find.byKey(pictureKey)),
          destination - tester.getCenter(find.byKey(pictureKey)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final rect = tester.getRect(find.byKey(pictureKey));
        expect(rect.left, greaterThanOrEqualTo(12));
        expect(rect.top, greaterThanOrEqualTo(32));
        expect(rect.right, lessThanOrEqualTo(388));
        expect(rect.bottom, lessThanOrEqualTo(800 - 20 - 54.4 - 8));
        expect(rect.center.dx < 200, destination.dx < 200);
        expect(rect.center.dy < 400, destination.dy < 400);
      }
      final before = tester.getRect(find.byKey(pictureKey));
      rebuild(() => minimized = false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(find.byKey(pictureKey)), const Size(400, 800));
      rebuild(() => minimized = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(find.byKey(pictureKey)), before);
      expect(tester.takeException(), isNull);
    },
  );
}
