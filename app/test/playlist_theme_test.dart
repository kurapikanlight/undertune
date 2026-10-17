import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';
import 'package:undertune/screens/player.dart';
import 'package:undertune/screens/playlist.dart';
import 'package:undertune/widgets/audio_mini_player.dart';

void main() {
  testWidgets(
    'playlist theme stays local and follows playback after leaving the playlist',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'undertune.library.v1': jsonEncode({
          'theme': 'daydream',
          'onboardingComplete': true,
          'playlists': [
            {
              'id': 'night',
              'name': 'Night',
              'themeId': 'emerald',
              'tracks': [
                {
                  'url': 'song-one',
                  'title': 'Song one',
                  'artist': 'Artist',
                  'duration': 120,
                },
                {
                  'url': 'song-two',
                  'title': 'Song two',
                  'artist': 'Artist',
                  'duration': 120,
                },
              ],
            },
          ],
        }),
      });
      final library = await Library.load();
      await tester.pumpWidget(UndertuneApp(library: library));
      await tester.pump();
      expect(
        Theme.of(tester.element(find.text('Home').first)).brightness,
        Brightness.light,
      );
      await tester.tap(find.text('Night'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        Theme.of(tester.element(find.byType(PlaylistScreen))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.byTooltip('Play playlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('NOW PLAYING'))).brightness,
        Brightness.dark,
      );
      final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
      unawaited(player.playback.next());
      await tester.pump(const Duration(milliseconds: 400));
      expect(player.playback.current?.title, 'Song two');
      expect(
        Theme.of(tester.element(find.text('NOW PLAYING'))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.byTooltip('Collapse player'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Home').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        Theme.of(tester.element(find.text('Home').first)).brightness,
        Brightness.light,
      );
      // Reopening Now Playing retains the queue's source, independent of browsing.
      await tester.tap(
        find.descendant(
          of: find.byType(AudioMiniPlayer),
          matching: find.text('Song two'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        Theme.of(tester.element(find.text('NOW PLAYING'))).brightness,
        Brightness.dark,
      );
      // A fresh queue, even containing the same song, uses the global theme.
      unawaited(
        player.playback.play(
          player.playback.current!,
          from: player.playback.queue,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        Theme.of(tester.element(find.text('NOW PLAYING'))).brightness,
        Brightness.light,
      );
      expect(library.themeId, 'daydream');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('create playlist offers an optional theme and a Feelfree title', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = await Library.load();
    await library.completeOnboarding();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(UndertuneApp(library: library));
    await tester.pump();
    await tester.tap(find.byTooltip('Create playlist'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<Text>(find.text('New playlist')).style?.fontFamily,
      'Feelfree',
    );
    expect(find.text('Follow app theme'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ocean mix');
    await tester.ensureVisible(find.text('Follow app theme'));
    await tester.pump();
    await tester.tap(find.text('Follow app theme'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Sienna').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 400));
    final restored = await Library.load();
    expect(restored.playlists.single.name, 'Ocean mix');
    expect(restored.playlists.single.toJson()['themeId'], 'midnight_bloom');
    expect(library.themeId, 'obsidian');
    await tester.tap(find.byTooltip('Create playlist'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'App mix');
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 400));
    expect((await Library.load()).playlists.last.toJson()['themeId'], isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
