import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/playback.dart';
import 'support/native_audio.dart';

const a = Track(
  url: 'https://youtube.com/watch?v=a',
  title: 'A',
  artist: 'Artist',
);
const b = Track(
  url: 'https://youtube.com/watch?v=b',
  title: 'B',
  artist: 'Artist',
);

class AudioExtractor extends Extractor {
  @override
  Future<Map<String, dynamic>> resolve(Track track) async => {
    'audio': [
      {'url': 'https://media.example/${track.title}.m4a', 'bitrate': 160},
    ],
    'related': [],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NativeAudio backend;
  late Playback p;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = NativeAudio();
    p = Playback(AudioExtractor(), await Library.load());
    await p.play(a, from: [a, b]);
    await flushAudio();
    expect(p.error, isNull);
    expect(p.playing, isTrue);
  });
  tearDown(() async {
    await p.stop();
    await p.audio.dispose();
    p.dispose();
    await flushAudio();
    backend.dispose();
  });
  test(
    'first repeat press plays the current song exactly one extra time, then continues normally',
    () async {
      p.cycleRepeat();
      backend.current.finish();
      await flushAudio();
      expect(p.current?.key, a.key);
      expect(backend.current.seeks, 1);
      expect(
        p.repeat,
        0,
        reason: 'One extra play consumes the finite repeat state',
      );
      backend.current.finish();
      await flushAudio();
      expect(p.current?.key, b.key);
      backend.current.finish();
      await flushAudio();
      expect(p.playing, isFalse);
      expect(backend.sources, hasLength(2));
    },
  );
  test(
    'second repeat press continuously loops this song rather than the queue',
    () async {
      p.cycleRepeat();
      p.cycleRepeat();
      for (var i = 0; i < 3; i++) {
        backend.current.finish();
        await flushAudio();
        expect(p.current?.key, a.key);
      }
      expect(p.repeat, 2);
      expect(backend.current.seeks, 3);
      expect(backend.sources, hasLength(1));
      p.cycleRepeat();
      backend.current.finish();
      await flushAudio();
      expect(p.current?.key, b.key);
    },
  );
  test(
    'pause while an EOF seek is pending cannot be undone by a late replay',
    () async {
      p.cycleRepeat();
      final native = backend.current;
      native.seekGate = Completer<void>();
      native.finish();
      await flushAudio();
      expect(native.seeks, 1);
      await p.pause();
      native.seekGate!.complete();
      await flushAudio();
      expect(p.playing, isFalse);
    },
  );
  test('changing songs cancels an unconsumed one-time replay', () async {
    p.cycleRepeat();
    await p.next();
    await flushAudio();
    expect(p.current?.key, b.key);
    expect(p.repeat, 0);
  });
  for (final stop in [false, true]) {
    test('${stop ? 'stop' : 'next'} wins over a pending EOF replay', () async {
      p.cycleRepeat();
      final native = backend.current;
      native.seekGate = Completer<void>();
      native.finish();
      await flushAudio();
      final plays = native.plays;
      if (stop) {
        await p.stop();
      } else {
        await p.next();
      }
      await flushAudio();
      native.seekGate!.complete();
      await flushAudio();
      expect(native.plays, plays);
      expect(p.current?.key, stop ? null : b.key);
      expect(p.repeat, 0);
    });
  }
  test(
    'duplicate completion events advance only once and normal playback never wraps automatically',
    () async {
      final old = backend.current;
      old.finish();
      old.finish();
      await flushAudio();
      expect(p.current?.key, b.key);
      backend.current.finish();
      await flushAudio();
      expect(backend.sources, hasLength(2));
      expect(p.playing, isFalse);
    },
  );
  test(
    'previous, seek, shuffle and manual next keep their existing behavior',
    () async {
      await p.seek(const Duration(seconds: 10), a.key);
      await flushAudio();
      await p.previous();
      await flushAudio();
      expect(p.position.inSeconds, lessThan(1));
      p.toggleShuffle();
      expect(p.shuffle, isTrue);
      await p.next();
      await flushAudio();
      expect(p.current?.key, b.key);
      await p.seek(const Duration(seconds: 20), a.key);
      expect(p.position.inSeconds, lessThan(1));
      await p.toggle();
      expect(p.playing, isFalse);
      await p.toggle();
      await flushAudio();
      expect(p.playing, isTrue);
    },
  );
}
