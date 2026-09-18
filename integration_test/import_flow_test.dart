import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scouting_app/main.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/program_grid_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _advancementCsv = '''
BSA Member ID,First Name,Middle Name,Last Name,Advancement Type,Advancement,Version,Date Completed,Approved,Awarded
12972470,Ava,Marie,Smith,Rank,Scout,,03/10/2024,,
12972470,Ava,Marie,Smith,Rank,Tenderfoot,,06/10/2024,,
12972470,Ava,Marie,Smith,Rank,Life,,12/16/2025,,
12972470,Ava,Marie,Smith,Merit Badge,First Aid,,06/17/2024,,
12972471,Jaden,Lee,Jones,Merit Badge,Chess,,07/17/2025,,
''';

const _gridTsv = '''
Month\tProgram Feature\tWeek 1\tWeek 2\tWeek 3\tWeek 4\tWeek 5\tCamping\tEvent\tTasks\tHoliday\tService Project\tSpecial Event\tCouncil Activity\tPLC\tCommittee\tRoundtable\tOther\tHunting\tOA
November\tGear Up\t11/5/2026\t11/12/2026\t11/19/2026\t11/26/2026\t\t\t\t\t\t\t\t\t\t\t\t\t\t
\t\tGame night\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t
''';

const _rosterCsv = '''
UserID, BSA Member ID, First Name, Last Name, Nickname, Patrol Name
2778819,12972470,Henry,Welle,,Duck
2778820,12972471,Carter,Burns,,Falcons
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('advancement import auto-creates scouts and shows on detail',
      (tester) async {
    final table = CsvImportService.parse(_advancementCsv);
    final target = CsvImportService.targetById('advancement');
    final mapping = CsvImportService.autoMap(target, table.headers);
    final records = CsvImportService.apply(table, mapping);
    final result =
        await CsvImportService.save(target, 'advancement_e2e.csv', records);

    expect(result.scoutsAdded, 2);

    await tester.pumpWidget(TroopApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scout Page'));
    await tester.pumpAndSettle();

    expect(find.text('Ava Smith'), findsOneWidget);
    expect(find.text('Jaden Jones'), findsOneWidget);

    await tester.tap(find.text('Ava Smith'));
    await tester.pumpAndSettle();

    expect(find.text('First Aid'), findsOneWidget,
        reason: 'imported merit badge should show on the detail page');
    expect(find.text('Life'), findsWidgets,
        reason: 'imported rank should show on the detail page');
  });

  testWidgets('re-importing the same advancements adds zero duplicates',
      (tester) async {
    final table = CsvImportService.parse(_advancementCsv);
    final target = CsvImportService.targetById('advancement');
    final mapping = CsvImportService.autoMap(target, table.headers);
    final records = CsvImportService.apply(table, mapping);

    await CsvImportService.save(target, 'advancement_e2e.csv', records);
    final again = await CsvImportService.save(
        target, 'advancement_e2e.csv', records);

    expect(again.added, 0);
    expect(again.total, 5);
  });

  testWidgets('program grid tsv import shows events on the event page',
      (tester) async {
    final decoded = CsvImportService.decodeRows(_gridTsv);
    final rows = ProgramGridParser.toRows(decoded);
    final table =
        CsvTable(headers: rows.first, rows: rows.skip(1).toList());
    final target = CsvImportService.targetById('program_grid');
    final mapping = CsvImportService.autoMap(target, table.headers);
    final records = CsvImportService.apply(table, mapping);

    expect(records, isNotEmpty);
    expect(records.first['title'], 'Game night');
    await CsvImportService.save(target, 'grid_e2e.tsv', records);

    await tester.pumpWidget(TroopApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Event Page'));
    await tester.pumpAndSettle();

expect(find.text('Game night'), findsWidgets,
        reason: 'imported grid event should appear on the event page');
  });

  testWidgets('roster import populates scout list with patrol and memberId',
      (tester) async {
    final table = CsvImportService.parse(_rosterCsv);
    final target = CsvImportService.targetById('roster');
    final mapping = CsvImportService.autoMap(target, table.headers);
    final records = CsvImportService.apply(table, mapping);

    expect(records.first['name'], 'Henry Welle');
    expect(records.first['patrol'], 'Duck');
    final result =
        await CsvImportService.save(target, 'roster_e2e.csv', records);
    expect(result.scoutsAdded, 2);

    await tester.pumpWidget(TroopApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scout Page'));
    await tester.pumpAndSettle();

    expect(find.text('Henry Welle'), findsOneWidget);
    expect(find.text('Duck'), findsWidgets,
        reason: 'patrol label should appear in the scout list');
  });
}
