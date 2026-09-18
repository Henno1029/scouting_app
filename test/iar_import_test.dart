import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/iar_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('iar csv parses, maps and saves as advancement rows', () async {
    final file = File('data/Troop0033BIAR_20260917.csv');
    if (!file.existsSync()) {
      print('MISSING data file - skipping');
      return;
    }
    SharedPreferences.setMockInitialValues({});

    final decoded = CsvImportService.decodeRows(file.readAsStringSync());
    final rows = IarParser.toRows(decoded);
    final table = rows.isEmpty
        ? CsvTable.empty
        : CsvTable(headers: rows.first, rows: rows.skip(1).toList());
    final target = CsvImportService.targetById('iar');
    expect(target.id, 'iar');
    expect(target.storageKey, 'import_advancement');

    final mapping = CsvImportService.autoMap(target, table.headers);
    final missing = CsvImportService.missingRequired(target, mapping);
    final records = CsvImportService.apply(table, mapping);

    print('headers(${table.headers.length}): ${table.headers.join(', ')}');
    print('mapping: $mapping');
    print('missing: $missing');
    print('records: ${records.length}');

    expect(mapping['memberId'], 'BSA Member ID');
    expect(mapping['firstName'], 'First Name');
    expect(mapping['lastName'], 'Last Name');
    expect(mapping['advancementType'], 'Advancement Type');
    expect(mapping['advancement'], 'Advancement');
    expect(mapping['dateCompleted'], 'Date Completed');
    expect(missing, isEmpty);
    expect(records, isNotEmpty);

    for (final record in records) {
      expect(record['memberId'], '12972470');
    }
    expect(
      records.any((r) => r['advancementType'] == 'Rank' &&
          r['advancement'] == 'Life'),
      isTrue,
      reason: 'Life rank header row should be present',
    );
    expect(
      records.any((r) => r['advancementType'] == 'Merit Badge' &&
          r['advancement'] == 'First Aid'),
      isTrue,
      reason: 'First Aid badge should be present',
    );
    expect(
      records.any((r) => r['advancementType'] == 'Merit Badge' &&
          r['advancement'] == 'Chess'),
      isTrue,
      reason: 'extra badge Chess should be present',
    );
    expect(
      records.every(
          (r) => r['dateCompleted'] == null || r['dateCompleted']!.isEmpty),
      isNot(true),
      reason: 'incomplete/percentage dates should be skipped',
    );

    final first = await CsvImportService.save(
        target, 'iar_test.csv', records);
    final second = await CsvImportService.save(
        target, 'iar_test.csv', records);

    final prefs = await SharedPreferences.getInstance();
    final stored = await CsvImportService.load('import_advancement');
    final scouts = prefs.getString('scouts') ?? '[]';

    print('first save: $first');
    print('second save: $second');
    print('stored advancement rows: ${stored.length}');

    expect(first.scoutsAdded, greaterThan(0));
    expect(second.scoutsAdded, 0);
    expect(stored.length, first.total);
    expect(scouts.toLowerCase(), contains('henry welle'));
  });
}