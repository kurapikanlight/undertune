import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/widgets/loading.dart';
import 'package:undertune/widgets/media_image.dart';

class PendingImage extends ImageProvider<PendingImage> {
  final frame = Completer<ImageInfo>();
  int loads = 0;
  @override
  Future<PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    PendingImage key,
    ImageDecoderCallback decode,
  ) {
    loads++;
    return OneFrameImageStreamCompleter(frame.future);
  }
}

void main() {
  testWidgets(
    'artwork keeps dimensions while pending, loaded, cached, and failed',
    (tester) async {
      final provider = PendingImage();
      Widget build(ImageProvider image) => MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 72,
            child: MediaImage(
              image: image,
              fallback: const Icon(Icons.music_note),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(provider));
      expect(find.byType(SkeletonPulse), findsOneWidget);
      final before = tester.getRect(find.byType(MediaImage));
      provider.frame.complete(
        ImageInfo(
          image: (await tester.runAsync(
            () => createTestImage(width: 20, height: 20),
          ))!,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.byType(SkeletonPulse), findsNothing);
      expect(tester.getRect(find.byType(MediaImage)), before);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(build(provider));
      expect(find.byType(SkeletonPulse), findsNothing);
      expect(provider.loads, 1);
      final failure = PendingImage();
      await tester.pumpWidget(build(failure));
      failure.frame.completeError(StateError('offline'));
      await tester.pump();
      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.byType(SkeletonPulse), findsNothing);
      expect(tester.getRect(find.byType(MediaImage)), before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
