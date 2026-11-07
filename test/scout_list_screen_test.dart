import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/scoutList_screen.dart';
import 'package:scouting_app/services/scout_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('scout list still renders after a patrol is cleared',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'scouts': jsonEncode([
        {'name': 'Test Scout', 'rank': 'Life', 'patrol': 'Fox'},
      ]),
    });
    await ScoutService.updateScout('Test Scout', {'patrol': ''});

    await tester.pumpWidget(MaterialApp(home: ScoutListScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Test Scout'), findsOneWidget);
    expect(find.text('Life'), findsOneWidget);
  });
}
