import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/program_grid_parser.dart';

const _fixture = '''
Month\tProgram Feature\tWeek 1\tWeek 2\tWeek 3\tWeek 4\tWeek 5\tCamping\tEvent\tTasks\tHoliday\tService Project\tSpecial Event\tCouncil Activity\tPLC\tCommittee\tRoundtable\tOther\tHunting\tOA
January\tSkills for Klondike\t1/6/2027\t1/13/2027\t1/20/2027\t1/27/2027\t\t1/15-1/17\t1/9/2027\tBook Klondike\tNew Year's Day MLK Jr Day\t\t1/14/2027\t\t1/12/2027\tDecember 8\tJanuary 19\t\t1/23/2027\t1/10/2027
\t\tSled assessment\tSled repair\tKnots\tFirst Aid\t\tJennings\tPolar Bear Night\t\t\t\tWreaths cleanup\t\t\t\t\t\t\t
February\tSkills for First Aid Meet\t2/3/2027\t2/10/2027\t2/17/2027\t2/24/2027\t\t2/5/27-2/7/27\t\tBook First Aid Meet\tPresident's Day, Ash Wednesday\t\t\tKlondike\t\t\tFebruary 11\t\t2/19-2/21\t
\t\tKlondike Prep\tNO MEETING\tFirst Aid skill\tB & G Pool Party\t\tKlondike\t\t\t\t\t\t\t\t\t\t\t\t
''';

void main() {
  final drafts = ProgramGridParser.parse(
    CsvImportService.decodeRows(_fixture),
  );

  test('weekly meeting dates come from the months top date row', () {
    final meetings =
        drafts.where((d) => d.type == 'Meeting').toList();
    expect(meetings.length, 8, reason: '4 January + 4 February meetings');
    expect(
      meetings.first.date,
      DateTime(2027, 1, 6),
      reason: 'C column date belongs to week 1 of January',
    );
    expect(meetings[1].date, DateTime(2027, 1, 13));
    expect(meetings[2].date, DateTime(2027, 1, 20));
    expect(meetings[3].date, DateTime(2027, 1, 27));
    expect(meetings[4].date, DateTime(2027, 2, 3),
        reason: 'first week of February is the next month block');
  });

  test('meeting titles and notes use the detail row + program feature', () {
    final meetings =
        drafts.where((d) => d.type == 'Meeting').toList();
    expect(meetings[0].title, 'Sled assessment');
    expect(meetings[0].notes, contains('Week 1'));
    expect(meetings[0].notes, contains('Skills for Klondike'));
    expect(meetings[1].title, 'Sled repair');
    expect(meetings[5].notes, contains('Skills for First Aid Meet'));
  });

  test('camping ranges spanning one weekday to the next are expanded', () {
    final campouts = drafts.where((d) => d.type == 'Campout').toList();
    final january = campouts
        .where((d) => d.date!.year == 2027 && d.date!.month == 1)
        .toList();
    expect(january.map((d) => d.date), [
      DateTime(2027, 1, 15),
      DateTime(2027, 1, 16),
      DateTime(2027, 1, 17),
    ]);
    expect(january.first.title, 'Jennings');
    expect(january.first.location, 'Jennings');

    final february = campouts
        .where((d) => d.date!.year == 2027 && d.date!.month == 2)
        .toList();
    expect(february.map((d) => d.date), [
      DateTime(2027, 2, 5),
      DateTime(2027, 2, 6),
      DateTime(2027, 2, 7),
    ]);
  });

  test('event and special event columns produce single events', () {
    final events = drafts.where((d) => d.type == 'Event').toList();
    expect(events.length, 1);
    expect(events.first.title, 'Polar Bear Night');
    expect(events.first.date, DateTime(2027, 1, 9));

    final specials = drafts.where((d) => d.type == 'Special Event').toList();
    expect(specials.length, 1);
    expect(specials.first.title, 'Wreaths cleanup');
    expect(specials.first.date, DateTime(2027, 1, 14));
  });

  test('holiday names resolve to real dates for the block year', () {
    final holidays = drafts.where((d) => d.type == 'Holiday').toList();
    expect(holidays.map((d) => d.date), containsAllInOrder([
      DateTime(2027, 1, 1), // New Year's Day
      DateTime(2027, 1, 18), // MLK Jr Day (3rd Monday of January)
      DateTime(2027, 2, 10), // Ash Wednesday
      DateTime(2027, 2, 15), // President's Day (3rd Monday of February)
    ]));
    expect(holidays.first.title, "New Year's Day");
  });

  test('only the meaningful columns are imported', () {
    final types = drafts.map((d) => d.type).toSet();
    expect(types, containsAll(['Meeting', 'Campout', 'Event', 'Special Event',
        'Holiday']));
    expect(
      types.intersection({
        'PLC', 'Committee', 'Roundtable', 'Council Activity', 'OA',
        'Hunting', 'Other',
      }),
      isEmpty,
      reason: 'planning-only columns should not clutter the calendar',
    );
  });

  test('round trips through the import pipeline with required fields', () {
    final rows = ProgramGridParser.toRows(
      CsvImportService.decodeRows(_fixture),
    );
    final table = rows.isEmpty
        ? CsvTable.empty
        : CsvTable(headers: rows.first, rows: rows.skip(1).toList());
    final target = CsvImportService.targetById('program_grid');
    final mapping = CsvImportService.autoMap(target, table.headers);
    final missing = CsvImportService.missingRequired(target, mapping);
    final records = CsvImportService.apply(table, mapping);

    expect(missing, isEmpty);
    expect(records, isNotEmpty);
    expect(
      records.every((r) => (r['date'] ?? '').isNotEmpty),
      true,
      reason: 'every imported row needs a real date',
    );
  });
}