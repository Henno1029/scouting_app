import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/models/event_group.dart';
import 'package:scouting_app/screens/calculation_screen.dart';
import 'package:scouting_app/screens/event_list_screen.dart';
import 'package:scouting_app/scoutDetail_screen.dart';
import 'package:scouting_app/scoutList_screen.dart';
import 'package:scouting_app/services/branding_service.dart';
import 'package:scouting_app/services/calculation_pdf_service.dart';
import 'package:scouting_app/services/program_grid_parser.dart';
import 'package:scouting_app/services/requirement_calculator.dart';
import 'package:scouting_app/services/scout_service.dart';
import 'package:scouting_app/widgets/load_error.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }

  testWidgets('damaged data shows a message, not an endless spinner',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'scouts': '[{"name":"Alex Tester"}]',
      'import_advancement': 'this is not valid saved data',
    });
    await pump(tester, const CalculationScreen());
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LoadError), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await pump(tester, const ScoutDetailScreen(scout: {'name': 'Alex Tester'}));
    expect(find.byType(LoadError), findsOneWidget);
  });

  testWidgets('scouts saved with odd values still load',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'scouts': jsonEncode([
        {'name': 'Alex Tester', 'rank': null, 'patrol': 'Fox', 'age': 12},
        {'rank': 'Scout'},
        'not a scout',
      ]),
      'branding_patrol_emblems': jsonEncode({
        'Fox': {'name': 'fox', 'data': '%%% not an image %%%'},
      }),
    });
    final scouts = await ScoutService.load();
    expect(scouts.length, 2);
    expect(scouts.first['age'], '12');
    expect(scouts.first.containsKey('rank'), isFalse);

    await pump(tester, ScoutListScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Alex Tester'), findsOneWidget);
  });

  test('damaged images become empty instead of crashing', () {
    expect(const TroopLogo('logo', 'not base64!').bytes, isEmpty);
    expect(const PatrolEmblem('fox', '***').bytes, isEmpty);
  });

  testWidgets('Add Event from a day starts on that day',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'events': jsonEncode([
        Event(id: 'e', title: 'Summer Camp', type: 'Campout', date: DateTime(2099, 6, 15))
            .toJson(),
      ]),
    });
    await pump(tester, const EventListScreen());
    await tester.tap(find.text('Summer Camp').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Event'));
    await tester.pumpAndSettle();
    expect(find.text('Date: 6/15/2099'), findsOneWidget);
  });

  test('a plain calendar list is told apart from the planning grid', () {
    expect(
      ProgramGridParser.hasGridHeader([
        ['Date', 'Title', 'Type'],
        ['6/15/2099', 'Camp', 'Campout'],
      ]),
      isFalse,
    );
    expect(
      ProgramGridParser.hasGridHeader([
        ['Month', 'Program Feature', 'Week 1', 'Camping'],
      ]),
      isTrue,
    );
  });

  test('PDFs embed a font that can draw accented and other letters', () async {
    final bytes = await CalculationPdfService.build(
      event: Event(id: 'e', title: 'Fall Camp', type: 'Campout', date: DateTime(2099, 10, 2)),
      results: [
        ScoutRequirements(const ScoutProgress(name: 'Łukasz Núñez Тест'), const []),
      ],
      troopName: 'Troop 000',
    );
    expect(latin1.decode(bytes), contains('Roboto'));
  });

  test('Event Detail groups survive a single-day event', () {
    final group = EventGroup([
      Event(id: 'e', title: 'Night', type: 'Meeting', date: DateTime(2099, 1, 1)),
    ]);
    expect(group.isMultiDay, isFalse);
  });
}
