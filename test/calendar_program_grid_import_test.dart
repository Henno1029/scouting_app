import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/program_grid_parser.dart';

void main() {
  test('program calendar csv (comma) parses via delimiter detection', () {
    final file = File('data/Troop Planning Calendar - 2027.csv');
    if (!file.existsSync()) {
      print('MISSING data file - skipping');
      return;
    }
    final decoded = CsvImportService.decodeRows(file.readAsStringSync());
    final rows = ProgramGridParser.toRows(decoded);
    final table = rows.isEmpty
        ? CsvTable.empty
        : CsvTable(headers: rows.first, rows: rows.skip(1).toList());
    final target = CsvImportService.targetById('program_grid');
    final mapping = CsvImportService.autoMap(target, table.headers);
    final missing = CsvImportService.missingRequired(target, mapping);
    final records = CsvImportService.apply(table, mapping);

    print('decoded columns: ${decoded.first.length}');
    print('mapping: $mapping');
    print('missing: $missing');
    print('rows: ${table.rows.length}');

    expect(decoded.first.length, greaterThan(5),
        reason: 'comma delimiter should be detected');
    expect(mapping['date'], 'Date');
    expect(mapping['title'], 'Title');
    expect(mapping['type'], 'Type');
    expect(missing, isEmpty);
    expect(records, isNotEmpty);
  });

  test('program grid tsv parses via delimiter detection and maps', () {
    final file = File('data/Troop Planning Calendar - 2027.tsv');
    if (!file.existsSync()) {
      print('MISSING data file - skipping');
      return;
    }
    final decoded = CsvImportService.decodeRows(file.readAsStringSync());
    final rows = ProgramGridParser.toRows(decoded);
    final table = rows.isEmpty
        ? CsvTable.empty
        : CsvTable(headers: rows.first, rows: rows.skip(1).toList());
    final target = CsvImportService.targetById('program_grid');
    final mapping = CsvImportService.autoMap(target, table.headers);
    final missing = CsvImportService.missingRequired(target, mapping);
    final records = CsvImportService.apply(table, mapping);

    print('mapping: $mapping');
    print('missing: $missing');
    print('rows: ${table.rows.length}');
    print('first record: ${records.isEmpty ? 'n/a' : records.first}');

    expect(decoded.first.length, greaterThan(5),
        reason: 'tab delimiter should be detected');
    expect(mapping['date'], 'Date');
    expect(mapping['title'], 'Title');
    expect(missing, isEmpty);
    expect(records, isNotEmpty);
  });
}