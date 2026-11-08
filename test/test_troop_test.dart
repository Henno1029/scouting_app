import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/models/event_group.dart';
import 'package:scouting_app/models/event_plan.dart';
import 'package:scouting_app/services/advancement_service.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/event_service.dart';
import 'package:scouting_app/services/official_form_service.dart';
import 'package:scouting_app/services/ollama_classifier.dart';
import 'package:scouting_app/services/program_grid_parser.dart';
import 'package:scouting_app/services/requirement_calculator.dart';
import 'package:scouting_app/services/scout_service.dart';
import 'package:scouting_app/services/troop_stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads the fictional test_troop files the way the import screen does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String name) =>
      File('test_troop/$name').readAsStringSync(encoding: utf8);

  Future<({int added, int total, int scoutsAdded})> importFile(
      String targetId, String name) {
    final target = CsvImportService.targetById(targetId);
    final table = CsvImportService.parse(read(name));
    final mapping = CsvImportService.autoMap(target, table.headers);
    expect(CsvImportService.missingRequired(target, mapping), isEmpty);
    return CsvImportService.save(
        target, name, CsvImportService.apply(table, mapping));
  }

  Future<void> importGrid() async {
    final target = CsvImportService.targetById('program_grid');
    final drafts = ProgramTypeClassifier.applyKeywords(
      ProgramGridParser.parse(
          CsvImportService.decodeRows(read('program_grid.csv'))),
    );
    final table = CsvTable(
      headers: const ['Date', 'Title', 'Type', 'Location', 'Notes'],
      rows: [
        for (final d in drafts)
          [
            '${d.date!.month}/${d.date!.day}/${d.date!.year}',
            d.title,
            d.type,
            d.location,
            d.notes,
          ],
      ],
    );
    await CsvImportService.save(target, 'program_grid.csv',
        CsvImportService.apply(table, CsvImportService.autoMap(target, table.headers)));
  }

  Future<void> importAll() async {
    SharedPreferences.setMockInitialValues({});
    await importFile('roster', 'roster.csv');
    await importFile('advancement', 'advancements.csv');
    await importFile('activity', 'activities.csv');
    await importGrid();
  }

  Future<ScoutProgress> progressOf(String name) async {
    final scouts = await ScoutService.load();
    final scout = scouts.firstWhere((s) => s['name'] == name);
    return RequirementCalculator.load(name, scout['rank'] ?? '');
  }

  List<String> idsAt(List<EventGroup> groups, String title, ScoutProgress p) {
    final group = groups.firstWhere((g) => g.first.title == title);
    return RequirementCalculator.available(group.first, p)
        .map((r) => '${r.rank} ${r.id}')
        .toList();
  }

  test('the roster and advancement report create 15 scouts with details',
      () async {
    SharedPreferences.setMockInitialValues({});
    final roster = await importFile('roster', 'roster.csv');
    expect(roster.added, 14);

    final advancement = await importFile('advancement', 'advancements.csv');
    expect(advancement.scoutsAdded, 1);

    final scouts = await ScoutService.load();
    expect(scouts.length, 15);
    final mateo = scouts.firstWhere((s) => s['name'] == 'Mateo Núñez');
    expect(mateo['patrol'], 'Hawk');
    expect(mateo['memberId'], isNotEmpty);
    expect(scouts.map((s) => s['name']), contains('Maya Rose Patel'));
    expect(scouts.map((s) => s['name']), contains('Owen Brooks'));
  });

  test('importing the advancement report again adds nothing', () async {
    await importAll();
    final again = await importFile('advancement', 'advancements.csv');
    expect(again.added, 0);
    expect(again.scoutsAdded, 0);
  });

  test('ranks from the troop cover every level', () async {
    await importAll();
    const expected = {
      'Ethan Walker': '',
      'Liam James Ortiz': 'Scout',
      'Noah Kim': 'Tenderfoot',
      'Ava Thompson': 'Second Class',
      'Lucas Greene': 'First Class',
      'Oliver Hayes': 'Star',
      'Charlotte Anne Rivera': 'Life',
      'Henry Vance': 'Eagle',
      'Owen Brooks': 'Scout',
    };
    for (final entry in expected.entries) {
      final progress = await progressOf(entry.key);
      expect(progress.rank, entry.value, reason: entry.key);
    }
    final henry =
        await AdvancementService.importedAdvancements('Henry Vance');
    expect(henry.where((e) => e.isMeritBadge).length, 13);
    expect(henry.where((e) => e.isAward).length, 1);
  });

  test('every event type and requirement state behaves as the README says',
      () async {
    await importAll();
    final groups = EventGroup.combine(await EventService.load());
    const meeting = 'Flag Etiquette';

    final ethan = await progressOf('Ethan Walker');
    final liam = await progressOf('Liam James Ortiz');
    final lucas = await progressOf('Lucas Greene');
    final oliver = await progressOf('Oliver Hayes');
    final charlotte = await progressOf('Charlotte Anne Rivera');
    final henry = await progressOf('Henry Vance');

    expect(idsAt(groups, meeting, ethan), contains('Scout 1a'));
    expect(idsAt(groups, meeting, charlotte), isEmpty);
    expect(idsAt(groups, meeting, henry), isEmpty);

    // Liam finished the first 8 Tenderfoot requirements. The 4 after those have
    // a row with no completion date, so they still count as to do.
    final liamIds = idsAt(groups, 'Winter Camp at Test Lake', liam);
    expect(liamIds, isNot(contains('Tenderfoot 1a')));
    expect(liamIds, isNot(contains('Tenderfoot 3b')));
    expect(liamIds, contains('Tenderfoot 3c'));
    expect(liamIds, contains('Second Class 1c'));

    expect(idsAt(groups, 'Wreaths for Veterans', lucas), ['Star 4']);
    expect(idsAt(groups, 'Wreaths for Veterans', oliver), ['Life 4']);
    expect(idsAt(groups, 'Fall Court of Honor', ethan), isEmpty);

    final swim = idsAt(groups, 'Swim Night at Test Town Pool', ethan);
    expect(swim, contains('Second Class 5b'));
    expect(swim, contains('First Class 6a'));
  });

  test('Jon Reed and Jon Reedy keep separate records', () async {
    await importAll();
    expect((await progressOf('Jon Reed')).rank, 'Tenderfoot');
    expect((await progressOf('Jon Reedy')).rank, 'Scout');
  });

  test('birthdays come in from the roster', () async {
    await importAll();
    final ethan = (await ScoutService.load())
        .firstWhere((s) => s['name'] == 'Ethan Walker');
    expect(ethan['birthday'], '2015-03-14');
  });

  test('only the deliberately odd record is unreadable', () async {
    await importAll();
    final scouts = await ScoutService.load();
    for (final scout in scouts) {
      final progress =
          await RequirementCalculator.load(scout['name']!, scout['rank'] ?? '');
      expect(progress.unreadableRows, scout['name'] == 'Mateo Núñez' ? 1 : 0,
          reason: scout['name']);
    }
  });

  test('the calendar has its events, types and combined campouts', () async {
    await importAll();
    final events = await EventService.load();
    final types = events.map((e) => e.type).toSet();
    expect(
      types,
      containsAll([
        'Meeting',
        'Campout',
        'Court of Honor',
        'Holiday',
        'Service Project',
        'Swim',
        'PLC',
        'Committee',
        'Roundtable',
        'Council Activity',
        'OA',
        'Elections',
        'No Meeting',
        'Advancement',
        'Fundraiser',
      ]),
    );

    final groups = EventGroup.combine(events);
    final winter =
        groups.firstWhere((g) => g.first.title == 'Winter Camp at Test Lake');
    expect(winter.days.length, 3);
    expect(winter.dateLabel, '12/11 to 12/13/2026');
    expect(OfficialFormService.formFor(winter), OfficialForm.scoutWorksheet);

    final meeting = groups.firstWhere((g) => g.first.title == 'Flag Etiquette');
    expect(OfficialFormService.formFor(meeting), OfficialForm.meetingPlan);
    expect(meeting.first.date, DateTime(2026, 11, 3));
  });

  test('both forms fill out from the troop\'s events', () async {
    await importAll();
    final groups = EventGroup.combine(await EventService.load());
    for (final title in ['Flag Etiquette', 'Winter Camp at Test Lake']) {
      final group = groups.firstWhere((g) => g.first.title == title);
      final bytes = await OfficialFormService.build(
        group: group,
        plan: EventPlan(eventId: group.id, notes: 'Bring rope'),
        troopName: 'Troop 9999',
      );
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    }
  });

  test('the statistics report matches the README', () async {
    await importAll();
    final stats = await TroopStatsService.build(
      since: DateTime(2026, 1, 1),
      now: DateTime(2026, 11, 7),
    );
    expect(stats.scouts.length, 15);
    expect(stats.campouts, 2);
    expect(stats.serviceProjects, 2);
    expect(stats.serviceHours, greaterThan(0));
    expect(stats.meritBadgesEarned, greaterThan(0));
    final older = await TroopStatsService.build(
      since: DateTime(2023, 1, 1),
      now: DateTime(2026, 11, 7),
    );
    expect(older.campouts, 3);
    expect(older.meritBadgesEarned, greaterThan(stats.meritBadgesEarned));
  });

  test('the sample data is fictional', () {
    for (final name in ['roster.csv', 'advancements.csv', 'activities.csv']) {
      final text = read(name);
      expect(RegExp(r'\b555-01\d\d\b').hasMatch(text) || name != 'roster.csv',
          isTrue);
    }
    final emails =
        RegExp(r'[\w.-]+@([\w.-]+)').allMatches(read('roster.csv')).toList();
    expect(emails, isNotEmpty);
    for (final email in emails) {
      expect(email.group(1), 'example.com');
    }
  });
}
