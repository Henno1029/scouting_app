import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:scouting_app/main.dart';

void main() {
  testWidgets('Troop Manager home renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(TroopApp());
    await tester.pumpAndSettle();

    expect(find.text('Navigation Hub'), findsOneWidget);
    expect(find.text('Scout Page'), findsOneWidget);
    expect(find.text('Upload Data'), findsOneWidget);
  });
}