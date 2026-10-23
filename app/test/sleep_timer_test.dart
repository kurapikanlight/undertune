import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/media_session.dart';
import 'package:undertune/media/sleep_timer.dart';
import 'media_session_test.dart' show SessionMusic, SessionVideo;
import 'package:undertune/media/extractor.dart';

void main() {
  testWidgets(
    'timer countdown can be replaced, cancelled and expires only once',
    (tester) async {
      var stopped = 0;
      final timer = SleepTimer(
        onExpired: () async {
          stopped++;
        },
      );
      timer.start(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 2));
      expect(timer.remaining, const Duration(minutes: 3));
      timer.start(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 30));
      expect(stopped, 0);
      timer.cancel();
      await tester.pump(const Duration(minutes: 10));
      expect(stopped, 0);
      expect(timer.active, isFalse);
      timer.start(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(stopped, 1);
      expect(timer.active, isFalse);
      await tester.pump(const Duration(minutes: 5));
      expect(stopped, 1);
      expect(() => timer.start(Duration.zero), throwsArgumentError);
      timer.start(const Duration(minutes: 1));
      timer.dispose();
      await tester.pump(const Duration(minutes: 2));
      expect(stopped, 1);
    },
  );
  testWidgets(
    'expired timer pauses current video after an audio-to-video handoff, preserving position and queue',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final music = SessionMusic(await Library.load());
      const track = Track(url: 'music', title: 'Music', artist: 'Artist');
      music.current = track;
      music.queue = [track];
      final session = UndertuneMediaSession()..bindMusic(music);
      session.sleepTimer.start(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 30));
      final video = SessionVideo();
      await video.seekTo(const Duration(seconds: 20));
      session.attachVideo(
        video,
        const Track(url: 'video', title: 'Video', artist: 'Channel'),
        null,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(video.value.isPlaying, isFalse);
      expect(video.value.position, const Duration(seconds: 20));
      expect(session.playbackState.value.playing, isFalse);
      expect(music.running, isFalse);
      expect(music.queue, [track]);
      expect(session.sleepTimer.active, isFalse);
      session.detachVideo(video);
      session.unbindMusic();
      await video.dispose();
      music.dispose();
      session.sleepTimer.dispose();
    },
  );
  testWidgets(
    'audio expiry pauses rather than clearing the queue; explicit stop cancels the timer',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final music = SessionMusic(await Library.load());
      const track = Track(url: 'music', title: 'Music', artist: 'Artist');
      music.current = track;
      music.queue = [track];
      final session = UndertuneMediaSession()..bindMusic(music);
      session.sleepTimer.start(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(music.running, isFalse);
      expect(music.current, track);
      expect(music.queue, [track]);
      await session.play();
      session.sleepTimer.start(const Duration(minutes: 5));
      await session.stop();
      expect(session.sleepTimer.active, isFalse);
      session.unbindMusic();
      music.dispose();
      session.sleepTimer.dispose();
    },
  );
  testWidgets(
    'pause failures are handled and a replacement timer clears the error',
    (tester) async {
      final timer = SleepTimer(
        onExpired: () async {
          throw StateError('Native player unavailable');
        },
      );
      timer.start(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(timer.error, isNotNull);
      expect(timer.active, isFalse);
      timer.start(const Duration(minutes: 1));
      expect(timer.error, isNull);
      timer.dispose();
    },
  );
  testWidgets(
    'timer expiry prevents a still-loading video from starting automatically',
    (tester) async {
      final session = UndertuneMediaSession();
      final revision = session.pauseRevision;
      session.sleepTimer.start(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final video = SessionVideo();
      video.value = video.value.copyWith(isPlaying: false);
      await session.startVideo(
        video,
        const Track(url: 'late', title: 'Late video', artist: 'Channel'),
        null,
        pauseRevision: revision,
      );
      expect(video.plays, 0);
      expect(session.videoPlaying, isFalse);
      await session.play();
      expect(video.value.isPlaying, isTrue);
      session.detachVideo(video);
      await video.dispose();
      session.sleepTimer.dispose();
    },
  );
}
