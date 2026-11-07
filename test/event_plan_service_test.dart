import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/models/event_plan.dart';
import 'package:scouting_app/services/event_plan_service.dart';
import 'package:scouting_app/services/event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Event eventOfType(String id, String type) =>
      Event(id: id, title: id, type: type, date: DateTime(2099, 1, 1));

  test('a new event gets a starter agenda for its type', () async {
    final meeting = await EventPlanService.load(eventOfType('m', 'Meeting'));
    expect(meeting.items.map((i) => i.title), contains('Breakout Groups (Patrol Meetings)'));

    final campout = await EventPlanService.load(eventOfType('c', 'Camping'));
    expect(campout.items.map((i) => i.title), contains('Choose a location'));

    final other = await EventPlanService.load(eventOfType('o', 'Swim'));
    expect(other.items.map((i) => i.title), contains('Choose a location'));
  });

  test('saved plans come back whole and stay separate per event', () async {
    final first = eventOfType('first', 'Meeting');
    final second = eventOfType('second', 'Meeting');

    await EventPlanService.save(const EventPlan(
      eventId: 'first',
      items: [
        PlanItem(title: 'Knots', minutes: 25, who: 'Fox Patrol', notes: 'Rope'),
      ],
      requirements: {'Tenderfoot 3a'},
      notes: 'Bring rope',
    ));

    final loaded = await EventPlanService.load(first);
    expect(loaded.items.single.title, 'Knots');
    expect(loaded.items.single.minutes, 25);
    expect(loaded.items.single.who, 'Fox Patrol');
    expect(loaded.items.single.notes, 'Rope');
    expect(loaded.requirements, {'Tenderfoot 3a'});
    expect(loaded.notes, 'Bring rope');

    final other = await EventPlanService.load(second);
    expect(other.items.first.title, 'Preopening');
  });

  const fullPlan = EventPlan(
    eventId: 'x',
    items: [
      PlanItem(title: 'Knots', minutes: 25, who: 'Fox Patrol', notes: 'Rope'),
      PlanItem(title: 'Game', minutes: 15),
      PlanItem(title: ''),
    ],
    requirements: {'Tenderfoot 3a', 'Second Class 2f'},
    notes: 'Bring rope',
  );

  test('the summary lists the agenda, requirements and notes', () {
    expect(
      EventPlanService.describe(fullPlan),
      'Event plan (40 min): Knots 25 min (Fox Patrol): Rope; Game 15 min\n'
      'Covers: Tenderfoot 3a, Second Class 2f\n'
      'Notes: Bring rope',
    );
    expect(EventPlanService.describe(const EventPlan(eventId: 'x')), '');
  });

  test('saving again replaces the summary and keeps other text', () {
    final once = EventPlanService.mergeDescription('Meet at church', fullPlan);
    expect(once, startsWith('Meet at church\nEvent plan (40 min): Knots'));

    final twice = EventPlanService.mergeDescription(
      once,
      const EventPlan(
        eventId: 'x',
        items: [PlanItem(title: 'Hike', minutes: 60)],
      ),
    );
    expect(twice, 'Meet at church\nEvent plan (60 min): Hike 60 min');

    expect(
      EventPlanService.mergeDescription(
          twice, const EventPlan(eventId: 'x')),
      'Meet at church',
    );
  });

  test('starter rows nobody filled in stay out of the summary', () {
    expect(
      EventPlanService.describe(const EventPlan(
        eventId: 'x',
        items: [
          PlanItem(title: 'Choose a location'),
          PlanItem(title: 'Set the agenda', who: 'PLC', target: '9/1'),
          PlanItem(title: 'My own row'),
        ],
      )),
      'Event plan: Set the agenda (PLC) by 9/1; My own row',
    );
  });

  test('other text mentioning a plan is left alone', () {
    const text = 'Event plan changed last year\nBring food';
    expect(
      EventPlanService.mergeDescription(
          text, const EventPlan(eventId: 'x')),
      text,
    );
  });

  test('saving to the calendar updates every day of the event', () async {
    final fri = Event(
        id: 'fri',
        title: 'Camp',
        type: 'Campout',
        location: 'Lake',
        date: DateTime(2099, 10, 2),
        activities: const ['Bring tents']);
    final sat = Event(
        id: 'sat', title: 'Camp', type: 'Campout', date: DateTime(2099, 10, 3));
    await EventService.add(fri);
    await EventService.add(sat);

    await EventPlanService.saveToCalendar(
      const EventPlan(eventId: 'fri', notes: 'Bring rope'),
      [fri, sat],
    );

    final events = await EventService.load();
    expect(events.length, 2);
    for (final event in events) {
      expect(event.description, contains('Notes: Bring rope'));
    }
    expect(events.first.location, 'Lake');
    expect(events.first.activities, ['Bring tents']);
    expect((await EventPlanService.load(fri)).notes, 'Bring rope');
  });

  test('saving to the calendar works for imported events', () async {
    SharedPreferences.setMockInitialValues({
      'import_calendar':
          '[{"date":"2099-06-15","title":"Summer Camp","type":"Campout"}]',
    });
    final imported = (await EventService.load()).single;

    await EventPlanService.saveToCalendar(
      EventPlan(eventId: imported.id, notes: 'Bring rope'),
      [imported],
    );

    final after = (await EventService.load()).single;
    expect(after.id, imported.id);
    expect(after.description, contains('Bring rope'));
  });

  test('quick successive saves for different events all stick', () async {
    await Future.wait([
      for (final id in ['a', 'b', 'c'])
        EventPlanService.save(EventPlan(eventId: id, notes: 'note $id')),
    ]);

    for (final id in ['a', 'b', 'c']) {
      final plan = await EventPlanService.load(eventOfType(id, 'Meeting'));
      expect(plan.notes, 'note $id');
    }
  });
}
