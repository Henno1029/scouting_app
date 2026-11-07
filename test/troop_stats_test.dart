import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/scoutList_screen.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/troop_report_pdf_service.dart';
import 'package:scouting_app/services/troop_stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final today = DateTime(2026, 11, 7);

  Map<String, String> advancement(String first, String type, String title,
          String date) =>
      {
        'firstName': first,
        'lastName': 'Tester',
        'advancementType': type,
        'advancement': title,
        'dateCompleted': date,
      };

  Map<String, String> event(String date, String title, String type) =>
      {'date': date, 'title': title, 'type': type};

  void seed({
    List<Map<String, String>> records = const [],
    List<Map<String, String>> activity = const [],
    List<Map<String, String>> calendar = const [],
  }) {
    SharedPreferences.setMockInitialValues({
      'scouts': jsonEncode([
        {'name': 'Alex Tester', 'rank': 'Scout', 'patrol': 'Fox', 'memberId': '1'},
        {'name': 'Sam Tester', 'rank': 'Tenderfoot', 'patrol': 'Hawk'},
      ]),
      'import_advancement': jsonEncode(records),
      'import_activity': jsonEncode(activity),
      'import_calendar': jsonEncode(calendar),
    });
  }

  Future<TroopStats> statsSince(DateTime since) =>
      TroopStatsService.build(since: since, now: today);

  test('only ranks and merit badges since the date count, date included',
      () async {
    seed(records: [
      advancement('Alex', 'Rank', 'Tenderfoot Rank', '01/01/2026'),
      advancement('Alex', 'Rank', 'Scout Rank', '12/31/2025'),
      advancement('Alex', 'Merit Badges', 'Chess MB', '03/04/2026'),
      advancement('Alex', 'Merit Badges', 'Cooking MB', '11/30/2025'),
      advancement('Sam', 'Merit Badges', 'Chess MB', '05/05/2026'),
      advancement('Sam', 'Awards', 'Test Award', '06/06/2026'),
      advancement('Sam', 'Tenderfoot Rank Requirements', '3a Knot', '07/07/2026'),
    ]);

    final stats = await statsSince(DateTime(2026, 1, 1));
    final alex = stats.scouts.firstWhere((s) => s.name == 'Alex Tester');
    expect(alex.ranks.map((r) => r.title), ['Tenderfoot']);
    expect(alex.meritBadges.map((b) => b.title), ['Chess']);
    expect(stats.ranksEarned, 1);
    expect(stats.meritBadgesEarned, 2);
    expect(stats.awardsEarned, 1);
    expect(stats.requirementsCompleted, 1);
    expect(stats.scoutsWhoAdvanced, 1);
    expect(stats.scoutsWithBadges, 2);
    expect(stats.averageBadges, 1);
    expect(stats.topMeritBadges().first.key, 'Chess');
    expect(stats.topMeritBadges().first.value, 2);
    expect(stats.ranksEarnedByRank, {'Tenderfoot': 1});
  });

  test('every scout is listed, even with nothing earned', () async {
    seed();
    final stats = await statsSince(DateTime(2026, 1, 1));
    expect(stats.scouts.map((s) => s.name), ['Alex Tester', 'Sam Tester']);
    expect(stats.currentRanks, {'Scout': 1, 'Tenderfoot': 1});
  });

  test('records with no readable date are reported, not counted', () async {
    seed(records: [
      advancement('Alex', 'Merit Badges', 'Chess MB', ''),
      advancement('Alex', 'Rank', 'Scout Rank', 'someday'),
    ]);
    final stats = await statsSince(DateTime(2000, 1, 1));
    expect(stats.meritBadgesEarned, 0);
    expect(stats.undatedRecords, 2);
  });

  test('a multi-day campout counts once, and future ones not at all', () async {
    seed(calendar: [
      event('10/2/2026', 'Fall Camp', 'Campout'),
      event('10/3/2026', 'Fall Camp', 'Campout'),
      event('10/4/2026', 'Fall Camp', 'Campout'),
      event('6/1/2026', 'Overnight', 'Camping'),
      event('12/11/2026', 'Winter Camp', 'Campout'),
      event('11/6/2026', 'Ends Later', 'Campout'),
      event('11/7/2026', 'Ends Later', 'Campout'),
      event('11/8/2026', 'Ends Later', 'Campout'),
      event('1/5/2025', 'Old Camp', 'Campout'),
      event('9/1/2026', 'Troop Night', 'Meeting'),
    ]);
    final stats = await statsSince(DateTime(2026, 1, 1));
    expect(stats.campouts, 2);
    expect(stats.troopCampingNights, 2);
    expect(stats.eventsByType, {'Campout': 1, 'Camping': 1, 'Meeting': 1});
  });

  test('a campout in both the calendar and activity report counts once',
      () async {
    seed(
      calendar: [
        event('10/2/2026', 'Fall Camp', 'Campout'),
        event('10/3/2026', 'Fall Camp', 'Campout'),
      ],
      activity: [
        {'scoutName': 'Alex Tester', 'date': '10/2/2026', 'activity': 'Camping', 'event': 'Fall Camp', 'nights': '1'},
        {'scoutName': 'Sam Tester', 'date': '10/2/2026', 'activity': 'Camping', 'event': 'Fall Camp', 'nights': '1'},
        {'scoutName': 'Sam Tester', 'date': '7/1/2026', 'activity': 'Camping', 'event': 'Summer Camp', 'nights': '6'},
      ],
    );
    final stats = await statsSince(DateTime(2026, 1, 1));
    expect(stats.campouts, 2, reason: 'Fall Camp, plus Summer Camp from the log');
    expect(stats.troopCampingNights, 7);
    expect(stats.scoutCampingNights, 8);
  });

  test('hours, nights and miles come from columns or notes', () async {
    seed(activity: [
      {'scoutName': 'Alex Tester', 'date': '4/1/2026', 'activity': 'Service', 'event': 'Cleanup', 'hours': '2.5'},
      {'scoutName': 'Sam Tester', 'date': '4/1/2026', 'activity': 'Service', 'event': 'Cleanup', 'notes': 'Worked 3 hours'},
      {'scoutName': 'Tester, Sam', 'date': '5/1/2026', 'activity': 'Service Project', 'event': 'Food Drive', 'notes': '1 hr'},
      {'scoutName': 'Alex Tester', 'date': '6/1/2026', 'activity': 'Hiking', 'event': 'Ridge', 'notes': '5 miles'},
      {'scoutName': 'Alex Tester', 'date': '6/2/2026', 'activity': 'Hiking', 'event': 'Hill', 'miles': '2'},
      {'scoutName': 'Alex Tester', 'date': '1/1/2020', 'activity': 'Service', 'event': 'Old', 'hours': '50'},
      {'scoutName': 'Someone Else', 'date': '4/1/2026', 'activity': 'Meeting', 'event': 'Troop Night', 'notes': '9 hours'},
    ]);
    final stats = await statsSince(DateTime(2026, 1, 1));
    final alex = stats.scouts.firstWhere((s) => s.name == 'Alex Tester');
    final sam = stats.scouts.firstWhere((s) => s.name == 'Sam Tester');
    expect(alex.serviceHours, 2.5);
    expect(sam.serviceHours, 4);
    expect(stats.serviceHours, 6.5);
    expect(stats.hikingMiles, 7);
    expect(stats.serviceProjects, 2);
    expect(stats.activitiesLogged, 6);
  });

  test('re-importing an old activity row with hours does not double count',
      () async {
    seed(activity: [
      {'scoutName': 'Alex Tester', 'date': '4/1/2026', 'activity': 'Service', 'event': 'Cleanup'},
      {'scoutName': 'Alex Tester', 'date': '4/1/2026', 'activity': 'Service', 'event': 'Cleanup', 'hours': '3'},
    ]);
    final stats = await statsSince(DateTime(2026, 1, 1));
    expect(stats.serviceHours, 3);
    expect(stats.activitiesLogged, 1);
  });

  test('the activity import keeps hours, nights and miles columns', () {
    final target = CsvImportService.targetById('activity');
    final mapping = CsvImportService.autoMap(target, const [
      'Scout Name', 'Date', 'Activity', 'Service Hours', 'Nights', 'Miles Hiked',
    ]);
    expect(mapping['hours'], 'Service Hours');
    expect(mapping['nights'], 'Nights');
    expect(mapping['miles'], 'Miles Hiked');
  });

  test('both reports build, and long ones run onto more pages', () async {
    seed(records: [
      advancement('Alex', 'Merit Badges', 'Chess MB', '03/04/2026'),
    ]);
    int pages(List<int> bytes) =>
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

    final stats = await TroopReportPdfService.buildStatistics(
      stats: await statsSince(DateTime(2026, 1, 1)),
      troopName: 'Troop 000',
    );
    expect(latin1.decode(stats.sublist(0, 5)), '%PDF-');

    final roster = await TroopReportPdfService.buildRoster(
      scouts: [
        for (var i = 0; i < 80; i++)
          RosterEntry(name: 'Scout $i', rank: 'Star', patrol: i.isEven ? 'Fox' : ''),
      ],
      troopName: 'Troop 000',
      printedOn: today,
    );
    expect(pages(roster), greaterThan(1));
  });

  testWidgets('the Scout Page has both buttons, and statistics asks for a date',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    seed();
    await tester.pumpWidget(MaterialApp(home: ScoutListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Print Scout Roster'), findsOneWidget);
    await tester.tap(find.text('Print out Statistics'));
    await tester.pumpAndSettle();

    expect(find.text('Show statistics since'), findsOneWidget);
  });
}
