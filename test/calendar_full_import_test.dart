import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/event_service.dart';
import 'package:scouting_app/services/ollama_classifier.dart';
import 'package:scouting_app/services/program_grid_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('planning calendar imports every event type, not just meetings',
      () async {
    final file = File('data/Troop Planning Calendar - 2027.csv');
    if (!file.existsSync()) {
      print('MISSING data file - skipping');
      return;
    }
    SharedPreferences.setMockInitialValues({});
    final rows = CsvImportService.decodeRows(file.readAsStringSync());
    final drafts = ProgramTypeClassifier.applyKeywords(
        ProgramGridParser.parse(rows, layout: ProgramGridParser.detect(rows)));

    final draftTypes = <String, int>{};
    for (final draft in drafts) {
      draftTypes[draft.type] = (draftTypes[draft.type] ?? 0) + 1;
    }
    expect(draftTypes['Meeting'], greaterThan(0));
    for (final required in [
      'Campout',
      'Holiday',
      'PLC',
      'Committee',
      'Roundtable',
      'OA',
    ]) {
      expect(draftTypes[required], greaterThan(0),
          reason: '$required events should survive parsing');
    }
    expect(draftTypes.length, greaterThan(5));

    final table = CsvTable(
      headers: const ['Date', 'Title', 'Type', 'Location', 'Notes'],
      rows: drafts
          .map((d) => [
                d.date == null
                    ? ''
                    : '${d.date!.month}/${d.date!.day}/${d.date!.year}',
                d.title,
                d.type,
                d.location,
                d.notes,
              ])
          .toList(),
    );
    final target = CsvImportService.targetById('calendar');
    final mapping = CsvImportService.autoMap(target, table.headers);
    final records = CsvImportService.apply(table, mapping);
    await CsvImportService.save(
        target, 'Troop Planning Calendar - 2027.csv', records);

    final events = await EventService.load();
    expect(events.length, drafts.length,
        reason: 'every draft should reach the calendar');
    expect(events.every((event) => event.date != null), isTrue,
        reason: 'every imported event needs a parsed date to render');

    final eventTypes = <String, int>{};
    for (final event in events) {
      eventTypes[event.type] = (eventTypes[event.type] ?? 0) + 1;
    }
    expect(eventTypes, equals(draftTypes));
  });
}
