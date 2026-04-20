// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:geo_guesser/main.dart';

void main() {
  testWidgets('App shows home title', (WidgetTester tester) async {
    await tester.pumpWidget(const GeoGuesserApp());

    expect(find.text('GeoGuesser'), findsOneWidget);
    // 首頁應顯示三個模式按鈕
    expect(find.text('完整 Move'), findsOneWidget);
    expect(find.text('No Move'), findsOneWidget);
    expect(find.text('Picture'), findsOneWidget);
  });
}
