import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/main.dart';
import 'package:scouting_app/models/event_group.dart';
import 'package:scouting_app/screens/ask_screen.dart';
import 'package:scouting_app/screens/badge_planner_screen.dart';
import 'package:scouting_app/screens/branding_screen.dart';
import 'package:scouting_app/screens/calculation_screen.dart';
import 'package:scouting_app/screens/event_detail_screen.dart';
import 'package:scouting_app/screens/event_list_screen.dart';
import 'package:scouting_app/screens/import_screen.dart';
import 'package:scouting_app/screens/users_screen.dart';
import 'package:scouting_app/scoutDetail_screen.dart';
import 'package:scouting_app/scoutList_screen.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/event_service.dart';
import 'package:scouting_app/services/permission_service.dart';
import 'package:scouting_app/services/program_grid_parser.dart';
import 'package:scouting_app/services/ollama_classifier.dart';
import 'package:scouting_app/services/scout_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The test troop's data, imported once and reused as stored values.
Future<Map<String, Object>> troopData() async {
  SharedPreferences.setMockInitialValues({});
  String read(String name) =>
      File('test_troop/$name').readAsStringSync(encoding: utf8);
  for (final pair in [
    ['roster', 'roster.csv'],
    ['advancement', 'advancements.csv'],
    ['activity', 'activities.csv'],
  ]) {
    final target = CsvImportService.targetById(pair[0]);
    final table = CsvImportService.parse(read(pair[1]));
    await CsvImportService.save(target, pair[1],
        CsvImportService.apply(table, CsvImportService.autoMap(target, table.headers)));
  }
  final target = CsvImportService.targetById('program_grid');
  final drafts = ProgramTypeClassifier.applyKeywords(
      ProgramGridParser.parse(CsvImportService.decodeRows(read('program_grid.csv'))));
  final rows = ProgramGridParser.toRows(
      CsvImportService.decodeRows(read('program_grid.csv')));
  final table = CsvTable(headers: rows.first, rows: rows.skip(1).toList());
  await CsvImportService.save(target, 'program_grid.csv',
      CsvImportService.apply(table, CsvImportService.autoMap(target, table.headers)));
  expect(drafts, isNotEmpty);
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
}

void main() {
  late Map<String, Object> data;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    data = await troopData();
  });

  Future<void> open(WidgetTester tester, Widget screen,
      {Size size = const Size(1000, 1800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(data);
    PermissionService.reset();
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'the screen finished loading');
  }

  // A phone-sized screen too, where layouts are most likely to overflow.
  for (final size in const [Size(1000, 1800), Size(400, 800)]) {
    final label = '${size.width.toInt()} wide';

    testWidgets('home loads, $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(data);
      await tester.pumpWidget(TroopApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ask Your Troop'), findsOneWidget);
    });

    testWidgets('scout list loads, $label', (tester) async {
      await open(tester, ScoutListScreen(), size: size);
      expect(find.text('Ethan Walker'), findsOneWidget);
    });

    testWidgets('every scout page loads, $label', (tester) async {
      SharedPreferences.setMockInitialValues(data);
      final scouts = (await tester.runAsync(ScoutService.load))!;
      for (final scout in scouts) {
        await open(tester, ScoutDetailScreen(scout: scout), size: size);
        expect(find.textContaining('Eagle-required merit badges'), findsOneWidget,
            reason: scout['name']);
      }
    });

    testWidgets('calendar loads in month and year view, $label', (tester) async {
      await open(tester, const EventListScreen(), size: size);
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('calculation page loads both tabs, $label', (tester) async {
      await open(tester, const CalculationScreen(), size: size);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Winter Camp').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Event Plans'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Planning phases'), findsOneWidget);
    });

    testWidgets('event detail loads, $label', (tester) async {
      SharedPreferences.setMockInitialValues(data);
      final groups = EventGroup.combine((await tester.runAsync(EventService.load))!);
      for (final title in ['Winter Camp at Test Lake', 'Flag Etiquette', 'Wreaths for Veterans']) {
        await open(tester,
            EventDetailScreen(group: groups.firstWhere((g) => g.first.title == title)),
            size: size);
      }
    });

    testWidgets('import, branding, planner, users and ask load, $label',
        (tester) async {
      await open(tester, const ImportScreen(), size: size);
      await open(tester, BrandingScreen(), size: size);
      await open(tester, const BadgePlannerScreen(), size: size);
      await tester.tap(find.text('Swimming'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await open(tester, const UsersScreen(), size: size);
      await open(tester, const AskScreen(), size: size);
    });
  }
}
