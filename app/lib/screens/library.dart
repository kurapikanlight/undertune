import 'package:flutter/material.dart';
import '../library.dart';
import '../media/extractor.dart';
import '../media/video_catalog.dart';
import '../widgets/video_catalog_widgets.dart';
import '../widgets/playlist_row.dart';
import '../widgets/branding.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.library,
    required this.onCollection,
    required this.onVideos,
    required this.onDownloads,
    required this.trackRow,
    this.onVideoPlaylist,
  });
  final ValueChanged<RemoteVideoPlaylist>? onVideoPlaylist;
  final Library library;
  final ValueChanged<String> onCollection;
  final VoidCallback onVideos, onDownloads;
  final Widget Function(Track, List<Track>) trackRow;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  final _queries = ['', ''];
  bool _tracks = false;
  double _swipeDistance = 0;
  String _sort = 'Saved order';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(bool value) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _queries[_tracks ? 1 : 0] = _search.text;
      _tracks = value;
      _search.text = _queries[_tracks ? 1 : 0];
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.library,
    builder: (context, _) {
      final library = widget.library;
      final saved = library.tracks;
      final query = _search.text.trim().toLowerCase();
      final playlists = [
        Playlist('liked', 'Liked', library.liked),
        ...library.playlists,
      ].where((p) => p.name.toLowerCase().contains(query)).toList();
      final videos = library.videoPlaylists
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
      final tracks = saved
          .where((t) => '${t.title} ${t.artist}'.toLowerCase().contains(query))
          .toList();
      if (_sort == 'Name A–Z') {
        videos.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        playlists.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        tracks.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _swipeDistance = 0,
        onHorizontalDragUpdate: (d) => _swipeDistance += d.delta.dx,
        onHorizontalDragEnd: (d) {
          final velocity = d.primaryVelocity ?? 0;
          if (_swipeDistance < -64 || velocity < -300) _select(true);
          if (_swipeDistance > 64 || velocity > 300) _select(false);
          _swipeDistance = 0;
        },
        child: ListView(
          key: const PageStorageKey('library-scroll'),
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (c, box) {
                  final narrow =
                      box.maxWidth < 300 ||
                      MediaQuery.textScalerOf(c).scale(1) > 1.4;
                  final title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your library',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.merge(
                              feelfreeHeadingStyle.copyWith(fontSize: 48),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${library.playlists.length + library.videoPlaylists.length + 1} ${library.playlists.length + library.videoPlaylists.length + 1 == 1 ? 'playlist' : 'playlists'} · ${saved.length} ${saved.length == 1 ? 'track' : 'tracks'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _action(Icons.movie_outlined, 'Videos', widget.onVideos),
                      const SizedBox(width: 10),
                      _action(
                        Icons.download_outlined,
                        'Downloads',
                        widget.onDownloads,
                      ),
                    ],
                  );
                  return narrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: 12),
                            actions,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 12),
                            actions,
                          ],
                        );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LibrarySelector(tracks: _tracks, onChanged: _select),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (c, box) {
                  final search = TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: _tracks ? 'Search Tracks' : 'Search playlists',
                      prefixIcon: const Icon(Icons.search, size: 21),
                      filled: true,
                      fillColor: Theme.of(c).colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  );
                  final sort = PopupMenuButton<String>(
                    tooltip: 'Sort library',
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (_) => ['Saved order', 'Name A–Z']
                        .map((s) => PopupMenuItem(value: s, child: Text(s)))
                        .toList(),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          c,
                        ).colorScheme.surface.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort_rounded, size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _sort,
                              style: Theme.of(c).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  return box.maxWidth < 310 ||
                          MediaQuery.textScalerOf(c).scale(1) > 1.3
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [search, const SizedBox(height: 4), sort],
                        )
                      : Row(
                          children: [
                            Expanded(child: search),
                            const SizedBox(width: 8),
                            sort,
                          ],
                        );
                },
              ),
            ),
            const SizedBox(height: 10),
            if (_tracks)
              ...tracks.map((t) => widget.trackRow(t, tracks))
            else
              ...playlists.map(
                (p) => PlaylistRow(
                  name: p.name,
                  tracks: p.tracks,
                  coverPath: p.coverPath,
                  sourceArtwork: p.sourceArtwork,
                  subtitle: p.collectionKind == 'album'
                      ? 'Album · ${p.tracks.length} tracks'
                      : null,
                  liked: p.id == 'liked',
                  artworkSize: 96 * .8,
                  onTap: () => widget.onCollection(p.id),
                ),
              ),
            if (!_tracks)
              ...videos.map(
                (p) => VideoPlaylistRow(
                  playlist: p,
                  saved: true,
                  onTap: () => widget.onVideoPlaylist?.call(p),
                ),
              ),
            if (_tracks ? tracks.isEmpty : playlists.isEmpty && videos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 36,
                ),
                child: Column(
                  children: [
                    Icon(
                      _tracks
                          ? Icons.library_music_outlined
                          : Icons.playlist_play_rounded,
                      size: 38,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      query.isNotEmpty
                          ? 'No matches found'
                          : _tracks
                          ? 'No saved tracks yet'
                          : 'No playlists yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      query.isNotEmpty
                          ? 'Try a different search.'
                          : 'Save a song from Search to start your collection.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
  Widget _action(IconData icon, String tooltip, VoidCallback onTap) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, semanticLabel: tooltip),
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surface,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
}
