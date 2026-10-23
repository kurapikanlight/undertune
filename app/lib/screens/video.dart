import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../library.dart';
import '../media/extractor.dart';
import '../media/media_session.dart';
import '../media/segments.dart';
import '../media/video_source.dart';
import '../media/video_catalog.dart';
import '../widgets/video_catalog_widgets.dart';
import '../widgets/loading.dart';
import '../widgets/media_image.dart';
import '../widgets/video_card.dart';
import '../widgets/minimize_on_swipe.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({
    super.key,
    required this.track,
    required this.extractor,
    this.sponsorBlock = false,
    this.library,
    this.onSave,
    this.onActions,
    this.minimized = false,
    this.onMinimize,
    this.onExpand,
    this.onClose,
    this.loadRequest = 0,
    this.localFor,
    this.background,
    this.onChannel,
  });
  final Track track;
  final ValueChanged<VideoChannel>? onChannel;
  final UndertuneMediaSession? background;
  final Extractor extractor;
  final String? Function(Track)? localFor;
  final bool sponsorBlock;
  final bool minimized;
  final int loadRequest;
  final VoidCallback? onMinimize, onExpand, onClose;
  final Library? library;
  final Future<void> Function(Track)? onSave, onActions;
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with WidgetsBindingObserver {
  late Track _track = widget.track;
  String _channelUrl = '', _channelArtwork = '';
  VideoPlayerController? _video;
  List<Track> _related = [];
  bool _metadataLoading = false;
  SegmentSkipper? _skipper;
  Timer? _hideControls;
  final _chrome = ValueNotifier<int>(0);
  bool _seeking = false, _controls = true, _fullscreenOpen = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _hideControls?.cancel();
      if (widget.background == null) _video?.pause();
    }
  }

  @override
  void didUpdateWidget(VideoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadRequest != widget.loadRequest ||
        oldWidget.track.key != widget.track.key) {
      _load(widget.track);
    }
  }

  void _minimize() {
    if (widget.onMinimize != null) {
      widget.onMinimize!();
    } else {
      Navigator.pop(context);
    }
  }

  void _progress() {
    final controller = _video;
    if (_seeking ||
        controller == null ||
        !controller.value.isPlaying ||
        !mounted) {
      return;
    }
    final target = _skipper?.target(controller.value.position);
    if (target != null && target < controller.value.duration) {
      _seeking = true;
      controller.seekTo(target).whenComplete(() => _seeking = false);
    }
  }

  void _showControls() {
    _hideControls?.cancel();
    if (mounted) {
      setState(() => _controls = true);
      _chrome.value++;
    }
    _hideControls = Timer(const Duration(seconds: 3), () {
      if (mounted && _video?.value.isPlaying == true) {
        setState(() => _controls = false);
        _chrome.value++;
      }
    });
  }

  Future<void> _load([Track? next]) async {
    final generation = ++_generation;
    final pauseRevision = widget.background?.pauseRevision ?? 0;
    _hideControls?.cancel();
    final old = _video;
    setState(() {
      if (next != null) _track = next.asVideo(true);
      _channelUrl = _track.channelUrl;
      _channelArtwork = _track.channelArtwork;
      _video = null;
      _error = null;
      _related = [];
      _metadataLoading = true;
      _skipper = null;
      _controls = true;
    });
    if (old != null) widget.background?.detachVideo(old);
    await old?.dispose();
    VideoPlayerController? pending;
    try {
      final local = widget.localFor?.call(_track);
      final info = local == null
          ? await widget.extractor.resolve(_track)
          : <String, dynamic>{'localUrl': local, 'related': []};
      if (_track.live && info['live'] == false) {
        await widget.library?.removeLive(_track);
        throw StateError('This broadcast has ended.');
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _metadataLoading = false;
        _channelUrl = info['channelUrl'] as String? ?? _channelUrl;
        _channelArtwork = info['channelArtwork'] as String? ?? _channelArtwork;
        _related = (info['related'] as List? ?? [])
            .map((e) => Track.fromJson(e as Map).asVideo(true))
            .toList();
      });
      final controller = videoControllerFrom(
        info,
        background: widget.background != null,
      );
      pending = controller;
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      _video = controller;
      pending = null;
      controller.addListener(_progress);
      if (widget.background != null) {
        await widget.background!.startVideo(
          controller,
          _track,
          widget.onClose,
          pauseRevision: pauseRevision,
        );
      } else {
        await controller.play();
      }
      if (!mounted || generation != _generation) return;
      _showControls();
      unawaited(
        widget.library?.played(_track).catchError((Object _) {}) ??
            Future<void>.value(),
      );
      if (widget.sponsorBlock && local == null) {
        unawaited(
          SegmentSkipper.load(_track.url)
              .then((value) {
                if (mounted && generation == _generation) _skipper = value;
              })
              .catchError((Object _) {}),
        );
      }
    } catch (_) {
      await pending?.dispose();
      if (mounted && generation == _generation) {
        setState(() {
          _metadataLoading = false;
          _error = 'This video couldn’t be played.';
        });
      }
    }
  }

  Future<void> _toggle() async {
    final controller = _video;
    if (controller == null) return;
    if (widget.background != null) {
      if (widget.background!.videoPlaying) {
        await widget.background!.pause();
      } else {
        await widget.background!.play();
      }
    } else if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
    _showControls();
  }

  void _jump(int seconds) {
    final controller = _video;
    if (controller == null) return;
    final value = (controller.value.position.inSeconds + seconds).clamp(
      0,
      controller.value.duration.inSeconds,
    );
    controller.seekTo(Duration(seconds: value));
    _showControls();
  }

  Future<void> _fullscreen() async {
    if (_fullscreenOpen) return;
    _fullscreenOpen = true;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) {
      await _restoreSystemUi();
      return;
    }
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (c) => Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Center(
                child: MinimizeOnSwipe(
                  onMinimize: () {
                    Navigator.pop(c);
                    _minimize();
                  },
                  child: _video == null
                      ? const SizedBox.shrink()
                      : ValueListenableBuilder(
                          valueListenable: _video!,
                          builder: (_, _, _) => _surface(fullscreen: true),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      await _restoreSystemUi();
      _showControls();
    }
  }

  Future<void> _restoreSystemUi() async {
    _fullscreenOpen = false;
    await SystemChrome.setPreferredOrientations([]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    ++_generation;
    _hideControls?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_video != null) widget.background?.detachVideo(_video!);
    _video?.dispose();
    _chrome.dispose();
    super.dispose();
  }

  Widget _surface({bool fullscreen = false}) => ValueListenableBuilder(
    valueListenable: _chrome,
    builder: (_, _, _) => _surfaceContent(fullscreen: fullscreen),
  );
  Widget _surfaceContent({bool fullscreen = false}) {
    final controller = _video;
    final value = controller?.value;
    final ready = value?.isInitialized == true;
    final visible = _controls || value?.isPlaying != true;
    return AspectRatio(
      aspectRatio: fullscreen && ready ? value!.aspectRatio : 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_controls) {
              setState(() => _controls = false);
              _chrome.value++;
            } else {
              _showControls();
            }
          },
          onDoubleTapDown: (d) {
            final box = context.findRenderObject() as RenderBox?;
            _jump(
              d.localPosition.dx <
                      (box?.size.width ?? MediaQuery.sizeOf(context).width) / 2
                  ? -10
                  : 10,
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ready)
                Center(
                  child: AspectRatio(
                    aspectRatio: value!.aspectRatio,
                    child: VideoPlayer(controller!),
                  ),
                )
              else if (_track.artwork.isNotEmpty)
                Opacity(
                  opacity: .35,
                  child: LayoutBuilder(
                    builder: (context, constraints) => MediaImage.network(
                      _track.artwork,
                      cacheWidth: artworkDecodeWidth(
                        context,
                        constraints.maxWidth,
                      ),
                      fallback: const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (_error != null || value?.hasError == true)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'This video couldn’t be played.',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!ready || value!.isBuffering)
                const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (visible && _error == null && value?.hasError != true) ...[
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black45,
                          Colors.transparent,
                          Colors.black87,
                        ],
                        stops: [0, .45, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 4,
                  child: IconButton(
                    tooltip: fullscreen ? 'Exit fullscreen' : 'Back',
                    color: Colors.white,
                    icon: Icon(
                      fullscreen ? Icons.fullscreen_exit : Icons.arrow_back,
                    ),
                    onPressed: fullscreen
                        ? () => Navigator.pop(context)
                        : _minimize,
                  ),
                ),
                if (widget.onActions != null)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton(
                      tooltip: 'Video actions',
                      color: Colors.white,
                      icon: const Icon(
                        Icons.more_horiz,
                        semanticLabel: 'Video actions',
                      ),
                      onPressed: () => widget.onActions!(_track),
                    ),
                  ),
                if (ready && !value!.isBuffering)
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Rewind 10 seconds',
                          onPressed: () => _jump(-10),
                          color: Colors.white,
                          icon: const Icon(Icons.replay_10, size: 30),
                        ),
                        const SizedBox(width: 22),
                        IconButton(
                          tooltip:
                              (widget.background?.videoPlaying ??
                                  value.isPlaying)
                              ? 'Pause video'
                              : 'Play video',
                          onPressed: _toggle,
                          color: Colors.white,
                          icon: Icon(
                            (widget.background?.videoPlaying ?? value.isPlaying)
                                ? Icons.pause_rounded
                                : value.position >= value.duration
                                ? Icons.replay_rounded
                                : Icons.play_arrow_rounded,
                            size: 48,
                          ),
                        ),
                        const SizedBox(width: 22),
                        IconButton(
                          tooltip: 'Forward 10 seconds',
                          onPressed: () => _jump(10),
                          color: Colors.white,
                          icon: const Icon(Icons.forward_10, size: 30),
                        ),
                      ],
                    ),
                  ),
                if (ready)
                  Positioned(
                    left: 12,
                    right: 4,
                    bottom: 0,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              '${mediaTime(value!.position.inSeconds)} / ${mediaTime(value.duration.inSeconds)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: fullscreen
                                  ? 'Exit fullscreen'
                                  : 'Fullscreen',
                              color: Colors.white,
                              icon: Icon(
                                fullscreen
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                              ),
                              onPressed: fullscreen
                                  ? () => Navigator.pop(context)
                                  : _fullscreen,
                            ),
                          ],
                        ),
                        VideoProgressIndicator(
                          controller!,
                          allowScrubbing: true,
                          padding: const EdgeInsets.only(right: 8, bottom: 8),
                          colors: VideoProgressColors(
                            playedColor: Theme.of(context).colorScheme.primary,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (!visible && ready)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: VideoProgressIndicator(
                    controller!,
                    allowScrubbing: false,
                    colors: VideoProgressColors(
                      playedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              if (_error != null || value?.hasError == true)
                Positioned(
                  left: 4,
                  top: 4,
                  child: IconButton(
                    tooltip: 'Back',
                    color: Colors.white,
                    onPressed: fullscreen
                        ? () => Navigator.pop(context)
                        : _minimize,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.minimized
      ? _miniPlayer()
      : Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (!_fullscreenOpen)
                  MinimizeOnSwipe(
                    onMinimize: _minimize,
                    child: _video == null
                        ? _surface()
                        : ValueListenableBuilder(
                            valueListenable: _video!,
                            builder: (_, _, _) => _surface(),
                          ),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                12,
                              ),
                              child: Text(
                                _track.title,
                                style: const TextStyle(
                                  fontSize: 19,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap:
                                    _channelUrl.isEmpty ||
                                        widget.onChannel == null
                                    ? null
                                    : () => widget.onChannel!(_channelSource()),
                                child: Row(
                                  children: [
                                    ChannelAvatar(
                                      channel: _channelSource(),
                                      size: 34,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                children: [
                                  if (widget.library != null && !_track.live)
                                    ListenableBuilder(
                                      listenable: widget.library!,
                                      builder: (c, _) => ActionChip(
                                        avatar: Icon(
                                          widget.library!.isLiked(_track)
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 17,
                                        ),
                                        label: Text(
                                          widget.library!.isLiked(_track)
                                              ? 'Liked'
                                              : 'Like',
                                        ),
                                        onPressed: () async {
                                          try {
                                            await widget.library!.toggleLike(
                                              _track,
                                            );
                                          } catch (_) {
                                            if (mounted) {
                                              _message(
                                                'Couldn’t save this video.',
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  if (widget.onSave != null) ...[
                                    const SizedBox(width: 8),
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.playlist_add,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _track.live
                                            ? (widget.library?.liveStreams.any(
                                                        (t) =>
                                                            t.key == _track.key,
                                                      ) ==
                                                      true
                                                  ? 'Remove from Live'
                                                  : 'Add to Live')
                                            : 'Save',
                                      ),
                                      onPressed: () => widget.onSave!(_track),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  ActionChip(
                                    avatar: const Icon(Icons.link, size: 17),
                                    label: const Text('Copy link'),
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: _track.url),
                                      );
                                      if (mounted) _message('Link copied');
                                    },
                                  ),
                                  if (widget.onActions != null) ...[
                                    const SizedBox(width: 8),
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.more_horiz,
                                        size: 18,
                                      ),
                                      label: const Text('More'),
                                      onPressed: () =>
                                          widget.onActions!(_track),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_related.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                          child: Text(
                            'Up next',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (_metadataLoading && _error == null)
                        const ContentSkeleton(video: true, count: 2),
                      ..._related
                          .take(12)
                          .map(
                            (t) => VideoCard(
                              track: t,
                              onTap: () => _load(t),
                              onMore: () => widget.onActions?.call(t),
                              onChannel:
                                  t.channelUrl.isEmpty ||
                                      widget.onChannel == null
                                  ? null
                                  : () => widget.onChannel!(
                                      VideoChannel(
                                        id: t.channelUrl,
                                        url: t.channelUrl,
                                        name: t.artist,
                                        artwork: t.channelArtwork,
                                        serviceId: t.serviceId,
                                      ),
                                    ),
                            ),
                          ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
  VideoChannel _channelSource() => VideoChannel(
    id: _channelUrl,
    url: _channelUrl,
    name: _track.artist,
    artwork: _channelArtwork,
    serviceId: _track.serviceId,
  );

  Widget _miniPlayer() => Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        top: 10,
        right: 10,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 8,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onExpand,
            child: Semantics(
              label: 'Expand video: ${_track.title}',
              button: true,
              child: ColoredBox(
                color: Colors.black,
                child: _video == null
                    ? Center(
                        child: _error == null
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              )
                            : IconButton(
                                tooltip: 'Retry video',
                                onPressed: _load,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  semanticLabel: 'Retry video',
                                ),
                              ),
                      )
                    : ValueListenableBuilder(
                        valueListenable: _video!,
                        builder: (_, value, _) => Stack(
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: AspectRatio(
                                aspectRatio: value.aspectRatio,
                                child: VideoPlayer(_video!),
                              ),
                            ),
                            if (!(widget.background?.videoPlaying ??
                                value.isPlaying))
                              Center(
                                child: IconButton(
                                  tooltip: 'Play video',
                                  onPressed: _toggle,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black45,
                                  ),
                                  icon: Icon(
                                    value.position >= value.duration
                                        ? Icons.replay
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    semanticLabel: 'Play video',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        child: IconButton(
          tooltip: 'Close video',
          onPressed: widget.onClose,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          padding: const EdgeInsets.all(4),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .12),
              ),
            ),
            child: const Icon(
              Icons.close,
              size: 19,
              semanticLabel: 'Close video',
            ),
          ),
        ),
      ),
    ],
  );
  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
