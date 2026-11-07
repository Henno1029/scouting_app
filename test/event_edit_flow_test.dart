import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/screens/event_list_screen.dart';
import 'package:scouting_app/services/event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpCalendar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'import_calendar': jsonEncode([
        {'date': '2099-06-15', 'title': 'Summer Camp', 'type': 'PLC'},
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: EventListScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> renameInDialog(WidgetTester tester) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ).first,
      'Renamed',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('pencil on a month list tile edits the event',
      (WidgetTester tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.byTooltip('Edit event'));
    await tester.pumpAndSettle();
    await renameInDialog(tester);

    expect(find.text('Summer Camp'), findsNothing);
    expect(find.text('Renamed'), findsWidgets);
    final events = (await tester.runAsync(EventService.load))!;
    expect(events.single.title, 'Renamed');
  });

  testWidgets('pencil in the day sheet edits the event and closes the sheet',
      (WidgetTester tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Summer Camp'));
    await tester.pumpAndSettle();
    expect(find.text('Add Event'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit event').last);
    await tester.pumpAndSettle();
    await renameInDialog(tester);

    expect(find.text('Add Event'), findsNothing);
    expect(find.text('Summer Camp'), findsNothing);
    expect(find.text('Renamed'), findsWidgets);
  });

  testWidgets('cancelling the dialog changes nothing',
      (WidgetTester tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.byTooltip('Edit event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Summer Camp'), findsWidgets);
  });
}
