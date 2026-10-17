import 'package:flutter/material.dart';
import '../library.dart';
import '../media/extractor.dart';
import '../widgets/discovery.dart';
import '../widgets/track_row.dart';
import '../widgets/playlist_cover.dart';
import '../widgets/branding.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.library,
    required this.extractor,
    required this.onCollection,
    required this.onVideos,
    required this.onSearch,
    required this.onPlay,
    required this.suggestionRow,
    this.active = true,
  });
  final Library library;
  final Extractor extractor;
  final ValueChanged<String> onCollection;
  final VoidCallback onVideos, onSearch;
  final void Function(Track, List<Track>) onPlay;
  final Widget Function(Track, List<Track>) suggestionRow;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final all = library.tracks;
    return ListView(
      key: const PageStorageKey('home-scroll'),
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            'Home',
            style: Theme.of(context).textTheme.headlineMedium?.merge(
              feelfreeHeadingStyle.copyWith(fontSize: 62.4),
            ),
          ),
        ),
        _heading(
          context,
          'Your collection',
          action: TextButton.icon(
            onPressed: onVideos,
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.ondemand_video, size: 18),
            label: const Text('Videos'),
          ),
        ),
        _shelf(context, [
          ...library.playlists.map(
            (p) => _tile(
              context,
              p.name,
              '${p.tracks.length} ${p.tracks.length == 1 ? 'track' : 'tracks'}',
              p.tracks.isEmpty ? '' : p.tracks.first.artwork,
              () => onCollection(p.id),
              cover: PlaylistCover(
                tracks: p.tracks,
                coverPath: p.coverPath,
                sourceArtwork: p.sourceArtwork,
              ),
            ),
          ),
          _tile(
            context,
            'Tracks',
            '${all.length} ${all.length == 1 ? 'track' : 'tracks'}',
            all.isEmpty ? '' : all.first.artwork,
            () => onCollection('tracks'),
            cover: const Artwork('', size: 96, icon: Icons.headphones_rounded),
          ),
          _tile(
            context,
            'Liked',
            '${library.liked.length} ${library.liked.length == 1 ? 'track' : 'tracks'}',
            '',
            () => onCollection('liked'),
            liked: true,
          ),
        ]),
        _heading(context, 'Recently played'),
        if (library.history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your listening starts here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Discover music'),
                ),
              ],
            ),
          )
        else
          _shelf(
            context,
            library.history
                .take(12)
                .map(
                  (t) => _tile(
                    context,
                    t.title,
                    t.artist,
                    t.artwork,
                    () => onPlay(t, library.history),
                  ),
                )
                .toList(),
          ),
        Discovery(
          key: const ValueKey('music-suggestions'),
          library: library,
          extractor: extractor,
          row: suggestionRow,
          active: active,
        ),
      ],
    );
  }

  Widget _shelf(BuildContext context, List<Widget> children) => SizedBox(
    height:
        96 +
        20 +
        MediaQuery.textScalerOf(context).scale(14) * 2.5 +
        MediaQuery.textScalerOf(context).scale(12) * 1.4,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, i) => children[i],
    ),
  );
  Widget _tile(
    BuildContext context,
    String title,
    String subtitle,
    String art,
    VoidCallback onTap, {
    bool liked = false,
    Widget? cover,
  }) => SizedBox(
    width: 104,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cover ?? Artwork(art, size: 96, liked: liked),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
  Widget _heading(BuildContext context, String text, {Widget? action}) =>
      Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          text == 'Your collection' ? 8 : 12,
          20,
          10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleLarge?.merge(
                  feelfreeHeadingStyle.copyWith(
                    fontSize: text == 'Your collection' ? 44 : 36,
                  ),
                ),
              ),
            ),
            ?action,
          ],
        ),
      );
}
