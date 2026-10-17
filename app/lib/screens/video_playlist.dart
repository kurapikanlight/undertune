import 'package:flutter/material.dart';
import '../library.dart';
import '../media/extractor.dart';
import '../media/video_catalog.dart';
import '../widgets/branding.dart';
import '../widgets/loading.dart';
import '../widgets/media_image.dart';
import '../widgets/video_catalog_widgets.dart';

class VideoPlaylistScreen extends StatefulWidget {
  const VideoPlaylistScreen({
    super.key,
    required this.playlist,
    required this.library,
    required this.catalog,
    required this.row,
    required this.onPlay,
  });
  final RemoteVideoPlaylist playlist;
  final Library library;
  final VideoCatalog catalog;
  final Widget Function(Track, List<Track>) row;
  final ValueChanged<Track> onPlay;
  @override
  State<VideoPlaylistScreen> createState() => _VideoPlaylistScreenState();
}

class _VideoPlaylistScreenState extends State<VideoPlaylistScreen> {
  late RemoteVideoPlaylist _playlist = widget.playlist;
  final _scroll = ScrollController();
  final _videos = <Track>[];
  String? _next, _error;
  bool _loading = true, _saving = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_paginate);
    _load();
  }

  void _paginate() {
    if (_scroll.position.extentAfter < 600 &&
        !_loading &&
        _next != null &&
        _error == null) {
      _load(more: true);
    }
  }

  Future<void> _load({bool more = false, bool refresh = false}) async {
    if (more && (_loading || _next == null)) return;
    final generation = ++_generation;
    final token = more ? _next : null;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.catalog.playlist(
        _playlist,
        page: token,
        refresh: refresh,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (page.playlist != null) _playlist = page.playlist!;
        if (!more) _videos.clear();
        final seen = _videos.map((v) => v.key).toSet();
        _videos.addAll(page.videos.where((v) => seen.add(v.key)));
        _next = page.nextPage;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        if (videoPageExpired(error)) _next = null;
        setState(
          () => _error =
              'Couldn’t load this video playlist. It may be private or unavailable.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (widget.library.hasVideoPlaylist(_playlist)) {
        await widget.library.removeVideoPlaylist(_playlist.key);
      } else {
        await widget.library.saveVideoPlaylist(_playlist);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t save this change. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    ++_generation;
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.only(bottom: 24),
    itemCount: _videos.length + 2,
    itemBuilder: (context, index) {
      if (index == 0) return _header(context);
      if (index <= _videos.length) {
        return widget.row(_videos[index - 1], _videos);
      }
      if (_loading) return const ContentSkeleton(video: true, count: 2);
      if (_error != null) {
        return CatalogMessage(
          message: _error!,
          onRetry: () => _load(more: _next != null, refresh: true),
        );
      }
      if (_videos.isEmpty) {
        return const CatalogMessage(
          message:
              'No playable videos in this playlist. Private or removed videos may be unavailable.',
        );
      }
      if (_next != null) {
        return TextButton(
          onPressed: () => _load(more: true),
          child: const Text('Load more'),
        );
      }
      return const SizedBox.shrink();
    },
  );
  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: _playlist.artwork.isEmpty
                  ? const Icon(Icons.video_library_outlined, size: 56)
                  : MediaImage.network(
                      _playlist.artwork,
                      cacheWidth: artworkDecodeWidth(
                        context,
                        MediaQuery.sizeOf(context).width,
                      ),
                      fallback: const Icon(
                        Icons.video_library_outlined,
                        size: 56,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        MediaHeading(_playlist.name),
        const SizedBox(height: 4),
        Text(
          [
            'Video playlist',
            if (_playlist.count >= 0) '${_playlist.count} videos',
            if (_playlist.artist.isNotEmpty) _playlist.artist,
          ].join(' · '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            ListenableBuilder(
              listenable: widget.library,
              builder: (context, _) {
                final saved = widget.library.hasVideoPlaylist(_playlist);
                return FilledButton.tonalIcon(
                  onPressed: _saving ? null : _save,
                  icon: Icon(
                    saved ? Icons.playlist_add_check : Icons.playlist_add,
                  ),
                  label: Text(
                    saved ? 'Remove from Your Library' : 'Add to Your Library',
                  ),
                );
              },
            ),
            if (_videos.isNotEmpty)
              FilledButton.icon(
                onPressed: () => widget.onPlay(_videos.first),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
          ],
        ),
      ],
    ),
  );
}
