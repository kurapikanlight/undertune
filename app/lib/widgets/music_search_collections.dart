import 'package:flutter/material.dart';
import '../library.dart';
import '../media/music_collections.dart';
import '../media/extractor.dart';
import '../screens/playlist.dart';
import 'loading.dart';
import 'playlist_row.dart';

class MusicSearchCollections extends StatefulWidget {
  const MusicSearchCollections({
    super.key,
    required this.query,
    required this.catalog,
    required this.library,
    required this.onOpen,
  });
  final String query;
  final MusicCatalog catalog;
  final Library library;
  final ValueChanged<MusicCollection> onOpen;
  @override
  State<MusicSearchCollections> createState() => _MusicSearchCollectionsState();
}

class _MusicSearchCollectionsState extends State<MusicSearchCollections> {
  final _items = <String, List<MusicCollection>>{'album': [], 'playlist': []};
  final _next = <String, String?>{};
  final _loading = <String>{}, _failed = <String>{};
  final _expanded = <String>{}, _saving = <String>{};
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load('album');
    _load('playlist');
  }

  @override
  void didUpdateWidget(MusicSearchCollections old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) {
      _generation++;
      _items.updateAll((_, _) => []);
      _next.clear();
      _loading.clear();
      _failed.clear();
      _expanded.clear();
      _load('album');
      _load('playlist');
    }
  }

  Future<void> _load(String kind, {bool more = false}) async {
    if (_loading.contains(kind)) return;
    final generation = _generation;
    setState(() {
      _loading.add(kind);
      _failed.remove(kind);
    });
    try {
      final page = await widget.catalog.search(
        widget.query,
        kind: kind,
        page: more ? _next[kind] : null,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final seen = _items[kind]!.map((e) => e.key).toSet();
        _items[kind]!.addAll(page.collections.where((e) => seen.add(e.key)));
        _next[kind] = page.nextPage;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _failed.add(kind));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading.remove(kind));
      }
    }
  }

  Future<void> _add(MusicCollection source, {required bool toPlaylist}) async {
    if (_saving.contains(source.key)) return;
    String? target;
    if (toPlaylist) {
      target = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Add to playlist')),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create playlist'),
                onTap: () => Navigator.pop(c, 'new'),
              ),
              for (final playlist in widget.library.playlists.where(
                (p) => p.collectionKind != 'album',
              ))
                ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.tracks.length} tracks'),
                  onTap: () => Navigator.pop(c, playlist.id),
                ),
            ],
          ),
        ),
      );
      if (!mounted || target == null) return;
    }
    setState(() => _saving.add(source.key));
    try {
      final tracks = <Track>[], seen = <String>{}, pages = <String>{};
      String? next;
      do {
        final page = await widget.catalog.collection(source, page: next);
        if (!mounted) return;
        tracks.addAll(page.tracks.where((t) => seen.add(t.key)));
        next = page.nextPage;
        if (next != null && !pages.add(next)) {
          throw StateError('Repeated continuation');
        }
      } while (next != null);
      if (toPlaylist) {
        if (target == 'new') {
          target = await showDialog<String>(
            context: context,
            builder: (_) => PlaylistEditor(library: widget.library),
          );
          if (!mounted || target == null) return;
        }
        await widget.library.addTracksToPlaylist(target!, tracks);
      } else {
        await widget.library.saveMusicCollection(source, tracks);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toPlaylist ? 'Tracks added to playlist' : 'Added to Your Library',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Couldn’t add the collection.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _add(source, toPlaylist: toPlaylist),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(source.key));
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final kind in ['album', 'playlist']) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
          child: Text(
            kind == 'album' ? 'Albums' : 'Music playlists',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final source
            in (_expanded.contains(kind)
                ? _items[kind]!
                : _items[kind]!.take(3)))
          PlaylistRow(
            name: source.name,
            tracks: const [],
            sourceArtwork: source.artwork,
            artworkSize: 76.8,
            subtitle:
                '${kind == 'album' ? 'Album' : 'Playlist'}${source.artist.isEmpty ? '' : ' · ${source.artist}'}${widget.library.playlists.any((p) => p.id == source.key) ? ' · Saved' : ''}',
            onTap: () => widget.onOpen(source),
            trailing: _saving.contains(source.key)
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Adding collection',
                        ),
                      ),
                    ),
                  )
                : PopupMenuButton<String>(
                    tooltip: 'Actions for ${source.name}',
                    icon: Icon(
                      Icons.more_vert,
                      semanticLabel: 'Actions for ${source.name}',
                    ),
                    onSelected: (value) =>
                        _add(source, toPlaylist: value == 'playlist'),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'library',
                        enabled: !widget.library.playlists.any(
                          (p) => p.id == source.key,
                        ),
                        child: Text(
                          widget.library.playlists.any(
                                (p) => p.id == source.key,
                              )
                              ? 'Added to Your Library'
                              : 'Add to Your Library',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'playlist',
                        child: Text('Add to playlist'),
                      ),
                    ],
                  ),
          ),
        if (_loading.contains(kind))
          ContentSkeleton(
            count: _items[kind]!.isEmpty ? 2 : 1,
            artworkSize: 76.8,
            horizontalPadding: 20,
            verticalPadding: 8,
            actionWidth: 0,
            label: 'Loading music ${kind == 'album' ? 'albums' : 'playlists'}',
          ),
        if (_failed.contains(kind))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Text('Couldn’t load collections.')),
                TextButton(
                  onPressed: () => _load(kind, more: _next[kind] != null),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (!_loading.contains(kind) && _items[kind]!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'No matching ${kind == 'album' ? 'albums' : 'playlists'}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (!_loading.contains(kind) &&
            (_next[kind] != null ||
                (!_expanded.contains(kind) && _items[kind]!.length > 3)))
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: TextButton(
                onPressed: () {
                  if (!_expanded.contains(kind)) {
                    setState(() => _expanded.add(kind));
                  } else {
                    _load(kind, more: true);
                  }
                },
                child: Text('More ${kind == 'album' ? 'albums' : 'playlists'}'),
              ),
            ),
          ),
      ],
      const SizedBox(height: 12),
    ],
  );
}
