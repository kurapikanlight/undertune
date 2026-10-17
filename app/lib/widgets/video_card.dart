import 'package:flutter/material.dart';
import '../media/extractor.dart';
import 'media_image.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.track,
    required this.onTap,
    required this.onMore,
    this.onChannel,
  });
  final Track track;
  final VoidCallback onTap, onMore;
  final VoidCallback? onChannel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onTap,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (track.artwork.isNotEmpty)
                        LayoutBuilder(
                          builder: (context, constraints) => MediaImage.network(
                            track.artwork,
                            cacheWidth: artworkDecodeWidth(
                              context,
                              constraints.maxWidth,
                            ),
                            fallback: const Icon(
                              Icons.ondemand_video_outlined,
                              size: 40,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.ondemand_video_outlined, size: 40),
                      if (track.live || track.duration > 0)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: track.live
                                  ? Colors.red.shade700
                                  : Colors.black87,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              track.live ? 'LIVE' : mediaTime(track.duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 0, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            InkWell(
                              onTap: onChannel,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: .6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Video actions',
                    onPressed: onMore,
                    icon: const Icon(
                      Icons.more_vert,
                      size: 21,
                      semanticLabel: 'Video actions',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
