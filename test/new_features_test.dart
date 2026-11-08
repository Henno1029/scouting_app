import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/models/event_group.dart';
import 'package:scouting_app/scoutList_screen.dart';
import 'package:scouting_app/screens/ask_screen.dart';
import 'package:scouting_app/screens/event_detail_screen.dart';
import 'package:scouting_app/services/advancement_service.dart';
import 'package:scouting_app/services/attendance_service.dart';
import 'package:scouting_app/services/backup_service.dart';
import 'package:scouting_app/services/badge_planner_service.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/permission_service.dart';
import 'package:scouting_app/services/rank_progress_service.dart';
import 'package:scouting_app/services/requirement_calculator.dart';
import 'package:scouting_app/services/scout_service.dart';
import 'package:scouting_app/services/troop_question_service.dart';
import 'package:scouting_app/services/troop_stats_service.dart';
import 'package:scouting_app/utils/app_dates.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, String> row(String first, String last, String type, String title,
        {String id = '', String middle = '', String date = '01/02/2026'}) =>
    {
      'memberId': id,
      'firstName': first,
      'middleName': middle,
      'lastName': last,
      'advancementType': type,
      'advancement': title,
      'dateCompleted': date,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(PermissionService.reset);

  group('backup and restore', () {
    test('a backup restores everything exactly', () async {
      SharedPreferences.setMockInitialValues({
        'scouts': '[{"name":"Alex Tester"}]',
        'flag': true,
        'count': 3,
        'ratio': 1.5,
        'branding_patrol_names': ['Fox', 'Hawk'],
      });
      final backup = await BackupService.export(now: DateTime(2026, 11, 7));

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setString('scouts', '[]');
      await prefs.setString('stray', 'gone after restore');

      expect(await BackupService.restore(backup), 5);
      expect(prefs.getString('scouts'), '[{"name":"Alex Tester"}]');
      expect(prefs.getBool('flag'), isTrue);
      expect(prefs.getInt('count'), 3);
      expect(prefs.getDouble('ratio'), 1.5);
      expect(prefs.getStringList('branding_patrol_names'), ['Fox', 'Hawk']);
      expect(prefs.getString('stray'), isNull);
      expect(BackupService.fileName(DateTime(2026, 3, 4)),
          'troop_backup_2026-03-04.json');
    });

    test('a file that is not a backup changes nothing', () async {
      SharedPreferences.setMockInitialValues({'scouts': 'keep me'});
      for (final bad in ['not json', '{"app":"other","data":{}}', '[1,2]']) {
        await expectLater(
          BackupService.restore(Uint8List.fromList(utf8.encode(bad))),
          throwsFormatException,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('scouts'), 'keep me');
    });
  });

  group('matching scouts to records', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'import_advancement': jsonEncode([
          row('Jon', 'Reed', 'Rank', 'Tenderfoot Rank', id: '113'),
          row('Jon', 'Reedy', 'Rank', 'Scout Rank', id: '114'),
          row('Maya', 'Patel', 'Merit Badges', 'Chess MB'),
          row('Sam', 'Old Name', 'Merit Badges', 'Cooking MB', id: '200'),
        ]),
      });
    });

    test('one name inside another no longer shares records', () async {
      final index = await AdvancementIndex.load();
      expect(index.rank('Jon Reed'), 'Tenderfoot');
      expect(index.rank('Jon Reedy'), 'Scout');
    });

    test('member ID wins, so a renamed scout keeps their records', () async {
      final index = await AdvancementIndex.load();
      expect(index.advancements('Sam New Name', memberId: '200').single.title,
          'Cooking MB');
      expect(index.advancements('Sam New Name'), isEmpty);
    });

    test('a middle name on the roster still matches', () async {
      final index = await AdvancementIndex.load();
      expect(index.advancements('Maya Rose Patel').single.title, 'Chess MB');
    });
  });

  test('roster imports match by member ID and keep birthdays', () async {
    SharedPreferences.setMockInitialValues({
      'scouts': jsonEncode([
        {'name': 'Renamed Scout', 'rank': 'Scout', 'memberId': '300'},
      ]),
    });
    final target = CsvImportService.targetById('roster');
    final table = CsvImportService.parse(
      'BSA Member ID,First Name,Last Name,Patrol Name,Date of Birth\n'
      '300,Original,Name,Fox,2013-03-14\n'
      '301,Jo,Tester,Hawk,4/2/2014\n',
    );
    await CsvImportService.save(target, 'roster.csv',
        CsvImportService.apply(table, CsvImportService.autoMap(target, table.headers)));
    final scouts = await ScoutService.load();
    expect(scouts.length, 2);
    expect(scouts.first['name'], 'Renamed Scout');
    expect(scouts.first['patrol'], 'Fox');
    expect(scouts.first['birthday'], '2013-03-14');
    expect(AppDates.parse(scouts.last['birthday']!), DateTime(2014, 4, 2));
  });

  test('ages count whole years', () {
    expect(AppDates.ageOn(DateTime(2013, 3, 14), DateTime(2026, 3, 13)), 12);
    expect(AppDates.ageOn(DateTime(2013, 3, 14), DateTime(2026, 3, 14)), 13);
    expect(AppDates.ageOn(DateTime(2030, 1, 1), DateTime(2026, 1, 1)), isNull);
  });

  group('rank and Eagle progress', () {
    AdvancementEntry badge(String title) =>
        AdvancementEntry(type: 'Merit Badges', title: '$title MB');

    test('counts every requirement toward a lower rank', () {
      final progress = RankProgressService.compute(
        progress: const ScoutProgress(
          name: 'Alex',
          rank: 'Tenderfoot',
          completed: {'Second Class': {'1a', '2'}},
        ),
        advancements: const [],
        birthday: DateTime(2013, 3, 14),
        now: DateTime(2026, 11, 7),
      );
      expect(progress.nextRank, 'Second Class');
      expect(progress.requirementsTotal, 37);
      expect(progress.requirementsDone, 8, reason: '1a plus all of 2a to 2g');
      expect(progress.requirementsLeft, isNot(contains('2c')));
      expect(progress.age, 13);
      expect(progress.eagleDeadline, DateTime(2031, 3, 14));
    });

    test('Star, Life and Eagle count merit badges and Eagle slots', () {
      final progress = RankProgressService.compute(
        progress: const ScoutProgress(name: 'Alex', rank: 'First Class'),
        advancements: [
          badge('Camping'),
          badge('Lifesaving'),
          badge('Hiking'),
          badge('Chess'),
        ],
      );
      expect(progress.nextRank, 'Star');
      expect(progress.countsRequirements, isFalse);
      expect(progress.badgesEarned, 4);
      expect(progress.badgesNeeded, 6);
      expect(progress.eagleRequiredEarned, 3);
      expect(progress.eagleRequiredNeeded, 4);
      final emergency = progress.eagleSlots
          .firstWhere((slot) => slot.options.contains('Lifesaving'));
      expect(emergency.earnedWith, 'Lifesaving');
    });

    test('an Eagle Scout has no next rank', () {
      final progress = RankProgressService.compute(
        progress: const ScoutProgress(name: 'Alex', rank: 'Eagle'),
        advancements: const [],
      );
      expect(progress.nextRank, isNull);
    });
  });

  group('attendance', () {
    final camp = EventGroup([
      for (final day in [2, 3, 4])
        Event(id: 'c$day', title: 'Fall Camp', type: 'Campout', date: DateTime(2026, 10, day)),
    ]);
    final service = EventGroup([
      Event(id: 's', title: 'Park Cleanup', type: 'Service Project', date: DateTime(2026, 9, 19)),
    ]);

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'scouts': jsonEncode([
          {'name': 'Alex Tester', 'rank': 'Scout'},
          {'name': 'Sam Tester', 'rank': 'Scout'},
        ]),
        'import_activity': jsonEncode([
          {'scoutName': 'Alex Tester', 'date': '1/5/2026', 'activity': 'Hiking', 'event': 'Imported', 'miles': '4'},
        ]),
      });
    });

    test('saving fills the activity report, and saving again replaces it',
        () async {
      await AttendanceService.save(camp, {'Alex Tester', 'Sam Tester'});
      await AttendanceService.save(service, {'Alex Tester'}, hours: '3');
      var stats = await TroopStatsService.build(
          since: DateTime(2026, 1, 1), now: DateTime(2026, 11, 7));
      expect(stats.campouts, 1);
      expect(stats.troopCampingNights, 2);
      expect(stats.scoutCampingNights, 4);
      expect(stats.serviceHours, 3);
      expect(stats.hikingMiles, 4, reason: 'imported rows are kept');

      await AttendanceService.save(camp, {'Sam Tester'});
      stats = await TroopStatsService.build(
          since: DateTime(2026, 1, 1), now: DateTime(2026, 11, 7));
      expect(stats.scoutCampingNights, 2);
      expect((await AttendanceService.load(camp.id)).scouts, {'Sam Tester'});
      expect((await AttendanceService.load(service.id)).hours, '3');

      await AttendanceService.save(camp, {});
      expect((await AttendanceService.load(camp.id)).scouts, isEmpty);
    });

    testWidgets('Event Detail shows the event and saves who came',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: EventDetailScreen(group: camp)));
      await tester.pumpAndSettle();

      expect(find.text('10/2 to 10/4/2026'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Sam Tester'));
      await tester.pump();
      await tester.tap(find.text('Save attendance'));
      await tester.pumpAndSettle();

      expect(find.text('Saved attendance for 1 scout'), findsOneWidget);
      final saved = (await tester.runAsync(() => AttendanceService.load(camp.id)))!;
      expect(saved.scouts, {'Sam Tester'});
    });
  });

  group('permissions', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PermissionService.load();
    });

    test('with no users, everyone can do everything', () {
      final state = PermissionService.state.value;
      expect(state.setupMode, isTrue);
      expect(state.canEdit, isTrue);
      expect(state.canAdmin, isTrue);
    });

    test('the first user is an Admin and permissions turn on', () async {
      await PermissionService.addUser('Leader', PermissionLevel.viewer);
      final state = PermissionService.state.value;
      expect(state.setupMode, isFalse);
      expect(state.current!.level, PermissionLevel.admin);
      expect(state.canAdmin, isTrue);
    });

    test('viewers cannot edit until the password unlocks them', () async {
      await PermissionService.addUser('Leader', PermissionLevel.admin);
      await PermissionService.addUser('Parent', PermissionLevel.viewer);
      await PermissionService.setPassword('campfire');
      final parent = PermissionService.state.value.users.last;
      expect(await PermissionService.selectUser(parent.id), isTrue);

      var state = PermissionService.state.value;
      expect(state.canEdit, isFalse);
      expect(state.canAdmin, isFalse);
      await expectLater(
          PermissionService.addUser('Sneaky', PermissionLevel.admin),
          throwsStateError);

      expect(await PermissionService.unlock('wrong'), isFalse);
      expect(await PermissionService.unlock('campfire'), isTrue);
      state = PermissionService.state.value;
      expect(state.canEdit, isTrue);
      expect(state.canAdmin, isFalse);

      // The password lets them change their own level, but not others'.
      await PermissionService.setLevel(parent.id, PermissionLevel.editor);
      final leader = PermissionService.state.value.users.first;
      await expectLater(
          PermissionService.setLevel(leader.id, PermissionLevel.viewer),
          throwsStateError);
    });

    test('a viewer needs the password to switch to an Admin', () async {
      await PermissionService.addUser('Leader', PermissionLevel.admin);
      await PermissionService.addUser('Parent', PermissionLevel.viewer);
      await PermissionService.setPassword('campfire');
      final users = PermissionService.state.value.users;
      await PermissionService.selectUser(users.last.id);

      expect(await PermissionService.selectUser(users.first.id), isFalse);
      expect(await PermissionService.selectUser(users.first.id, password: 'campfire'),
          isTrue);
    });

    test('there is always at least one Admin', () async {
      await PermissionService.addUser('Leader', PermissionLevel.admin);
      final leader = PermissionService.state.value.users.single;
      await expectLater(
          PermissionService.setLevel(leader.id, PermissionLevel.editor),
          throwsStateError);
      await PermissionService.addUser('Helper', PermissionLevel.editor);
      await expectLater(
          PermissionService.removeUser(leader.id), throwsStateError);
    });

    test('users and the current user are remembered', () async {
      await PermissionService.addUser('Leader', PermissionLevel.admin);
      await PermissionService.addUser('Parent', PermissionLevel.viewer);
      final parent = PermissionService.state.value.users.last;
      await PermissionService.selectUser(parent.id);
      PermissionService.reset();
      await PermissionService.load();
      expect(PermissionService.state.value.current!.name, 'Parent');
    });

    testWidgets('a viewer sees no way to add or delete scouts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'scouts': jsonEncode([
          {'name': 'Alex Tester', 'rank': 'Scout', 'patrol': 'Fox'},
        ]),
      });
      await tester.runAsync(() async {
        await PermissionService.load();
        await PermissionService.addUser('Leader', PermissionLevel.admin);
        await PermissionService.addUser('Parent', PermissionLevel.viewer);
        await PermissionService.selectUser(
            PermissionService.state.value.users.last.id);
      });
      await tester.pumpWidget(MaterialApp(home: ScoutListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Alex Tester'), findsOneWidget);
      expect(find.text('Add Scout'), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.text('Print Scout Roster'), findsOneWidget);
    });
  });

  group('merit badge planner', () {
    test('lists who needs each badge, Eagle-required first', () async {
      SharedPreferences.setMockInitialValues({
        'scouts': jsonEncode([
          {'name': 'Alex Tester'},
          {'name': 'Sam Tester'},
          {'name': 'Jo Tester'},
        ]),
        'import_advancement': jsonEncode([
          row('Alex', 'Tester', 'Merit Badges', 'Swimming MB'),
          row('Sam', 'Tester', 'Swimming Merit Badge Requirements', '1 Safety'),
        ]),
      });
      final plan =
          await BadgePlannerService.plan(['Archery', 'swimming', 'Archery ']);
      expect(BadgePlannerService.parseList('Archery, swimming\nArchery '),
          ['Archery', 'swimming']);
      final swimming = plan.first;
      expect(swimming.badge, 'swimming');
      expect(swimming.eagleRequired, isTrue);
      expect(swimming.earned, ['Alex Tester']);
      expect(swimming.needIt, ['Jo Tester', 'Sam Tester']);
      expect(swimming.started, ['Sam Tester']);
      expect(plan.last.needIt.length, 3);
    });
  });

  test('the patrol leaderboard ranks by advancement per scout', () {
    final stats = TroopStats(
      since: DateTime(2026),
      until: DateTime(2026, 11, 7),
      scouts: [
        ScoutStats(name: 'A', patrol: 'Big', ranks: [EarnedItem('Scout', DateTime(2026))]),
        const ScoutStats(name: 'B', patrol: 'Big'),
        const ScoutStats(name: 'C', patrol: 'Big'),
        ScoutStats(name: 'D', patrol: 'Small', meritBadges: [EarnedItem('Chess', DateTime(2026))]),
        const ScoutStats(name: 'E'),
      ],
    );
    final board = stats.patrolLeaderboard;
    expect(board.map((p) => p.patrol), ['Small', 'Big']);
    expect(board.last.scouts, 3);
  });

  group('ask your troop', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'scouts': jsonEncode([
          {'name': 'Alex Tester', 'rank': 'Scout', 'patrol': 'Fox', 'birthday': '2013-03-14'},
        ]),
        'import_advancement': jsonEncode([
          row('Alex', 'Tester', 'Merit Badges', 'Camping MB'),
        ]),
        'events': jsonEncode([
          Event(id: 'e', title: 'Fall Camp', type: 'Campout', date: DateTime(2026, 11, 20)).toJson(),
        ]),
      });
    });

    test('the summary covers scouts, badges and the calendar', () async {
      final summary =
          await TroopQuestionService.troopSummary(now: DateTime(2026, 11, 7));
      expect(summary, contains('Alex Tester'));
      expect(summary, contains('patrol: Fox'));
      expect(summary, contains('age: 13'));
      expect(summary, contains('merit badges earned (1): Camping'));
      expect(summary,
          contains('- Swimming or Hiking or Cycling (1): Alex Tester'));
      expect(summary, contains('- Camping (1): Alex Tester'));
      expect(summary, contains('- Scout (1): Alex Tester'));
      expect(summary, contains('- Alex Tester: '));
      expect(summary, contains('Fall Camp (Campout)'));
    });

    test('asks local Ollama with thinking off', () async {
      late http.Request sent;
      final service = TroopQuestionService(
        client: MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode({'response': ' Alex needs it. '}), 200);
        }),
      );
      expect(await service.ask('Who needs Swimming?', summary: 'DATA'),
          'Alex needs it.');
      expect(sent.url.host, 'localhost');
      final body = jsonDecode(sent.body);
      expect(body['think'], isFalse);
      expect(body['prompt'], contains('DATA'));
      expect(body['prompt'], contains('Who needs Swimming?'));
    });

    test('gives null when Ollama is not reachable', () async {
      final service = TroopQuestionService(
        client: MockClient((_) async => http.Response('', 500)),
      );
      expect(await service.ask('Anything?', summary: 'DATA'), isNull);
    });

    testWidgets('the screen shows the answer', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AskScreen(
          service: TroopQuestionService(
            client: MockClient((_) async =>
                http.Response(jsonEncode({'response': 'Alex is closest.'}), 200)),
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), 'Who is closest?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text('Who is closest?'), findsOneWidget);
      expect(find.text('Alex is closest.'), findsOneWidget);
    });
  });
}
