import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../library.dart';
import 'extractor.dart';
import 'stream_selection.dart';

class Playback extends ChangeNotifier {
  Playback(this.extractor, this.library, {this.localFor});
  final String? Function(Track)? localFor;
  final Extractor extractor;
  final Library library;
  AudioPlayer? _audio;
  AudioPlayer get audio => _audio ??= _createPlayer();
  AudioPlayer _createPlayer() {
    final player = AudioPlayer(useProxyForRequestHeaders: false);
    var previousProcessingState = ProcessingState.idle;
    player.playerStateStream.listen((state) {
      if (_disposed) return;
      // Stopping a completed source also changes its playing flag. Advance only
      // on entering completed, so that second state event cannot skip a song.
      final completed =
          state.processingState == ProcessingState.completed &&
          previousProcessingState != ProcessingState.completed;
      previousProcessingState = state.processingState;
      notifyListeners();
      if (completed && _playWhenReady) {
        if (repeat > 0) {
          unawaited(_replayCurrent(player));
        } else {
          unawaited(next(automatic: true));
        }
      }
    });
    player.errorStream.listen((event) {
      if (_disposed) return;
      error = 'Playback failed: ${event.message}';
      notifyListeners();
    });
    return player;
  }

  Future<void> _replayCurrent(AudioPlayer player) async {
    final generation = _generation;
    _restarting = true;
    if (repeat == 1) repeat = 0;
    notifyListeners();
    try {
      await player.seek(Duration.zero);
      if (!_disposed && generation == _generation && _playWhenReady) {
        unawaited(player.play());
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _playWhenReady = false;
        error = 'Couldn’t replay this track.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _restarting = false;
        notifyListeners();
      }
    }
  }

  Track? current;
  String? playlistId;
  List<Track> queue = [], related = [];
  int index = 0, repeat = 0, _generation = 0;
  bool loading = false, shuffle = false;
  bool _playWhenReady = false, _restarting = false, _disposed = false;
  // Keep the foreground service active across EOF and the next source load.
  // A user pause or the actual end of the queue still releases playback.
  bool get wantsToPlay =>
      loading ||
          _restarting ||
          (processingState == ProcessingState.completed && _continues)
      ? _playWhenReady
      : playing;
  bool get _continues =>
      repeat > 0 ||
      (queue.isNotEmpty &&
          ((shuffle && queue.length > 1) || index + 1 < queue.length));
  bool playingFromFile = false;
  int get sessionId => _generation;
  Duration get position => _audio?.position ?? Duration.zero;
  String? error;
  bool get playing =>
      (_audio?.playing ?? false) &&
      _audio?.processingState != ProcessingState.completed;
  Duration get duration => _audio?.duration ?? Duration.zero;
  bool get hasAudio => _audio != null;
  ProcessingState get processingState =>
      _audio?.processingState ?? ProcessingState.idle;
  Duration get bufferedPosition => _audio?.bufferedPosition ?? Duration.zero;
  double get speed => _audio?.speed ?? 1;
  Stream<Duration> get positionStream =>
      _audio?.positionStream ?? const Stream<Duration>.empty();
  Future<void> play(
    Track track, {
    List<Track>? from,
    String? playlistId,
  }) async {
    final generation = ++_generation;
    _restarting = false;
    if (repeat == 1 && current?.key != track.key) repeat = 0;
    current = track;
    final local = localFor?.call(track);
    playingFromFile = local != null;
    if (from != null) {
      this.playlistId = playlistId;
      queue = List.of(from);
      index = queue.indexWhere((e) => e.key == track.key);
    } else if (!queue.any((e) => e.key == track.key)) {
      this.playlistId = null;
      queue = [track];
      index = 0;
    } else {
      index = queue.indexWhere((e) => e.key == track.key);
    }
    loading = true;
    _playWhenReady = true;
    error = null;
    related = [];
    notifyListeners();
    try {
      await audio.stop();
      final info = local == null
          ? await extractor.resolve(track)
          : <String, dynamic>{
              'audio': [
                {'url': local},
              ],
              'related': [],
            };
      if (generation != _generation) return;
      final streams = (info['audio'] as List).cast<Map>();
      final hls = info['hls'] as String?;
      final url = streams.isNotEmpty
          ? (selectAudio(streams)?['url'] as String?)
          : (hls?.isNotEmpty == true ? hls : null);
      if (url == null) {
        throw StateError(
          'This item requires a stream transport that is not available yet. Try another item.',
        );
      }
      related = (info['related'] as List? ?? [])
          .map((e) => Track.fromJson(e as Map))
          .toList();
      await audio.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: track.key,
            title: track.title,
            artist: track.artist,
            artUri: track.artwork.isEmpty ? null : Uri.tryParse(track.artwork),
          ),
        ),
      );
      if (generation != _generation) return;
      // Publish ready after requesting play, so the media service never sees a
      // false pause between the loading state and this source starting.
      if (_playWhenReady) unawaited(audio.play());
      loading = false;
      notifyListeners();
      await library.played(track);
    } catch (e) {
      if (generation == _generation) {
        error = e.toString();
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggle() => wantsToPlay ? pause() : resume();

  Future<void> pause() async {
    _playWhenReady = false;
    await _audio?.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    if (current == null) return;
    if (error != null) {
      await play(current!);
      return;
    }
    _playWhenReady = true;
    if (loading) {
      notifyListeners();
      return;
    }
    if (audio.processingState == ProcessingState.completed) {
      await audio.seek(Duration.zero);
    }
    unawaited(audio.play());
  }

  Future<void> next({bool automatic = false}) async {
    if (queue.isEmpty) return;
    int target = shuffle && queue.length > 1
        ? (index + 1 + Random().nextInt(queue.length - 1)) % queue.length
        : index + 1;
    if (target >= queue.length) {
      if (automatic) return;
      target = 0;
    }
    await play(queue[target]);
  }

  Future<void> previous() async {
    if (audio.position.inSeconds > 3) {
      await audio.seek(Duration.zero);
      return;
    }
    if (queue.isNotEmpty) {
      await play(queue[(index - 1 + queue.length) % queue.length]);
    }
  }

  Future<void> seek(Duration target, String mediaKey) async {
    if (current?.key == mediaKey) await audio.seek(target);
  }

  void cycleRepeat() {
    repeat = (repeat + 1) % 3;
    notifyListeners();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  Future<void> stop() async {
    ++_generation;
    _playWhenReady = false;
    _restarting = false;
    repeat = 0;
    final stopping = _audio?.stop();
    current = null;
    playlistId = null;
    loading = false;
    error = null;
    notifyListeners();
    await stopping;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _playWhenReady = false;
    _audio?.dispose();
    super.dispose();
  }
}
