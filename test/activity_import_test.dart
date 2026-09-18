import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/services/csv_import_service.dart';

void main() {
  test('activity log csv sniffs header and maps columns', () {
    final file = File('data/Troop0033BActivityLogReport_20260917 (2).csv');
    if (!file.existsSync()) {
      print('MISSING data file - skipping');
      return;
    }
    final table = CsvImportService.parse(file.readAsStringSync());
    final target = CsvImportService.targetById('activity');
    final mapping = CsvImportService.autoMap(target, table.headers);
    final missing = CsvImportService.missingRequired(target, mapping);
    final records = CsvImportService.apply(table, mapping);

    print('sniffed headers(${table.headers.length}): '
        '${table.headers.join(', ')}');
    print('mapping: $mapping');
    print('missing: $missing');
    print('rows: ${table.rows.length}, records: ${records.length}');
    print('first record: ${records.isEmpty ? 'n/a' : records.first}');

    expect(table.headers.first, 'BSA Member ID');
    expect(mapping['scoutName'], 'Last Name');
    expect(mapping['activity'], isNotEmpty);
    expect(mapping['event'], mapping['activity']);
    expect(missing, isEmpty);
    expect(records, isNotEmpty);
  });
}