import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/theme.dart';

void main() {
  testWidgets('cloud motion paints without rebuilding its widget subtree', (
    tester,
  ) async {
    const key = ValueKey('atmosphere-frame');
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 160,
          height: 320,
          child: RepaintBoundary(
            key: key,
            child: AtmosphericBackground(
              theme: Atmosphere.all.first,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    Future<List<int>> pixels() async => (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: .25);
      final data = await image.toByteData();
      image.dispose();
      return data!.buffer.asUint8List().toList();
    }))!;
    final before = await pixels();
    var rebuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.findAncestorWidgetOfExactType<AtmosphericBackground>() !=
          null) {
        rebuilds++;
      }
      previous?.call(element, builtOnce);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final after = await pixels();
    expect(
      after,
      isNot(orderedEquals(before)),
      reason: 'The clouds must keep moving.',
    );
    // Animation frames must invalidate paint rather than rebuild UI widgets.
    expect(rebuilds, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
