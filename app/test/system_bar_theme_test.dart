import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/theme.dart';
import 'package:undertune/widgets/app_navigation.dart';

void main() {
  testWidgets('status icons remain readable on both light and dark app bars', (
    tester,
  ) async {
    for (final atmosphere in [
      Atmosphere.byId('daydream'),
      Atmosphere.byId('sidewalks'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: atmosphere.data,
          home: Scaffold(
            appBar: UndertuneAppBar(onMenu: () {}, onAdd: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final region = tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .last;
      expect(
        region.value.statusBarIconBrightness,
        atmosphere.light ? Brightness.dark : Brightness.light,
        reason: atmosphere.name,
      );
    }
  });
}
