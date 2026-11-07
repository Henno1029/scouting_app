import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/services/event_service.dart';
import 'package:scouting_app/widgets/event_edit_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpDialog(WidgetTester tester, Event event) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: EventEditDialog(event: event))),
    );
    await tester.pumpAndSettle();
  }

  Event eventOfType(String type) => Event(
        id: 'manual-1',
        title: 'Test event',
        date: DateTime(2027, 6, 15),
        type: type,
      );

  for (final type in [
    'Campout',
    'PLC',
    'Holiday',
    'Committee',
    'Council Activity',
    'OA',
    'Hunting',
    'Task',
    'Special Event',
    'Other',
    'Service',
    'Something Unexpected',
  ]) {
    testWidgets('opens for an event of type "$type"',
        (WidgetTester tester) async {
      await pumpDialog(tester, eventOfType(type));

      expect(tester.takeException(), isNull);
      expect(find.text(type), findsOneWidget);
    });
  }

  testWidgets('Save stores the edit', (WidgetTester tester) async {
    final event = eventOfType('PLC');
    await tester.runAsync(() => EventService.add(event));
    await pumpDialog(tester, event);

    await tester.enterText(find.byType(TextField).first, 'Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final events = (await tester.runAsync(EventService.load))!;
    expect(events.single.id, 'manual-1');
    expect(events.single.title, 'Renamed');
    expect(events.single.type, 'PLC');
  });
}
