import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/screens/calculation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'scouts': jsonEncode([
        {'name': 'Alex Tester', 'rank': 'First Class'},
        {'name': 'Sam Tester', 'rank': 'Life', 'patrol': 'Fox'},
      ]),
      'events': jsonEncode([
        {
          'id': 'service',
          'title': 'Park Cleanup',
          'type': 'Service Project',
          'date': '2099-05-01',
        },
        {'id': 'plc', 'title': 'Leaders', 'type': 'PLC', 'date': '2099-05-02'},
        {'id': 'old', 'title': 'Old Hike', 'type': 'Hike', 'date': '2001-05-02'},
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: CalculationScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> chooseEvent(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows each scout\'s requirements for the chosen event',
      (WidgetTester tester) async {
    await pumpScreen(tester);
    expect(find.textContaining('Choose an event and'), findsOneWidget);

    await chooseEvent(tester, 'Park Cleanup');
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Star 4'), findsOneWidget);
    expect(find.text('1 requirement'), findsOneWidget);
    expect(find.text('0 requirements'), findsOneWidget);
    expect(find.textContaining('Nothing left to complete'), findsOneWidget);
  });

  testWidgets('only attending scouts appear in the results',
      (WidgetTester tester) async {
    await pumpScreen(tester);
    await chooseEvent(tester, 'Park Cleanup');

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sam Tester'));
    await tester.pumpAndSettle();

    expect(find.text('0 requirements'), findsOneWidget);
    expect(find.text('Star 4'), findsNothing);
  });

  testWidgets('explains event types with no requirements',
      (WidgetTester tester) async {
    await pumpScreen(tester);
    await chooseEvent(tester, 'Leaders');
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No rank requirements are tied to PLC'),
        findsOneWidget);
  });

  testWidgets('print is only available once there are results',
      (WidgetTester tester) async {
    IconButton printButton() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.print_outlined));

    await pumpScreen(tester);
    expect(printButton().onPressed, isNull);

    await chooseEvent(tester, 'Park Cleanup');
    expect(printButton().onPressed, isNull);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sam Tester'));
    await tester.pumpAndSettle();
    expect(printButton().onPressed, isNotNull);

    await chooseEvent(tester, 'Leaders');
    expect(printButton().onPressed, isNull);
  });

  testWidgets('past events only appear when switched on',
      (WidgetTester tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('Old Hike'), findsNothing);
    await tester.tap(find.textContaining('Park Cleanup').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await chooseEvent(tester, 'Old Hike');

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Old Hike'), findsOneWidget);
  });
}
