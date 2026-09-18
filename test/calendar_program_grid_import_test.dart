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

    DateTime? dateOf(Map<String, String> record) {
      final parts = (record['date'] ?? '').split('/');
      if (parts.length != 3) return null;
      final m = int.tryParse(parts[0]);
      final d = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (m == null || d == null || y == null) return null;
      return DateTime(y, m, d);
    }

    bool hasDate(DateTime target) =>
        records.any((r) => dateOf(r) == target);
    final types = records.map((r) => r['type'] ?? '').toSet();

    expect(records.length, greaterThan(100),
        reason: 'full year planning sheet yields one event per week, '
            'campout day, holiday and special event');

    expect(records.where((r) => r['type'] == 'Meeting').length,
        greaterThanOrEqualTo(40),
        reason: 'roughly weekly meetings across 12 months');

    expect(hasDate(DateTime(2027, 1, 15)), isTrue,
        reason: 'January camping 1/15-1/17 without a year resolves');
    expect(hasDate(DateTime(2027, 1, 17)), isTrue);
    expect(hasDate(DateTime(2027, 10, 1)), isTrue,
        reason: 'October camping 10/1-10/3 without a year resolves');
    expect(hasDate(DateTime(2027, 10, 3)), isTrue);

    expect(types, contains('Campout'));
    expect(types, contains('Holiday'));
    expect(types, contains('Event'));

    expect(hasDate(DateTime(2027, 1, 1)), isTrue,
        reason: 'New Year\'s Day holiday resolves');
    expect(hasDate(DateTime(2027, 1, 18)), isTrue,
        reason: 'MLK Jr Day (3rd Monday of January) resolves');

    expect(
      types.intersection({
        'PLC', 'Committee', 'Roundtable', 'Council Activity', 'OA',
        'Hunting', 'Other',
      }),
      isEmpty,
      reason: 'planning-only columns are not imported as events',
    );
  });
}