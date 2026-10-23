import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';
import 'package:undertune/media/downloads.dart';
import 'package:undertune/media/media_session.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/playback.dart';
import 'package:undertune/media/sleep_timer.dart';
import 'package:undertune/screens/player.dart';
import 'package:undertune/widgets/sleep_timer_controls.dart';
import 'package:undertune/widgets/audio_mini_player.dart';

const song = Track(url: 'song', title: 'Song A', artist: 'Artist');
const other = Track(url: 'other', title: 'Song B', artist: 'Artist');

class Controls extends Playback {
  Controls(super.extractor, super.library);
  bool running = true;
  int nexts = 0, previouses = 0;
  Duration at = const Duration(seconds: 45);
  @override
  bool get playing => running;
  @override
  bool get wantsToPlay => running;
  @override
  Duration get position => at;
  @override
  Duration get duration => const Duration(minutes: 3);
  @override
  Future<void> toggle() async {
    running = !running;
    notifyListeners();
  }

  @override
  Future<void> next({bool automatic = false}) async {
    nexts++;
  }

  @override
  Future<void> previous() async {
    previouses++;
  }

  @override
  Future<void> play(
    Track track, {
    List<Track>? from,
    String? playlistId,
  }) async {
    current = track;
    at = Duration.zero;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration target, String mediaKey) async {
    if (current?.key == mediaKey) at = target;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'sleep timer opens from the top player menu, with no standalone button',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final p = Controls(Extractor(), library)
        ..current = song
        ..queue = [song];
      final downloads = Downloads();
      final session = UndertuneMediaSession()..bindMusic(p);
      const bridge = MethodChannel('undertune/extractor');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(bridge, (_) async => {'items': []});
      addTearDown(() => messenger.setMockMethodCallHandler(bridge, null));
      await tester.pumpWidget(
        MaterialApp(
          home: UndertuneShell(
            library: library,
            extractor: p.extractor,
            playback: p,
            downloads: downloads,
            background: session,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(AudioMiniPlayer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.text('Sleep timer'), findsNothing);
      await tester.tap(find.byTooltip('Track actions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Sleep timer'));
      await tester.tap(find.text('Sleep timer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Custom minutes'), findsOneWidget);
      await tester.tap(find.text('5 min'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(session.sleepTimer.active, isTrue);
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.text('Sleep timer'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      session.sleepTimer.dispose();
      session.unbindMusic();
      downloads.dispose();
      p.dispose();
    },
  );
  testWidgets(
    'Now Playing controls, repeat icons and initial seek position match their actions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = await Library.load();
      final p = Controls(Extractor(), library)
        ..current = song
        ..queue = [song, other];
      final timer = SleepTimer(onExpired: () async {});
      Track? added, actions;
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            playback: p,
            library: library,
            onAdd: (t) async {
              added = t;
            },
            onActions: (t) async {
              actions = t;
            },
            onPlay: p.play,
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Repeat off'), findsOneWidget);
      expect(find.byKey(const ValueKey('sleep-timer-control')), findsNothing);
      expect(find.bySemanticsLabel('Next'), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 45000);
      await tester.tap(find.byTooltip('Track actions'));
      expect(actions, song);
      await tester.tap(find.byTooltip('Like'));
      await tester.pump();
      expect(library.isLiked(song), isTrue);
      await tester.tap(find.byTooltip('Unlike'));
      await tester.pump();
      expect(library.isLiked(song), isFalse);
      await tester.tap(find.byTooltip('Add to playlist'));
      expect(added, song);
      await tester.ensureVisible(find.byTooltip('Repeat off'));
      await tester.tap(find.byTooltip('Repeat off'));
      await tester.pump();
      expect(p.repeat, 1);
      expect(find.byTooltip('Replay once'), findsOneWidget);
      expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
      await tester.tap(find.byTooltip('Replay once'));
      await tester.pump();
      expect(p.repeat, 2);
      expect(find.byIcon(Icons.all_inclusive_rounded), findsOneWidget);
      await tester.tap(find.byTooltip('Loop continuously'));
      await tester.pump();
      expect(p.repeat, 0);
      await tester.tap(find.byTooltip('Shuffle'));
      await tester.pump();
      expect(p.shuffle, isTrue);
      await tester.tap(find.byTooltip('Next'));
      await tester.tap(find.byTooltip('Previous'));
      expect(p.nexts, 1);
      expect(p.previouses, 1);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(p.running, isFalse);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(p.running, isTrue);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChangeStart!(30000);
      await tester.pump();
      tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(30000);
      await tester.pump();
      expect(p.at, const Duration(seconds: 30));
      await tester.ensureVisible(find.text('Queue · 2'));
      await tester.tap(find.text('Queue · 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Song B'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(p.current?.key, other.key);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
      p.dispose();
    },
  );
  testWidgets(
    'sleep timer presets, custom validation, countdown and cancel fit a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var pauses = 0;
      final timer = SleepTimer(
        onExpired: () async {
          pauses++;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SleepTimerTile(
                timer: timer,
                onTap: () => showSleepTimer(context, timer),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('sleep-timer-control')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('5 min'));
      await tester.tap(find.text('5 min'));
      await tester.pumpAndSettle();
      expect(timer.active, isTrue);
      await tester.tap(find.byKey(const ValueKey('sleep-timer-control')));
      await tester.pumpAndSettle();
      expect(find.textContaining('remaining'), findsWidgets);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '0');
      await tester.ensureVisible(find.text('Start'));
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('Enter 1–1440 minutes.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1');
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(timer.remaining, const Duration(seconds: 30));
      await tester.tap(find.byKey(const ValueKey('sleep-timer-control')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel timer'));
      await tester.tap(find.text('Cancel timer'));
      await tester.pumpAndSettle();
      expect(timer.active, isFalse);
      expect(pauses, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    },
  );
}
