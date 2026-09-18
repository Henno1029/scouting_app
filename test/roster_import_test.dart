import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/branding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rosterCsv = '''
UserID, BSA Member ID, First Name, Last Name, Nickname, Patrol Name, Rank
2778819,12972470,Henry,Welle,,Duck,
2778820,12972471,Carter,Burns,,Falcons,
2778821,12972472,Owen,Shelby,,Duck,Eagle
''';

Future<({int added, int total, int scoutsAdded})> _importRoster(String csv) {
  final table = CsvImportService.parse(csv);
  final target = CsvImportService.targetById('roster');
  final mapping = CsvImportService.autoMap(target, table.headers);
  final records = CsvImportService.apply(table, mapping);
  return CsvImportService.save(target, 'roster_test.csv', records);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('roster csv maps to scout list entries', () async {
    final result = await _importRoster(_rosterCsv);

    expect(result.added, 3);
    expect(result.total, 3);
    expect(result.scoutsAdded, 3);

    final scoutsKey = await CsvImportService.load('scouts');
    expect(scoutsKey.length, 3);

    final henry = scoutsKey.firstWhere((s) => s['name'] == 'Henry Welle');
    expect(henry['patrol'], 'Duck');
    expect(henry['memberId'], '12972470');
    expect(henry['rank'], '');

    final owen = scoutsKey.firstWhere((s) => s['name'] == 'Owen Shelby');
    expect(owen['rank'], 'Eagle');

    final patrols = await BrandingService.uniquePatrols();
    expect(patrols, containsAll(['Duck', 'Falcons']));
  });

  test('re-importing the same roster adds zero duplicates', () async {
    await _importRoster(_rosterCsv);
    final again = await _importRoster(_rosterCsv);

    expect(again.added, 0);
    expect(again.total, 3);
  });

  test('roster import merges with scouts created by advancement import',
      () async {
    final advancementTable = CsvImportService.parse(
      'First Name,Middle Name,Last Name,Advancement Type,Advancement,Date Completed\n'
      'Henry,,Welle,Rank,Life,12/16/2025\n',
    );
    final advancementTarget = CsvImportService.targetById('advancement');
    final advancementMapping =
        CsvImportService.autoMap(advancementTarget, advancementTable.headers);
    final advancementRecords =
        CsvImportService.apply(advancementTable, advancementMapping);
    await CsvImportService.save(
        advancementTarget, 'advancement_test.csv', advancementRecords);

    final result = await _importRoster(_rosterCsv);

    expect(result.added, 2, reason: 'Henry already exists from advancement');
    final scoutsKey = await CsvImportService.load('scouts');
    final henry = scoutsKey.firstWhere((s) => s['name'] == 'Henry Welle');
    expect(henry['rank'], 'Life', reason: 'rank preserved after merge');
    expect(henry['patrol'], 'Duck', reason: 'patrol filled in by roster');
  });
}