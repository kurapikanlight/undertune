import 'package:flutter/material.dart';
import 'loading.dart';

int artworkDecodeWidth(BuildContext context, double logicalWidth) =>
    (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round().clamp(
      1,
      1600,
    );

/// The owner supplies fixed artwork bounds. Loading never changes those bounds,
/// synchronous cache hits skip the placeholder, and failures remain local.
class MediaImage extends StatelessWidget {
  const MediaImage({super.key, required this.image, required this.fallback});
  MediaImage.network(
    String url, {
    super.key,
    int? cacheWidth,
    required this.fallback,
  }) : image = ResizeImage.resizeIfNeeded(cacheWidth, null, NetworkImage(url));
  final ImageProvider image;
  final Widget fallback;
  @override
  Widget build(BuildContext context) => Image(
    image: image,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => fallback,
    frameBuilder: (context, child, frame, synchronous) {
      if (synchronous) return child;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (frame == null)
            const SkeletonPulse(child: SkeletonBlock(radius: 0)),
          AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: child,
          ),
        ],
      );
    },
  );
}
