import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/services/year_calendar_pdf_service.dart';

void main() {
  test('year calendar PDF bytes are generated', () async {
    final events = [
      Event(id: 'e1', title: 'Troop Meeting', date: DateTime(2027, 1, 6), type: 'Meeting'),
      Event(id: 'e2', title: 'Campout', date: DateTime(2027, 3, 12), type: 'Campout'),
      Event(id: 'e3', title: 'Summer Camp',
          date: DateTime(2027, 7, 1), type: 'Event', location: 'Camp'),
    ];
    final bytes = await YearCalendarPdfService.buildYearCalendar(
      year: 2027,
      troopName: 'Troop 12',
      events: events,
    );
    expect(bytes.length, greaterThan(1000));
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });
}