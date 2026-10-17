import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../library.dart';
import '../media/downloads.dart';
import '../media/extractor.dart';
import '../media/playback.dart';
import '../media/playlist_downloads.dart';
import '../widgets/playlist_download_controls.dart';
import '../theme.dart';
import '../widgets/playlist_cover.dart';
import '../widgets/track_row.dart';
import '../widgets/loading.dart';
import '../widgets/branding.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({
    super.key,
    required this.id,
    required this.library,
    required this.extractor,
    required this.playback,
    required this.downloads,
    required this.onPlay,
    required this.onActions,
    required this.onDeleted,
    this.playlistDownloads,
  });
  final String id;
  final PlaylistDownloads? playlistDownloads;
  final Library library;
  final Extractor extractor;
  final Playback playback;
  final Downloads downloads;
  final void Function(Track, List<Track>) onPlay;
  final ValueChanged<Track> onActions;
  final VoidCallback onDeleted;
  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late final PlaylistDownloads _offline;
  @override
  void initState() {
    super.initState();
    _offline =
        widget.playlistDownloads ??
        PlaylistDownloads(widget.library, widget.downloads, widget.extractor);
  }

  @override
  void dispose() {
    if (widget.playlistDownloads == null) _offline.dispose();
    super.dispose();
  }

  bool _editing = false;
  String? _allSort;
  bool get _liked => widget.id == 'liked';
  bool get _all => widget.id == 'tracks';
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _add(List<Track> tracks) async {
    final selected = await showModalBottomSheet<List<Track>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SizedBox(
        height: MediaQuery.sizeOf(c).height * .8,
        child: _AddTracks(
          library: widget.library,
          extractor: widget.extractor,
          existing: tracks.map((t) => t.key).toSet(),
        ),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    await _run(() async {
      if (_all) {
        await widget.library.saveTracks(selected);
      } else if (_liked) {
        for (final track in selected) {
          if (!widget.library.isLiked(track)) {
            await widget.library.toggleLike(track);
          }
        }
      } else {
        await widget.library.addTracksToPlaylist(widget.id, selected);
      }
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: const Text(
          'Your liked songs and downloaded files will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() async {
        await widget.library.deletePlaylist(widget.id);
        if (mounted) widget.onDeleted();
      });
    }
  }

  Widget _customHeader(
    Playlist playlist,
    List<Track> tracks,
    String metadata,
    bool currentQueue,
  ) {
    final playback = widget.playback;
    final playing = currentQueue && playback.playing;
    return Column(
      children: [
        Padding(
          key: const ValueKey('playlist-hero'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: LayoutBuilder(
                  builder: (c, box) => PlaylistCover(
                    tracks: tracks,
                    coverPath: playlist.coverPath,
                    sourceArtwork: playlist.sourceArtwork,
                    size: (box.maxWidth * .76).clamp(140.0, 240.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: playlist.collectionKind == 'album'
                        ? Text(
                            playlist.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          )
                        : playlist.sourceUrl != null
                        ? MediaHeading(playlist.name, fontSize: 48)
                        : Text(
                            playlist.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.merge(
                                  feelfreeHeadingStyle.copyWith(fontSize: 48),
                                ),
                          ),
                  ),
                  IconButton(
                    tooltip: 'Edit playlist',
                    onPressed: () => showDialog<String>(
                      context: context,
                      builder: (_) => PlaylistEditor(
                        library: widget.library,
                        playlist: playlist,
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (playlist.sourceArtist?.isNotEmpty == true)
                Text(
                  '${playlist.collectionKind == 'album' ? 'Album' : 'Playlist'} · ${playlist.sourceArtist}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Text(metadata, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  final actionWidth = ((box.maxWidth - 51.2) / 5).clamp(
                    0.0,
                    48.0,
                  );
                  Widget action(Widget child) =>
                      SizedBox(width: actionWidth, child: child);
                  return Row(
                    children: [
                      action(
                        IconButton(
                          tooltip: 'Shuffle',
                          onPressed: tracks.isEmpty
                              ? null
                              : () {
                                  final shuffled = List<Track>.of(tracks)
                                    ..shuffle();
                                  widget.onPlay(shuffled.first, shuffled);
                                },
                          icon: const Icon(Icons.shuffle),
                        ),
                      ),
                      action(
                        PopupMenuButton<String>(
                          tooltip: 'Sort playlist',
                          icon: const Icon(Icons.sort),
                          onSelected: (value) => _run(
                            () => widget.library.sortPlaylist(widget.id, value),
                          ),
                          itemBuilder: (_) =>
                              ['Title A–Z', 'Artist A–Z', 'Reverse order']
                                  .map(
                                    (s) =>
                                        PopupMenuItem(value: s, child: Text(s)),
                                  )
                                  .toList(),
                        ),
                      ),
                      action(
                        IconButton(
                          tooltip: _editing ? 'Done editing' : 'Edit tracks',
                          onPressed: () => setState(() => _editing = !_editing),
                          icon: Icon(
                            _editing ? Icons.check : Icons.playlist_play,
                          ),
                        ),
                      ),
                      action(
                        PlaylistDownloadControls(
                          id: widget.id,
                          downloads: _offline,
                        ),
                      ),
                      action(
                        PopupMenuButton<String>(
                          tooltip: 'Playlist actions',
                          onSelected: (_) => _delete(),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete playlist'),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SizedBox.square(
                        dimension: 51.2,
                        child: IconButton.filled(
                          tooltip: playing ? 'Pause playlist' : 'Play playlist',
                          onPressed: tracks.isEmpty
                              ? null
                              : () => currentQueue
                                    ? playback.toggle()
                                    : widget.onPlay(
                                        tracks.first,
                                        List.of(tracks),
                                      ),
                          style: IconButton.styleFrom(
                            shape: const CircleBorder(),
                            elevation: 6,
                            shadowColor: Colors.black38,
                          ),
                          icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 27.2,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: Icon(
            Icons.add_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Add track'),
          onTap: () => _add(tracks),
        ),
        if (_editing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('Drag to reorder or remove tracks.'),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.library,
      widget.playback,
      widget.downloads,
    ]),
    builder: (context, _) {
      final library = widget.library;
      final playlist = library.playlists
          .where((p) => p.id == widget.id)
          .firstOrNull;
      if (!_liked && !_all && playlist == null) {
        return const Center(child: Text('Playlist no longer exists.'));
      }
      final tracks = _liked
          ? library.liked
          : _all
          ? library.tracks
          : playlist!.tracks;
      if (_all && _allSort != null) {
        if (_allSort == 'Reverse order') {
          final copy = tracks.reversed.toList();
          tracks
            ..clear()
            ..addAll(copy);
        } else {
          tracks.sort(
            (a, b) => (_allSort == 'Artist A–Z' ? a.artist : a.title)
                .toLowerCase()
                .compareTo(
                  (_allSort == 'Artist A–Z' ? b.artist : b.title).toLowerCase(),
                ),
          );
        }
      }
      final name = _liked
          ? 'Liked'
          : _all
          ? 'Tracks'
          : playlist!.name;
      final total = tracks.fold<int>(
        0,
        (sum, t) => sum + (t.duration > 0 ? t.duration : 0),
      );
      final partial = tracks.any((t) => t.duration <= 0);
      final duration = tracks.isEmpty
          ? '0 min'
          : total == 0
          ? 'Duration unavailable'
          : '${total >= 3600 ? '${total ~/ 3600} hr ' : ''}${(total ~/ 60) % 60} min${total < 60 ? ' ${total % 60} sec' : ''}${partial ? '+' : ''}';
      final playback = widget.playback;
      final currentQueue =
          playback.current != null &&
          playback.queue.length == tracks.length &&
          tracks.any((t) => t.key == playback.current!.key) &&
          tracks.every((t) => playback.queue.any((q) => q.key == t.key));
      final metadata =
          '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'} · $duration';
      final list = ReorderableListView.builder(
        key: PageStorageKey('playlist-${widget.id}'),
        padding: const EdgeInsets.only(bottom: 28),
        buildDefaultDragHandles: false,
        onReorder: (oldIndex, newIndex) =>
            _run(() => library.reorderPlaylist(widget.id, oldIndex, newIndex)),
        header: playlist != null
            ? _customHeader(playlist, tracks, metadata, currentQueue)
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (c, box) => Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_all)
                            Artwork(
                              '',
                              size:
                                  box.maxWidth < 310 ||
                                      MediaQuery.textScalerOf(c).scale(1) > 1.4
                                  ? 88
                                  : 120,
                              icon: Icons.headphones_rounded,
                            )
                          else
                            PlaylistCover(
                              tracks: tracks,
                              coverPath: playlist?.coverPath,
                              liked: _liked,
                              size:
                                  box.maxWidth < 310 ||
                                      MediaQuery.textScalerOf(c).scale(1) > 1.4
                                  ? 88
                                  : 120,
                            ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.merge(
                                        feelfreeHeadingStyle.copyWith(
                                          fontSize: 40,
                                        ),
                                      ),
                                ),
                                if (playlist != null)
                                  TextButton.icon(
                                    onPressed: () => showDialog<String>(
                                      context: context,
                                      builder: (_) => PlaylistEditor(
                                        library: library,
                                        playlist: playlist,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Edit'),
                                  ),
                              ],
                            ),
                          ),
                          if (playlist != null)
                            PopupMenuButton<String>(
                              tooltip: 'Playlist actions',
                              onSelected: (_) => _delete(),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete playlist'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'} · $duration',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: tracks.isEmpty
                              ? null
                              : () => currentQueue
                                    ? playback.toggle()
                                    : widget.onPlay(
                                        tracks.first,
                                        List.of(tracks),
                                      ),
                          icon: Icon(
                            currentQueue && playback.playing
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          label: Text(
                            currentQueue && playback.playing ? 'Pause' : 'Play',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: tracks.isEmpty
                              ? null
                              : () {
                                  final shuffled = List<Track>.of(tracks)
                                    ..shuffle();
                                  widget.onPlay(shuffled.first, shuffled);
                                },
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Shuffle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => _add(tracks),
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Sort playlist',
                          onSelected: (value) => _all
                              ? setState(() => _allSort = value)
                              : _run(
                                  () => library.sortPlaylist(widget.id, value),
                                ),
                          itemBuilder: (_) =>
                              ['Title A–Z', 'Artist A–Z', 'Reverse order']
                                  .map(
                                    (s) =>
                                        PopupMenuItem(value: s, child: Text(s)),
                                  )
                                  .toList(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sort, size: 20),
                                SizedBox(width: 8),
                                Text('Sort'),
                              ],
                            ),
                          ),
                        ),
                        PlaylistDownloadControls(
                          id: widget.id,
                          downloads: _offline,
                        ),
                        if (!_all)
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _editing = !_editing),
                            icon: Icon(
                              _editing ? Icons.check : Icons.edit_outlined,
                            ),
                            label: Text(_editing ? 'Done' : 'Edit'),
                          ),
                      ],
                    ),
                    if (_editing)
                      Text(
                        'Drag to reorder or remove tracks.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          final row = TrackRow(
            track: track,
            artworkSize: 48,
            horizontalPadding: 20,
            verticalPadding: 4,
            artworkGap: 10,
            titleLines: 2,
            showDuration: true,
            showFavorite: false,
            downloaded: widget.downloads.localFor(track) != null,
            active: playback.current?.key == track.key,
            liked: library.isLiked(track),
            onTap: () => widget.onPlay(track, List.of(tracks)),
            onLike: () => _run(() => library.toggleLike(track)),
            onMore: () => widget.onActions(track),
          );
          return Row(
            key: ValueKey(track.key),
            children: [
              if (_editing)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ReorderableDragStartListener(
                    index: index,
                    child: const SizedBox(
                      width: 32,
                      height: 56,
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ),
              Expanded(child: row),
              if (_editing)
                IconButton(
                  tooltip: 'Remove ${track.title}',
                  onPressed: () => _run(
                    () => _liked
                        ? library.toggleLike(track)
                        : library.removeFromPlaylist(widget.id, track),
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
            ],
          );
        },
        footer: tracks.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No tracks yet. Tap Add to find music for this playlist.',
                  textAlign: TextAlign.center,
                ),
              )
            : null,
      );
      if (playlist == null) return list;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: list,
      );
    },
  );
}

class PlaylistEditor extends StatefulWidget {
  const PlaylistEditor({super.key, required this.library, this.playlist});
  final Library library;
  final Playlist? playlist;
  @override
  State<PlaylistEditor> createState() => _PlaylistEditorState();
}

class _PlaylistEditorState extends State<PlaylistEditor> {
  static const _images = MethodChannel('undertune/playlist_images');
  late final _name = TextEditingController(text: widget.playlist?.name ?? '');
  late String? _cover = widget.playlist?.coverPath;
  late String _theme =
      Atmosphere.all.any((t) => t.id == widget.playlist?.themeId)
      ? widget.playlist!.themeId!
      : '';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = await _images.invokeMethod<String>('pick');
      if (mounted && path != null) setState(() => _cover = path);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open that image. Try another file.');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a playlist name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final themeId = _theme.isEmpty ? null : _theme;
      final playlist = widget.playlist;
      final String id;
      if (playlist == null) {
        id = await widget.library.createPlaylist(_name.text, themeId: themeId);
      } else {
        id = playlist.id;
        await widget.library.editPlaylist(
          id,
          name: _name.text,
          coverPath: _cover,
          themeId: themeId,
        );
      }
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.playlist == null ? 'New playlist' : 'Edit playlist',
      style: widget.playlist == null
          ? feelfreeHeadingStyle.copyWith(fontSize: 36)
          : null,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.playlist != null) ...[
          PlaylistCover(
            tracks: widget.playlist!.tracks,
            coverPath: _cover,
            sourceArtwork: widget.playlist!.sourceArtwork,
            size: 128,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Choose image'),
          ),
          if (_cover != null)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _cover = null),
              child: const Text('Use automatic cover'),
            ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _name,
          autofocus: widget.playlist == null,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Playlist name'),
          onSubmitted: (_) {
            if (!_busy) _save();
          },
        ),
        const SizedBox(height: 12),
        PlaylistThemePicker(
          value: _theme,
          onChanged: _busy ? null : (value) => setState(() => _theme = value),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
    ],
  );
}

class _AddTracks extends StatefulWidget {
  const _AddTracks({
    required this.library,
    required this.extractor,
    required this.existing,
  });
  final Library library;
  final Extractor extractor;
  final Set<String> existing;
  @override
  State<_AddTracks> createState() => _AddTracksState();
}

class _AddTracksState extends State<_AddTracks> {
  final _query = TextEditingController();
  final _selected = <String, Track>{};
  List<Track>? _results;
  bool _busy = false;
  String? _error;
  int _request = 0;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    final request = ++_request;
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _busy = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.extractor.search(query);
      if (!mounted || request != _request) return;
      setState(() {
        _results = page.tracks;
        _busy = false;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _error = 'Search failed. Try again.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final tracks =
        (_results ?? [...widget.library.tracks, ...widget.library.history])
            .where(
              (t) =>
                  !t.live &&
                  !widget.existing.contains(t.key) &&
                  seen.add(t.key),
            )
            .toList();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Text('Add tracks', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search music',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Find tracks',
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            Row(
              children: [
                Expanded(child: Text('${_selected.length} selected')),
                TextButton(
                  onPressed: tracks.isEmpty
                      ? null
                      : () => setState(() {
                          for (final t in tracks) {
                            _selected[t.key] = t;
                          }
                        }),
                  child: const Text('Select all'),
                ),
              ],
            ),
            if (_error != null) Text(_error!),
            Expanded(
              child: tracks.isEmpty && _busy
                  ? ListView(
                      children: const [
                        ContentSkeleton(
                          artworkSize: 44,
                          horizontalPadding: 16,
                          verticalPadding: 12,
                          actionWidth: 48,
                          titleLines: 2,
                          label: 'Searching for tracks',
                        ),
                      ],
                    )
                  : tracks.isEmpty
                  ? Center(
                      child: Text(
                        _results == null
                            ? 'Search for music to add.'
                            : 'No new tracks found.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (c, i) {
                        final track = tracks[i];
                        return CheckboxListTile(
                          value: _selected.containsKey(track.key),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              _selected[track.key] = track;
                            } else {
                              _selected.remove(track.key);
                            }
                          }),
                          secondary: Artwork(track.artwork, size: 44),
                          title: Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.values.toList()),
                child: Text('Add ${_selected.length} tracks'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
