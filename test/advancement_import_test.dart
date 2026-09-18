import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('advancement csv parses and maps cleanly', () {
    final file = File('data/Troop0033B_Advancement_20260917.csv');
    if (!file.existsSync()) {
      print('MISSING data file - skipping');
      return;
    }
    final table = CsvImportService.parse(file.readAsStringSync());
    final target = CsvImportService.targets.first;
    expect(target.id, 'advancement');
    final mapping = CsvImportService.autoMap(target, table.headers);

    final values = <String>{''};
    for (final header in table.headers) {
      expect(
        values.add(header),
        isTrue,
        reason: 'duplicate dropdown item value: "$header"',
      );
    }

    final missing = CsvImportService.missingRequired(target, mapping);
    final records = CsvImportService.apply(table, mapping);
    print('headers(${table.headers.length}): ${table.headers.join(', ')}');
    print('mapping: $mapping');
    print('missing: $missing');
    print('rows: ${table.rows.length}, records: ${records.length}');
    expect(missing, isEmpty);
    expect(records, isNotEmpty);
  });

  test('advancement save auto-creates missing scouts', () async {
    final file = File('data/Troop0033B_Advancement_20260917.csv');
    if (!file.existsSync()) {
      print('MISSING data file - skipping');
      return;
    }
    SharedPreferences.setMockInitialValues({});
    final table = CsvImportService.parse(file.readAsStringSync());
    final target = CsvImportService.targets.first;
    final mapping = CsvImportService.autoMap(target, table.headers);
    final records = CsvImportService.apply(table, mapping);
    final result = await CsvImportService.save(
        target, 'advancement_test.csv', records);

    final prefs = await SharedPreferences.getInstance();
    final scouts = (jsonDecode(prefs.getString('scouts') ?? '[]') as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
    final names = scouts.map((s) => s['name']).toSet();
    final hadHenryBefore = scouts.isNotEmpty;

    print('result: $result');
    print('scouts created: such result.scoutsAdded = ${result.scoutsAdded}');
    print('scout count: ${scouts.length}');
    print('Henry present: ${names.any((n) => (n ?? '').toLowerCase().contains('henry'))}');

    expect(result.scoutsAdded, greaterThan(0));
    expect(scouts.length, result.scoutsAdded, reason: 'empty seed roster');
    expect(hadHenryBefore, isTrue);
  });
}