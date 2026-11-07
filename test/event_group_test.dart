import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/models/event_group.dart';

void main() {
  Event day(String id, DateTime? date,
          {String title = 'Fall Camp', String type = 'Campout'}) =>
      Event(id: id, title: title, type: type, date: date);

  test('consecutive days with the same title and type combine', () {
    final groups = EventGroup.combine([
      day('sun', DateTime(2099, 10, 4)),
      day('fri', DateTime(2099, 10, 2)),
      day('sat', DateTime(2099, 10, 3)),
    ]);

    expect(groups.length, 1);
    expect(groups.single.days.map((d) => d.id), ['fri', 'sat', 'sun']);
    expect(groups.single.id, 'fri');
    expect(groups.single.isMultiDay, isTrue);
    expect(groups.single.dateLabel, '10/2 to 10/4/2099');
  });

  test('a gap, a new title or a new type starts a new group', () {
    final groups = EventGroup.combine([
      day('a', DateTime(2099, 10, 2)),
      day('gap', DateTime(2099, 10, 4)),
      day('title', DateTime(2099, 10, 5), title: 'Other Camp'),
      day('type', DateTime(2099, 10, 6), type: 'Service Project'),
    ]);

    expect(groups.map((g) => g.id), ['a', 'gap', 'title', 'type']);
  });

  test('weekly meetings stay separate', () {
    final groups = EventGroup.combine([
      day('w1', DateTime(2099, 3, 2), title: 'Meeting', type: 'Meeting'),
      day('w2', DateTime(2099, 3, 9), title: 'Meeting', type: 'Meeting'),
    ]);

    expect(groups.length, 2);
    expect(groups.first.isMultiDay, isFalse);
    expect(groups.first.dateLabel, '3/2/2099');
  });

  test('another event during a campout does not split it', () {
    final groups = EventGroup.combine([
      day('fri', DateTime(2099, 10, 2)),
      day('plc', DateTime(2099, 10, 3), title: 'PLC', type: 'PLC'),
      day('sat', DateTime(2099, 10, 3)),
    ]);

    expect(groups.length, 2);
    expect(groups.first.days.map((d) => d.id), ['fri', 'sat']);
    expect(groups.last.id, 'plc');
  });

  test('matching ignores case and stray spaces', () {
    final groups = EventGroup.combine([
      day('a', DateTime(2099, 10, 2), title: 'Fall Camp '),
      day('b', DateTime(2099, 10, 3), title: 'fall camp', type: 'CAMPOUT'),
    ]);

    expect(groups.length, 1);
  });

  test('ranges across month, year and daylight saving changes combine', () {
    expect(
      EventGroup.combine([
        day('a', DateTime(2099, 10, 31)),
        day('b', DateTime(2099, 11, 1)),
      ]).single.dateLabel,
      '10/31 to 11/1/2099',
    );
    expect(
      EventGroup.combine([
        day('a', DateTime(2098, 12, 31)),
        day('b', DateTime(2099, 1, 1)),
      ]).single.dateLabel,
      '12/31/2098 to 1/1/2099',
    );
    expect(
      EventGroup.combine([
        day('a', DateTime(2026, 3, 7)),
        day('b', DateTime(2026, 3, 8)),
        day('c', DateTime(2026, 3, 9)),
      ]).length,
      1,
    );
  });

  test('undated events are left out', () {
    expect(EventGroup.combine([day('none', null)]), isEmpty);
  });
}
