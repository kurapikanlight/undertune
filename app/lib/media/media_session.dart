import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:video_player/video_player.dart';
import 'extractor.dart';
import 'playback.dart';
import 'sleep_timer.dart';

/// One Android media session; playback stays in the existing audio/video players.
class UndertuneMediaSession extends BaseAudioHandler {
  late final sleepTimer = SleepTimer(onExpired: _pauseForSleep);
  int _pauseRevision = 0;
  int get pauseRevision => _pauseRevision;
  Playback? _music;
  StreamSubscription<Duration>? _position;
  List<Track>? _publishedQueue;
  VideoPlayerController? _video;
  Track? _videoTrack;
  void Function()? _closeVideo;
  bool _videoPaused = false, _videoWasBuffering = false;
  Timer? _videoPauseDecision;
  bool get videoPlaying => _video != null && playbackState.value.playing;

  void bindMusic(Playback music) {
    unbindMusic();
    _music = music;
    music.addListener(_syncMusic);
    _syncMusic();
  }

  void unbindMusic() {
    _music?.removeListener(_syncMusic);
    unawaited(_position?.cancel());
    _position = null;
    _music = null;
    _publishedQueue = null;
  }

  void attachVideo(
    VideoPlayerController controller,
    Track track,
    void Function()? onClose,
  ) {
    _videoPauseDecision?.cancel();
    _videoPauseDecision = null;
    _video?.removeListener(_syncVideo);
    _video = controller;
    _videoPaused = !controller.value.isPlaying;
    _videoWasBuffering = false;
    _videoTrack = track;
    _closeVideo = onClose;
    controller.addListener(_syncVideo);
    queue.add([_item(track, controller.value.duration)]);
    _syncVideo();
  }

  Future<void> startVideo(
    VideoPlayerController controller,
    Track track,
    void Function()? onClose, {
    required int pauseRevision,
  }) async {
    attachVideo(controller, track, onClose);
    // Timer expiry or an explicit pause during extraction/initialization wins.
    if (pauseRevision == _pauseRevision) await play();
  }

  void detachVideo(VideoPlayerController controller) {
    if (!identical(_video, controller)) return;
    _videoPauseDecision?.cancel();
    _videoPauseDecision = null;
    controller.removeListener(_syncVideo);
    _video = null;
    _videoTrack = null;
    _closeVideo = null;
    _publishedQueue = null;
    _syncMusic();
  }

  MediaItem _item(Track track, Duration duration) => MediaItem(
    id: track.key,
    title: track.title,
    artist: track.artist,
    duration: duration > Duration.zero ? duration : null,
    artUri: track.artwork.isEmpty ? null : Uri.tryParse(track.artwork),
    isLive: track.live,
  );

  void _publishItem(MediaItem item) {
    final old = mediaItem.value;
    if (old?.id != item.id ||
        old?.duration != item.duration ||
        old?.title != item.title ||
        old?.artist != item.artist ||
        old?.artUri != item.artUri) {
      mediaItem.add(item);
    }
  }

  void _idle() {
    mediaItem.add(null);
    if (queue.value.isNotEmpty) queue.add([]);
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle),
    );
  }

  void _syncMusic() {
    if (_video != null) return;
    final music = _music;
    final track = music?.current;
    if (music == null || track == null) {
      _idle();
      return;
    }
    if (_position == null && music.hasAudio) {
      _position = music.positionStream.listen((_) => _syncMusic());
    }
    if (!identical(_publishedQueue, music.queue)) {
      _publishedQueue = music.queue;
      queue.add(
        music.queue
            .map((t) => _item(t, Duration(seconds: t.duration)))
            .toList(),
      );
    }
    _publishItem(_item(track, music.duration));
    final state = music.error != null
        ? AudioProcessingState.error
        : music.loading
        ? AudioProcessingState.loading
        : switch (music.processingState) {
            ProcessingState.idle => AudioProcessingState.idle,
            ProcessingState.loading => AudioProcessingState.loading,
            ProcessingState.buffering => AudioProcessingState.buffering,
            ProcessingState.ready => AudioProcessingState.ready,
            ProcessingState.completed => AudioProcessingState.completed,
          };
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          music.wantsToPlay ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: state,
        playing: music.error == null && music.wantsToPlay,
        updatePosition: music.position,
        bufferedPosition: music.bufferedPosition,
        speed: music.speed,
        queueIndex: music.index >= 0 ? music.index : null,
        repeatMode: music.repeat == 0
            ? AudioServiceRepeatMode.none
            : AudioServiceRepeatMode.one,
        shuffleMode: music.shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        errorCode: music.error == null ? null : 1,
        errorMessage: music.error,
      ),
    );
  }

  void _syncVideo() {
    final video = _video, track = _videoTrack;
    if (video == null || track == null) return;
    final value = video.value;
    if (value.isPlaying || value.hasError || value.isCompleted) {
      _videoPauseDecision?.cancel();
      _videoPauseDecision = null;
    } else if (_videoWasBuffering &&
        !value.isBuffering &&
        !_videoPaused &&
        playbackState.value.playing) {
      // The SDK reports buffer-end before its playing event. Coalesce that
      // short transition without restarting Android's foreground service.
      _videoPauseDecision?.cancel();
      _videoPauseDecision = Timer(const Duration(milliseconds: 100), () {
        _videoPauseDecision = null;
        _syncVideo();
      });
    }
    _videoWasBuffering = value.isBuffering;
    final playing =
        !_videoPaused &&
        !value.hasError &&
        !value.isCompleted &&
        (value.isPlaying ||
            (value.isBuffering && playbackState.value.playing) ||
            _videoPauseDecision != null);
    _publishItem(_item(track, value.duration));
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.rewind,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: value.hasError
            ? AudioProcessingState.error
            : !value.isInitialized
            ? AudioProcessingState.loading
            : value.isCompleted
            ? AudioProcessingState.completed
            : value.isBuffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: playing,
        updatePosition: value.position,
        bufferedPosition: value.buffered.isEmpty
            ? Duration.zero
            : value.buffered.last.end,
        speed: value.playbackSpeed,
        errorCode: value.hasError ? 1 : null,
        errorMessage: value.errorDescription,
      ),
    );
  }

  @override
  Future<void> play() async {
    final video = _video;
    if (video != null) {
      _videoPaused = false;
      if (video.value.position >= video.value.duration) {
        await video.seekTo(Duration.zero);
      }
      await video.play();
      _syncVideo();
    } else {
      await _music?.resume();
    }
  }

  Future<void> _pauseForSleep() async {
    final hadVideo = _video != null;
    await pause();
    if (hadVideo) await _music?.pause();
  }

  @override
  Future<void> pause() async {
    ++_pauseRevision;
    if (_video != null) {
      _videoPaused = true;
      _videoPauseDecision?.cancel();
      _videoPauseDecision = null;
      await _video!.pause();
      _syncVideo();
    } else {
      await _music?.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    final video = _video;
    if (video != null) {
      await video.seekTo(position);
    } else {
      final music = _music;
      if (music?.current != null) {
        await music!.seek(position, music.current!.key);
      }
    }
    _video != null ? _syncVideo() : _syncMusic();
  }

  Future<void> _jump(int seconds) {
    final target =
        playbackState.value.updatePosition + Duration(seconds: seconds);
    final end = mediaItem.value?.duration;
    return seek(
      target < Duration.zero
          ? Duration.zero
          : end != null && target > end
          ? end
          : target,
    );
  }

  @override
  Future<void> rewind() => _jump(-10);
  @override
  Future<void> fastForward() => _jump(10);
  @override
  Future<void> skipToNext() async {
    if (_video == null) await _music?.next();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_video == null) await _music?.previous();
  }

  @override
  Future<void> stop() async {
    ++_pauseRevision;
    sleepTimer.cancel();
    if (_video != null) {
      await _video!.pause();
      _closeVideo?.call();
      if (_video != null) detachVideo(_video!);
    } else {
      await _music?.stop();
    }
    _idle();
  }

  // Removing a task removes the window, not the active media session.
  @override
  Future<void> onTaskRemoved() async {
    if (!playbackState.value.playing) await stop();
  }
}
