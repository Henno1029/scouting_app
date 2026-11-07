import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/models/event_group.dart';
import 'package:scouting_app/models/event_plan.dart';
import 'package:scouting_app/services/official_form_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  EventGroup groupOf(String type, {int days = 1}) => EventGroup([
        for (var i = 0; i < days; i++)
          Event(
            id: '$type$i',
            title: 'Test $type',
            type: type,
            location: 'Test Lake',
            date: DateTime(2099, 10, 2 + i),
          ),
      ]);

  int pageCount(List<int> bytes) =>
      RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

  const meetingRows = [
    PlanItem(title: 'Preopening', minutes: 15),
    PlanItem(title: 'Opening Ceremony', minutes: 5),
    PlanItem(title: 'Group Instruction', minutes: 10),
    PlanItem(title: 'Skills Instruction: Essential', minutes: 30),
    PlanItem(title: 'Skills Instruction: Advanced', minutes: 20),
    PlanItem(title: 'Breakout Groups (Patrol Meetings)', minutes: 15),
    PlanItem(title: 'Game or Challenge', minutes: 20),
    PlanItem(title: 'Closing', minutes: 10),
    PlanItem(title: 'After the Meeting', minutes: 10),
  ];

  test('meetings use the Meeting Plan and everything else the worksheet', () {
    expect(OfficialFormService.formFor(groupOf('Meeting')),
        OfficialForm.meetingPlan);
    for (final type in ['Campout', 'Camping', 'Swim', 'Service Project', '']) {
      expect(OfficialFormService.formFor(groupOf(type)),
          OfficialForm.scoutWorksheet);
    }
    expect(OfficialFormService.formFor(groupOf('Campout', days: 3)),
        OfficialForm.scoutWorksheet);
  });

  test('agenda rows find their Meeting Plan section', () {
    final cases = {
      'Preopening': 'preopening',
      'Pre-opening': 'preopening',
      'Opening ceremony': 'opening',
      'Skills instruction': 'essential',
      'Skills Instruction: Challenging': 'challenging',
      'Patrol meetings': 'breakout',
      'Interpatrol activity': 'game',
      'After the Meeting': 'after',
    };
    cases.forEach((title, section) {
      expect(OfficialFormService.meetingSection(title), section, reason: title);
    });
    expect(OfficialFormService.meetingSection('Custom row'), isNull);
  });

  test('clock times parse and format', () {
    const cases = {
      '7:00 PM': 19 * 60,
      '7pm': 19 * 60,
      '7:30 p.m.': 19 * 60 + 30,
      '12:00 AM': 0,
      '12:15 pm': 12 * 60 + 15,
      '19:05': 19 * 60 + 5,
    };
    cases.forEach((text, minutes) {
      expect(OfficialFormService.parseClock(text), minutes, reason: text);
    });
    for (final bad in ['', 'evening', '25:00', '13 pm', '7:99']) {
      expect(OfficialFormService.parseClock(bad), isNull, reason: bad);
    }
    expect(OfficialFormService.formatClock(19 * 60 + 5), '7:05 PM');
    expect(OfficialFormService.formatClock(0), '12:00 AM');
  });

  test('section times run in order, with skills taking the longest level', () {
    final times = OfficialFormService.meetingTimes(meetingRows, '7:00 PM');
    expect(times['preopening'], '6:45 PM');
    expect(times['opening'], '7:00 PM');
    expect(times['group'], '7:05 PM');
    expect(times['essential'], '7:15 PM');
    expect(times['breakout'], '7:45 PM');
    expect(times['game'], '8:00 PM');
    expect(times['closing'], '8:20 PM');
    expect(times['after'], '8:30 PM');
    expect(OfficialFormService.meetingTimes(meetingRows, 'soon'), isEmpty);
  });

  test('the meeting total leaves out preopening and after the meeting', () {
    expect(OfficialFormService.meetingMinutes(meetingRows), 90);
  });

  test('the form images are bundled', () async {
    for (final name in [
      'meeting_plan.jpg',
      'scout_planning_worksheet_1.jpg',
      'scout_planning_worksheet_2.jpg',
    ]) {
      final data = await rootBundle.load('assets/forms/$name');
      expect(data.lengthInBytes, greaterThan(1000), reason: name);
    }
  });

  test('a meeting fills one page when everything fits', () async {
    final bytes = await OfficialFormService.build(
      group: groupOf('Meeting'),
      plan: const EventPlan(
        eventId: 'x',
        items: meetingRows,
        details: {'startTime': '7:00 PM'},
      ),
      troopName: 'Troop 000',
    );
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(pageCount(bytes), 1);
  });

  test('meeting items with no box on the form go on an attached page',
      () async {
    final bytes = await OfficialFormService.build(
      group: groupOf('Meeting'),
      plan: const EventPlan(
        eventId: 'x',
        items: [PlanItem(title: 'Custom row', notes: 'Not on the form')],
        notes: 'Bring rope',
      ),
      troopName: 'Troop 000',
    );
    expect(pageCount(bytes), 2);
  });

  test('the worksheet is two pages when everything fits', () async {
    final bytes = await OfficialFormService.build(
      group: groupOf('Campout', days: 3),
      plan: const EventPlan(
        eventId: 'x',
        items: [
          PlanItem(
            title: 'Choose a location',
            who: 'SPL',
            target: '8/1',
            notes: 'Call the ranger; reserve site',
          ),
        ],
        details: {
          'goal': 'First overnight for new scouts',
          'teamMembers': 'Sam Tester, 555-0101, sam@example.com\nJo Tester',
        },
      ),
      troopName: 'Troop 000',
    );
    expect(pageCount(bytes), 2);
  });

  test('worksheet overflow goes on an attached page', () async {
    final tooManySteps = await OfficialFormService.build(
      group: groupOf('Campout'),
      plan: const EventPlan(
        eventId: 'x',
        items: [PlanItem(title: 'Phase', notes: 'a; b; c; d')],
      ),
      troopName: '',
    );
    expect(pageCount(tooManySteps), 3);

    final tooLong = await OfficialFormService.build(
      group: groupOf('Campout'),
      plan: EventPlan(
        eventId: 'x',
        details: {'hazards': 'long text ' * 60},
      ),
      troopName: '',
    );
    expect(pageCount(tooLong), 3);

    final tooManyPhases = await OfficialFormService.build(
      group: groupOf('Campout'),
      plan: EventPlan(
        eventId: 'x',
        items: [for (var i = 0; i < 6; i++) PlanItem(title: 'Phase $i')],
      ),
      troopName: '',
    );
    expect(pageCount(tooManyPhases), 3);
  });
}
