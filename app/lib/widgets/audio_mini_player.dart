import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../media/extractor.dart';
import '../media/playback.dart';
import '../media/video_source.dart';
import 'track_row.dart';
import 'media_image.dart';

class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({
    super.key,
    required this.playback,
    required this.extractor,
    required this.onOpen,
    this.visible = true,
  });
  final Playback playback;
  final Extractor extractor;
  final VoidCallback onOpen;
  final bool visible;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) {
      final track = playback.current;
      if (track == null) return const SizedBox.shrink();
      final surface = Theme.of(context).colorScheme.surface;
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (track.artwork.isNotEmpty)
                        MediaImage.network(
                          track.artwork,
                          cacheWidth: artworkDecodeWidth(
                            context,
                            MediaQuery.sizeOf(context).width,
                          ),
                          fallback: const SizedBox.shrink(),
                        ),
                      // Downloaded playback deliberately has no video widget or video request.
                      if (!playback.playingFromFile)
                        AudioVideoBackground(
                          playback: playback,
                          extractor: extractor,
                          enabled: visible,
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              surface.withValues(alpha: .9),
                              surface.withValues(alpha: .68),
                              surface.withValues(alpha: .9),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: onOpen,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Artwork(track.artwork, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (playback.loading)
                            const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            IconButton(
                              tooltip: playback.playing ? 'Pause' : 'Play',
                              onPressed: playback.toggle,
                              icon: Icon(
                                playback.playing
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                semanticLabel: playback.playing
                                    ? 'Pause'
                                    : 'Play',
                              ),
                            ),
                          IconButton(
                            tooltip: 'Next',
                            onPressed: playback.next,
                            icon: const Icon(
                              Icons.skip_next,
                              semanticLabel: 'Next',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  StreamBuilder<Duration>(
                    stream: playback.positionStream,
                    builder: (c, snap) {
                      final total = playback.duration.inMilliseconds;
                      return LinearProgressIndicator(
                        minHeight: 2,
                        value: total > 0
                            ? ((snap.data?.inMilliseconds ?? 0) / total).clamp(
                                0,
                                1,
                              )
                            : 0,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .05),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Optional silent visuals follow the audio player; they never own audio playback.
class AudioVideoBackground extends StatefulWidget {
  const AudioVideoBackground({
    super.key,
    required this.playback,
    required this.extractor,
    required this.enabled,
  });
  final Playback playback;
  final Extractor extractor;
  final bool enabled;
  @override
  State<AudioVideoBackground> createState() => _AudioVideoBackgroundState();
}

class _AudioVideoBackgroundState extends State<AudioVideoBackground>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  Timer? _syncTimer;
  String? _requestKey;
  int _generation = 0;
  bool _foreground = true, _syncing = false;
  bool get _wanted =>
      widget.enabled &&
      _foreground &&
      !widget.playback.playingFromFile &&
      !widget.playback.loading &&
      widget.playback.error == null &&
      widget.playback.current != null;
  String get _key =>
      '${widget.playback.sessionId}:${widget.playback.current?.key}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.playback.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(AudioVideoBackground old) {
    super.didUpdateWidget(old);
    if (old.playback != widget.playback) {
      old.playback.removeListener(_changed);
      widget.playback.addListener(_changed);
    }
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _changed();
  }

  void _changed() {
    if (!_wanted) {
      _clear();
      return;
    }
    if (_key != _requestKey) {
      unawaited(_load(_key));
    } else {
      unawaited(_sync());
    }
  }

  void _clear() {
    if (_requestKey == null && _video == null) return;
    ++_generation;
    _requestKey = null;
    _syncTimer?.cancel();
    final old = _video;
    _video = null;
    if (old != null) unawaited(old.dispose());
    if (mounted) setState(() {});
  }

  Future<void> _load(String key) async {
    _clear();
    _requestKey = key;
    final generation = ++_generation;
    final track = widget.playback.current!;
    VideoPlayerController? pending;
    try {
      final info = await widget.extractor.resolve(track.asVideo(true));
      if (!mounted || generation != _generation || !_wanted || _key != key) {
        return;
      }
      final controller = videoControllerFrom(info, silent: true);
      pending = controller;
      await controller.initialize();
      await controller.setVolume(0);
      if (!mounted || generation != _generation || !_wanted || _key != key) {
        await controller.dispose();
        return;
      }
      _video = controller;
      pending = null;
      await _sync();
      if (!mounted || generation != _generation) return;
      _syncTimer = Timer.periodic(
        const Duration(milliseconds: 750),
        (_) => unawaited(_sync()),
      );
      setState(() {});
    } catch (_) {
      if (pending != null) unawaited(pending.dispose());
      // An unavailable visual never interrupts the real audio stream.
    }
  }

  Future<void> _sync() async {
    final controller = _video;
    if (controller == null || _syncing || !_wanted) return;
    _syncing = true;
    try {
      final target = widget.playback.position;
      if ((controller.value.position - target).inMilliseconds.abs() > 800) {
        await controller.seekTo(target);
      }
      if (!mounted || _video != controller || !_wanted) return;
      if (widget.playback.playing && !controller.value.isPlaying) {
        await controller.play();
      }
      if (!widget.playback.playing && controller.value.isPlaying) {
        await controller.pause();
      }
    } catch (_) {
      /* Optional visuals cannot change audio state. */
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    widget.playback.removeListener(_changed);
    _syncTimer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
