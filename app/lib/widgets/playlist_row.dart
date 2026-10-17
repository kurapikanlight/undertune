import 'package:flutter/material.dart';
import '../media/extractor.dart';
import 'playlist_cover.dart';

class PlaylistRow extends StatelessWidget {
  const PlaylistRow({
    super.key,
    required this.name,
    required this.tracks,
    required this.onTap,
    this.liked = false,
    this.artworkSize = 96,
    this.coverPath,
    this.sourceArtwork,
    this.subtitle,
    this.trailing,
  });
  final String name;
  final List<Track> tracks;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool liked;
  final double artworkSize;
  final String? coverPath, sourceArtwork, subtitle;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          PlaylistCover(
            tracks: tracks,
            coverPath: coverPath,
            sourceArtwork: sourceArtwork,
            size: artworkSize,
            liked: liked,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ??
                      '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    ),
  );
}

class LibrarySelector extends StatelessWidget {
  const LibrarySelector({
    super.key,
    required this.tracks,
    required this.onChanged,
  });
  final bool tracks;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 8,
    children: [
      _option(context, 'Playlists', false),
      _option(context, 'Tracks', true),
    ],
  );
  Widget _option(BuildContext context, String name, bool value) => Semantics(
    selected: tracks == value,
    button: true,
    child: TextButton(
      onPressed: () => onChanged(value),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        foregroundColor: tracks == value
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
        backgroundColor: tracks == value
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(name),
    ),
  );
}
