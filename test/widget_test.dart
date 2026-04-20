// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:geo_guesser/main.dart';

void main() {
  testWidgets('App shows matchday home (step 1 of 2)',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GeoGuesserApp());

    // Brand mark
    expect(find.text('LOL'), findsOneWidget);
    expect(find.text('CATION'), findsOneWidget);
    expect(find.text('LOLCATION'), findsOneWidget);

    // Setup section on home page
    expect(find.text('GAME SETUP'), findsOneWidget);

    // CTA to next page
    expect(find.text('MATCHDAY →'), findsOneWidget);

    // Three mode cards should NOT appear here anymore — they're on
    // ModeSelectionPage now.
    expect(find.text('MOVE'), findsNothing);
    expect(find.text('NO MOVE'), findsNothing);
    expect(find.text('PICTURE'), findsNothing);
  });
}
