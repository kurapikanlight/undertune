import 'package:flutter/material.dart';
import '../library.dart';
import '../media/extractor.dart';
import '../media/music_collections.dart';
import '../widgets/branding.dart';
import '../widgets/loading.dart';
import '../widgets/playlist_cover.dart';

class MusicCollectionScreen extends StatefulWidget {
  const MusicCollectionScreen({
    super.key,
    required this.collection,
    required this.catalog,
    required this.library,
    required this.row,
    required this.onSaved,
  });
  final MusicCollection collection;
  final MusicCatalog catalog;
  final Library library;
  final Widget Function(Track, List<Track>) row;
  final ValueChanged<String> onSaved;
  @override
  State<MusicCollectionScreen> createState() => _MusicCollectionScreenState();
}

class _MusicCollectionScreenState extends State<MusicCollectionScreen> {
  final _tracks = <Track>[];
  String? _next, _error;
  bool _loading = true, _saving = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.catalog.collection(
        widget.collection,
        page: more ? _next : null,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (!more) _tracks.clear();
        final seen = _tracks.map((t) => t.key).toSet();
        _tracks.addAll(page.tracks.where((t) => seen.add(t.key)));
        _next = page.nextPage;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Couldn’t load this music collection.');
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
      final tracks = [..._tracks],
          seen = tracks.map((t) => t.key).toSet(),
          pages = <String>{};
      var next = _next;
      while (next != null) {
        if (!pages.add(next)) throw StateError('Repeated continuation');
        final page = await widget.catalog.collection(
          widget.collection,
          page: next,
        );
        if (!mounted) return;
        tracks.addAll(page.tracks.where((t) => seen.add(t.key)));
        next = page.nextPage;
      }
      final id = await widget.library.saveMusicCollection(
        widget.collection,
        tracks,
      );
      if (mounted) widget.onSaved(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t add the collection. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.only(bottom: 28),
    itemCount: _tracks.length + 2,
    itemBuilder: (context, index) {
      if (index == 0) {
        final source = widget.collection,
            saved = widget.library.playlists.any((p) => p.id == source.key);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: LayoutBuilder(
                  builder: (context, box) => PlaylistCover(
                    tracks: _tracks,
                    sourceArtwork: source.artwork,
                    size: (box.maxWidth * .7).clamp(120, 240),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (source.kind == 'album')
                Text(
                  source.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                MediaHeading(source.name, fontSize: 48),
              const SizedBox(height: 6),
              Text(
                '${source.kind == 'album' ? 'Album' : 'Music playlist'}${source.artist.isEmpty ? '' : ' · ${source.artist}'}${_tracks.isEmpty ? '' : ' · ${_tracks.length}${_next == null ? '' : '+'} tracks'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: saved
                    ? () => widget.onSaved(source.key)
                    : _loading || _saving || _error != null
                    ? null
                    : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        saved
                            ? Icons.library_add_check
                            : Icons.library_add_outlined,
                      ),
                label: Text(
                  saved
                      ? 'Open in Your Library'
                      : _saving
                      ? 'Adding all tracks…'
                      : 'Add to Your Library',
                ),
              ),
            ],
          ),
        );
      }
      if (index <= _tracks.length) {
        return widget.row(_tracks[index - 1], _tracks);
      }
      if (_loading) {
        return const ContentSkeleton(artworkSize: 64, titleLines: 2, count: 4);
      }
      if (_error != null) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(_error!),
              TextButton.icon(
                onPressed: () => _load(more: _next != null),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      if (_tracks.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No playable tracks in this collection.'),
        );
      }
      if (_next != null) {
        return TextButton(
          onPressed: _saving ? null : () => _load(more: true),
          child: const Text('Load more tracks'),
        );
      }
      return const SizedBox.shrink();
    },
  );
}
