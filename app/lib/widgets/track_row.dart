import 'package:flutter/material.dart';
import '../media/extractor.dart';
import 'media_image.dart';
import 'favorite_icon.dart';

class Artwork extends StatelessWidget {
  const Artwork(
    this.url, {
    super.key,
    this.size = 52,
    this.liked = false,
    this.icon,
  });
  final String url;
  final double size;
  final bool liked;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size > 120 ? 18 : 10),
    child: SizedBox(
      width: size,
      height: size,
      child: liked || icon != null
          ? ColoredBox(
              color: Colors.black,
              child: Center(
                child: Icon(
                  icon ?? Icons.favorite,
                  color: const Color(0xfff2a4a1),
                  size: size * .58,
                ),
              ),
            )
          : url.isEmpty
          ? _placeholder(context)
          : MediaImage.network(
              url,
              cacheWidth: artworkDecodeWidth(context, size),
              fallback: _placeholder(context),
            ),
    ),
  );
  Widget _placeholder(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Icon(
      Icons.music_note_rounded,
      size: size * .4,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.track,
    required this.onTap,
    required this.onLike,
    required this.onMore,
    required this.liked,
    this.active = false,
    this.downloaded = false,
    this.artworkSize = 52,
    this.titleLines = 1,
    this.showDuration = false,
    this.showFavorite = true,
    this.verticalPadding,
    this.horizontalPadding = 24,
    this.artworkGap = 12,
  });
  final Track track;
  final VoidCallback onTap, onLike, onMore;
  final bool liked, active, downloaded;
  final double artworkSize;
  final int titleLines;
  final bool showDuration;
  final bool showFavorite;
  final double? verticalPadding;
  final double horizontalPadding, artworkGap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding ?? (artworkSize > 60 ? 10 : 6),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Artwork(track.artwork, size: artworkSize),
              if (downloaded)
                Positioned(
                  right: 3,
                  top: active ? 3 : null,
                  bottom: active ? null : 3,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.download_done_rounded,
                      size: 12,
                      semanticLabel: 'Available offline',
                    ),
                  ),
                ),
              if (active)
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.graphic_eq,
                      size: 12,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: artworkGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: titleLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${track.artist}${showDuration && track.duration > 0 ? ' · ${mediaTime(track.duration)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .6),
                  ),
                ),
              ],
            ),
          ),
          if (showFavorite)
            IconButton(
              tooltip: liked ? 'Unlike' : 'Like',
              isSelected: liked,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.all(8),
              onPressed: onLike,
              icon: FavoriteIcon(liked: liked),
            ),
          IconButton(
            tooltip: 'Track actions',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.all(8),
            onPressed: onMore,
            icon: const Icon(Icons.more_vert, size: 21),
          ),
        ],
      ),
    ),
  );
}
