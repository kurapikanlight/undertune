import 'package:flutter/material.dart';
import '../media/video_catalog.dart';
import 'loading.dart';
import 'media_image.dart';

class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({super.key, required this.channel, this.size = 56});
  final VideoChannel channel;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipOval(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: channel.artwork.isEmpty
            ? const Icon(Icons.person_outline)
            : MediaImage.network(
                channel.artwork,
                cacheWidth: artworkDecodeWidth(context, size),
                fallback: const Icon(Icons.person_outline),
              ),
      ),
    ),
  );
}

class VideoChannelRow extends StatelessWidget {
  const VideoChannelRow({
    super.key,
    required this.channel,
    required this.following,
    required this.onTap,
  });
  final VideoChannel channel;
  final bool following;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    leading: ChannelAvatar(channel: channel),
    title: Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      following
          ? 'Following in Undertune'
          : channel.subscribers >= 0
          ? '${compactCount(channel.subscribers)} subscribers'
          : 'YouTube channel',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: Icon(
      following ? Icons.check_circle_outline : Icons.chevron_right,
    ),
    onTap: onTap,
  );
}

String compactCount(int count) => count >= 1000000
    ? '${(count / 1000000).toStringAsFixed(1)}M'
    : count >= 1000
    ? '${(count / 1000).toStringAsFixed(1)}K'
    : '$count';

class VideoPlaylistRow extends StatelessWidget {
  const VideoPlaylistRow({
    super.key,
    required this.playlist,
    required this.onTap,
    this.saved = false,
  });
  final RemoteVideoPlaylist playlist;
  final bool saved;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 76.8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: playlist.artwork.isEmpty
                    ? const Icon(Icons.video_library_outlined)
                    : MediaImage.network(
                        playlist.artwork,
                        cacheWidth: artworkDecodeWidth(context, 76.8),
                        fallback: const Icon(Icons.video_library_outlined),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Video playlist${playlist.count < 0 ? '' : ' · ${playlist.count} videos'}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (playlist.artist.isNotEmpty)
                  Text(
                    playlist.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            saved ? Icons.playlist_add_check : Icons.playlist_play_outlined,
            size: 22,
          ),
        ],
      ),
    ),
  );
}

class CatalogSkeleton extends StatelessWidget {
  const CatalogSkeleton({super.key, this.channels = false, this.count = 4});
  final bool channels;
  final int count;
  @override
  Widget build(BuildContext context) => ContentSkeleton(
    artworkSize: channels ? 56 : 76.8,
    artworkRadius: channels ? 999 : 12,
    horizontalPadding: 20,
    verticalPadding: channels ? 12 : 7,
    titleLines: 2,
    actionWidth: 32,
    count: count,
    label: channels ? 'Loading channels' : 'Loading video playlists',
  );
}

class CatalogMessage extends StatelessWidget {
  const CatalogMessage({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
      ],
    ),
  );
}
