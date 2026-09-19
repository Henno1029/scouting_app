import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/screens/event_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('calendar jumps to imported events outside the current month',
      (tester) async {
    final futureYear = DateTime.now().year + 2;
    SharedPreferences.setMockInitialValues({
      'import_calendar': jsonEncode([
        {
          'date': '1/6/$futureYear',
          'title': 'Far Future Meeting',
          'type': 'Meeting',
          'location': '',
          'notes': '',
        },
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: EventListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Far Future Meeting'), findsWidgets);
  });
}
