import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/library.dart';
import 'package:undertune/main.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/screens/library.dart';

void main() {
  testWidgets('library switches, searches and sorts actual saved content', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = await Library.load();
    final night = await library.createPlaylist('night');
    const track = Track(
      url: 'saved-track',
      title: 'Night song',
      artist: 'Artist',
      duration: 185,
    );
    await library.toggleLike(track);
    await library.addToPlaylist(night, track);
    await library.createPlaylist('ambient');
    await library.completeOnboarding();
    await tester.pumpWidget(UndertuneApp(library: library));
    await tester.pump();
    await tester.tap(find.text('Your Library'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Search playlists'), findsOneWidget);
    expect(find.text('3 playlists · 1 track'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search playlists'),
      'night',
    );
    await tester.pump();
    expect(find.text('night').last, findsOneWidget);
    expect(find.text('ambient'), findsNothing);
    await tester.drag(find.byType(LibraryScreen), const Offset(-280, 0));
    await tester.pump();
    expect(find.text('Search Tracks'), findsOneWidget);
    expect(find.text('Night song'), findsOneWidget);
    expect(find.text('Artist · 3:05'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search Tracks'),
      'no match',
    );
    await tester.pump();
    expect(find.text('No matches found'), findsOneWidget);
    expect(find.text('Night song'), findsNothing);
    await tester.drag(find.byType(LibraryScreen), const Offset(280, 0));
    await tester.pump();
    expect(find.text('night').last, findsOneWidget);
    expect(find.text('ambient'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'night'), '');
    await tester.pump();
    await tester.tap(find.text('Saved order'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Name A–Z'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('night'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(LibraryScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      tester.getTopLeft(find.text('ambient')).dy,
      lessThan(tester.getTopLeft(find.text('night')).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
