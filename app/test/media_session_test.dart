import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/media_session.dart';

// The real session receives the same controller notifications as VideoScreen.
// Commands update this controller rather than constructing a second player.
class SessionVideo extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  SessionVideo()
    : super(
        const VideoPlayerValue(
          duration: Duration(minutes: 2),
          size: Size(1280, 720),
          isInitialized: true,
          isPlaying: true,
        ),
      );
  int plays = 0, pauses = 0;
  @override
  Future<void> play() async {
    plays++;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    pauses++;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    value = value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async {
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SessionMusic extends Playback {
  SessionMusic(Library library) : super(Extractor(), library);
  bool running = true;
  @override
  bool get playing => running;
  @override
  bool get wantsToPlay => running;
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Duration get duration => const Duration(minutes: 3);
  @override
  Future<void> pause() async {
    running = false;
    notifyListeners();
  }

  @override
  Future<void> resume() async {
    running = true;
    notifyListeners();
  }

  @override
  Future<void> next({bool automatic = false}) async {
    index = (index + 1) % queue.length;
    current = queue[index];
    notifyListeners();
  }
}

class CompletingMusic extends Playback {
  CompletingMusic(Library library) : super(Extractor(), library);
  @override
  ProcessingState get processingState => ProcessingState.completed;
  @override
  bool get playing => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'video buffering does not demote the media service; explicit pause does',
    (tester) async {
      final video = SessionVideo();
      final session = UndertuneMediaSession();
      session.attachVideo(
        video,
        const Track(url: 'buffer', title: 'Video', artist: 'Channel'),
        null,
      );
      video.value = video.value.copyWith(isBuffering: true, isPlaying: false);
      expect(session.playbackState.value.playing, isTrue);
      video.value = video.value.copyWith(isBuffering: false);
      expect(
        session.playbackState.value.playing,
        isTrue,
        reason: 'Buffer-end arrives before the native playing event',
      );
      await tester.pump(const Duration(milliseconds: 30));
      video.value = video.value.copyWith(isPlaying: true);
      await tester.pump(const Duration(milliseconds: 150));
      expect(session.playbackState.value.playing, isTrue);
      video.value = video.value.copyWith(isBuffering: true, isPlaying: false);
      await session.pause();
      expect(session.playbackState.value.playing, isFalse);
      await session.play();
      video.value = video.value.copyWith(isBuffering: false);
      video.value = video.value.copyWith(isBuffering: true, isPlaying: false);
      video.value = video.value.copyWith(isBuffering: false);
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        session.playbackState.value.playing,
        isFalse,
        reason:
            'A genuine native pause after buffering must still release the service',
      );
      session.detachVideo(video);
      await video.dispose();
    },
  );
  test(
    'queued completion keeps the media service active until the next source loads',
    () async {
      SharedPreferences.setMockInitialValues({});
      final music = CompletingMusic(await Library.load());
      const first = Track(url: 'first', title: 'First', artist: 'Artist');
      const second = Track(url: 'second', title: 'Second', artist: 'Artist');
      music.current = first;
      music.queue = [first, second];
      music.loading = true;
      await music.resume();
      music.loading = false;
      final session = UndertuneMediaSession()..bindMusic(music);
      expect(
        session.playbackState.value.playing,
        isTrue,
        reason:
            'A transient completed event must not demote the foreground service',
      );
      music.index = 1;
      music.notifyListeners();
      expect(
        session.playbackState.value.playing,
        isFalse,
        reason: 'The end of a non-repeating queue really ends playback',
      );
      music.repeat = 1;
      music.notifyListeners();
      expect(session.playbackState.value.playing, isTrue);
      music.repeat = 2;
      music.notifyListeners();
      expect(
        session.playbackState.value.repeatMode,
        AudioServiceRepeatMode.one,
      );
      music.repeat = 0;
      music.shuffle = true;
      music.notifyListeners();
      expect(session.playbackState.value.playing, isTrue);
      await music.pause();
      expect(
        session.playbackState.value.playing,
        isFalse,
        reason: 'Explicit pause always releases the desired playback state',
      );
      session.unbindMusic();
      music.dispose();
    },
  );
  test(
    'music queue controls survive task dismissal and video restores music controls',
    () async {
      SharedPreferences.setMockInitialValues({});
      final music = SessionMusic(await Library.load());
      const first = Track(url: 'song-a', title: 'Song A', artist: 'Artist');
      const second = Track(url: 'song-b', title: 'Song B', artist: 'Artist');
      music.queue = [first, second];
      music.current = first;
      final session = UndertuneMediaSession()..bindMusic(music);
      expect(session.queue.value.map((t) => t.title), ['Song A', 'Song B']);
      await session.onTaskRemoved();
      expect(session.playbackState.value.playing, isTrue);
      await session.skipToNext();
      expect(session.mediaItem.value?.title, 'Song B');
      expect(session.playbackState.value.queueIndex, 1);
      await session.pause();
      expect(session.playbackState.value.playing, isFalse);
      await session.play();
      expect(session.playbackState.value.playing, isTrue);
      final video = SessionVideo();
      session.attachVideo(
        video,
        const Track(url: 'video', title: 'Video', artist: 'Channel'),
        null,
      );
      await session.pause();
      expect(
        music.playing,
        isTrue,
        reason: 'Video controls must target the video controller',
      );
      expect(video.value.isPlaying, isFalse);
      session.detachVideo(video);
      expect(session.mediaItem.value?.title, 'Song B');
      expect(
        session.playbackState.value.controls,
        contains(MediaControl.skipToNext),
      );
      session.unbindMusic();
      await video.dispose();
      music.dispose();
    },
  );
  test(
    'video publishes a session and keeps playing after task removal',
    () async {
      final video = SessionVideo();
      final session = UndertuneMediaSession();
      var closed = false;
      session.attachVideo(
        video,
        const Track(
          url: 'video',
          title: 'A video',
          artist: 'Channel',
          video: true,
        ),
        () => closed = true,
      );
      expect(session.mediaItem.value?.title, 'A video');
      expect(session.playbackState.value.playing, isTrue);
      await session.onTaskRemoved();
      expect(video.value.isPlaying, isTrue);
      expect(closed, isFalse);
      await session.pause();
      expect(video.pauses, 1);
      expect(session.playbackState.value.playing, isFalse);
      await session.seek(const Duration(seconds: 30));
      expect(video.value.position, const Duration(seconds: 30));
      await session.play();
      expect(video.plays, 1);
      await session.stop();
      expect(closed, isTrue);
      session.detachVideo(video);
      expect(
        session.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      await video.dispose();
    },
  );

  test(
    'closing an old video cannot clear the replacement media session',
    () async {
      final first = SessionVideo(), second = SessionVideo();
      final session = UndertuneMediaSession();
      session.attachVideo(
        first,
        const Track(url: 'first', title: 'First', artist: 'Channel'),
        null,
      );
      session.attachVideo(
        second,
        const Track(url: 'second', title: 'Second', artist: 'Channel'),
        null,
      );
      session.detachVideo(first);
      await session.pause();
      expect(first.pauses, 0);
      expect(second.pauses, 1);
      expect(session.mediaItem.value?.title, 'Second');
      session.detachVideo(second);
      await first.dispose();
      await second.dispose();
    },
  );
}
