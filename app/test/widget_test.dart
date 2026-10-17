import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undertune/main.dart';
import 'package:undertune/library.dart';

void main() {
  testWidgets('shell opens library and credits without fabricated content', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = await Library.load();
    await library.completeOnboarding();
    await tester.pumpWidget(UndertuneApp(library: library));
    await tester.pump();
    expect(find.text('Your Library'), findsOneWidget);
    await tester.tap(find.text('Your Library'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Liked'), findsOneWidget);
    expect(find.text('0 tracks'), findsWidgets);
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text('About Undertune'));
    await tester.tap(find.text('About Undertune'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Kafeyn'), findsOneWidget);
    expect(find.textContaining('InfinityLoop1308'), findsOneWidget);
  });
}
