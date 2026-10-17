import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../library.dart';
import '../media/extractor.dart';
import '../media/playback.dart';
import '../theme.dart';
import '../widgets/track_row.dart';
import '../widgets/favorite_icon.dart';
import '../widgets/minimize_on_swipe.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.playback,
    required this.library,
    required this.onAdd,
    required this.onActions,
    required this.onPlay,
  });
  final Playback playback;
  final Library library;
  final Future<void> Function(Track) onAdd, onActions, onPlay;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double? _drag;
  String? _dragKey;
  String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.playback, widget.library]),
    builder: (context, _) => PlaylistThemeScope(
      themeId:
          widget.library.playlists
              .where((p) => p.id == widget.playback.playlistId)
              .firstOrNull
              ?.themeId ??
          widget.library.themeId,
      child: Builder(builder: _player),
    ),
  );

  Widget _player(BuildContext context) {
    final p = widget.playback, t = p.current;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nothing playing.')),
      );
    }
    return ThemeSystemBars(
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: Column(
                children: [
                  MinimizeOnSwipe(
                    onMinimize: () => Navigator.pop(context),
                    child: SizedBox(
                      height: constraints.maxHeight.clamp(640, 1000).toDouble(),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Collapse player',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 30,
                                  ),
                                ),
                                const Expanded(
                                  child: Text(
                                    'NOW PLAYING',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Track actions',
                                  onPressed: () => widget.onActions(t),
                                  icon: const Icon(Icons.more_horiz),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onHorizontalDragEnd: (details) {
                                if ((details.primaryVelocity ?? 0) > 300) {
                                  p.next();
                                }
                              },
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 12,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: LayoutBuilder(
                                      builder: (c, box) => Artwork(
                                        t.artwork,
                                        size: box.maxWidth,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            t.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: .65),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: widget.library.isLiked(t)
                                          ? 'Unlike'
                                          : 'Like',
                                      onPressed: () async {
                                        try {
                                          await widget.library.toggleLike(t);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(content: Text('$e')),
                                            );
                                          }
                                        }
                                      },
                                      isSelected: widget.library.isLiked(t),
                                      icon: FavoriteIcon(
                                        liked: widget.library.isLiked(t),
                                        size: 24,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Add to playlist',
                                      onPressed: () => widget.onAdd(t),
                                      icon: const Icon(Icons.playlist_add),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                if (p.error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'Couldn’t play this track. Tap play to try again.',
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                StreamBuilder<Duration>(
                                  stream: p.positionStream,
                                  builder: (context, snapshot) {
                                    final duration = p.duration.inMilliseconds
                                        .toDouble();
                                    final position =
                                        (snapshot.data ?? Duration.zero)
                                            .inMilliseconds
                                            .toDouble();
                                    final value =
                                        (_dragKey == t.key ? _drag : null) ??
                                        position;
                                    return Column(
                                      children: [
                                        Slider(
                                          value: value.clamp(
                                            0,
                                            duration > 0 ? duration : 1,
                                          ),
                                          max: duration > 0 ? duration : 1,
                                          onChangeStart: (v) {
                                            _dragKey = t.key;
                                            setState(() => _drag = v);
                                          },
                                          onChanged: duration > 0
                                              ? (v) => setState(() => _drag = v)
                                              : null,
                                          onChangeEnd: (v) {
                                            p.seek(
                                              Duration(milliseconds: v.round()),
                                              _dragKey ?? '',
                                            );
                                            setState(() => _drag = null);
                                          },
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _time(
                                                Duration(
                                                  milliseconds: value.round(),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              _time(p.duration),
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      tooltip: 'Shuffle',
                                      onPressed: p.toggleShuffle,
                                      icon: Icon(
                                        Icons.shuffle,
                                        color: p.shuffle
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : null,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Previous',
                                      padding: const EdgeInsets.all(5),
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 48,
                                            height: 48,
                                          ),
                                      onPressed: p.previous,
                                      icon: const Icon(
                                        Icons.skip_previous_rounded,
                                        size: 38,
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: p.loading ? null : p.toggle,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        shape: const CircleBorder(),
                                        padding: const EdgeInsets.all(18),
                                      ),
                                      child: p.loading
                                          ? SizedBox(
                                              width: 28,
                                              height: 28,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                                semanticsLabel: 'Loading track',
                                              ),
                                            )
                                          : Icon(
                                              p.playing
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              semanticLabel: p.playing
                                                  ? 'Pause'
                                                  : 'Play',
                                              size: 34,
                                            ),
                                    ),
                                    IconButton(
                                      tooltip: 'Next',
                                      padding: const EdgeInsets.all(5),
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 48,
                                            height: 48,
                                          ),
                                      onPressed: p.next,
                                      icon: const Icon(
                                        Icons.skip_next_rounded,
                                        size: 38,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: [
                                        'Repeat off',
                                        'Repeat track',
                                        'Repeat queue',
                                      ][p.repeat],
                                      onPressed: p.cycleRepeat,
                                      icon: Icon(
                                        p.repeat == 1
                                            ? Icons.repeat_one
                                            : Icons.repeat,
                                        color: p.repeat > 0
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: TextButton.icon(
                                        onPressed: () => _queue(context),
                                        icon: const Icon(
                                          Icons.queue_music,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'Queue · ${p.queue.length}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Copy song link',
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: t.url),
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Song link copied'),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.ios_share,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (p.related.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 28, 24, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Keep the feeling',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    ...p.related
                        .take(15)
                        .map(
                          (r) => ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            leading: Artwork(r.artwork),
                            title: Text(
                              r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(r.artist, maxLines: 1),
                            onTap: () => p.play(r, from: p.related),
                          ),
                        ),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _queue(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ListView(
        children: [
          const ListTile(
            title: Text(
              'Up next',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          ...widget.playback.queue.map(
            (t) => ListTile(
              leading: Artwork(t.artwork),
              title: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(t.artist, maxLines: 1),
              onTap: () {
                Navigator.pop(c);
                widget.playback.play(t);
              },
            ),
          ),
        ],
      ),
    ),
  );
}
