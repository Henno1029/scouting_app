import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/services/csv_import_service.dart';
import 'package:scouting_app/services/event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seedImport() async {
    final target = CsvImportService.targetById('calendar');
    final table = CsvImportService.parse(
      'Date,Title,Type\n2027-06-15,Summer Camp,Campout\n',
    );
    final mapping = CsvImportService.autoMap(target, table.headers);
    final records = CsvImportService.apply(table, mapping);
    await CsvImportService.save(target, 'calendar_test.csv', records);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('imported events load into the calendar', () async {
    await seedImport();

    final events = await EventService.load();
    expect(events.length, 1);
    expect(events.single.title, 'Summer Camp');
  });

  test('deleting an imported event removes it on reload', () async {
    await seedImport();

    final events = await EventService.load();
    final imported = events.single;
    expect(imported.id.startsWith('import_calendar|'), isTrue);

    await EventService.delete(imported.id);

    final after = await EventService.load();
    expect(after, isEmpty);
  });

  test('deleting an imported event persists the tombstone', () async {
    await seedImport();

    final events = await EventService.load();
    await EventService.delete(events.single.id);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('deleted_imported_event_ids');
    expect(raw, isNotNull);
    expect(jsonDecode(raw!).length, 1);

    final after = await EventService.load();
    expect(after, isEmpty);
  });

  test('deleted manual event stays deleted', () async {
    await EventService.add(const Event(
      id: 'manual-event-1',
      title: 'Manual',
    ));

    final events = await EventService.load();
    expect(events.length, 1);
    final id = events.single.id;

    await EventService.delete(id);

    final after = await EventService.load();
    expect(after, isEmpty);
  });

  Event edited(Event event, String title) => Event(
        id: event.id,
        title: title,
        date: DateTime(2027, 7, 1),
        location: 'Lake',
        type: 'Holiday',
        description: 'Bring a tent',
        activities: event.activities,
      );

  test('editing an imported event keeps one copy with the same id', () async {
    await seedImport();
    final original = (await EventService.load()).single;

    await EventService.update(edited(original, 'First edit'));
    await EventService.update(edited(original, 'Second edit'));

    final after = (await EventService.load()).single;
    expect(after.id, original.id);
    expect(after.title, 'Second edit');
    expect(after.date, DateTime(2027, 7, 1));
    expect(after.location, 'Lake');
    expect(after.type, 'Holiday');
    expect(after.description, 'Bring a tent');
  });

  test('an edited imported event can be deleted', () async {
    await seedImport();
    final original = (await EventService.load()).single;
    await EventService.update(edited(original, 'Edited'));

    await EventService.delete(original.id);

    expect(await EventService.load(), isEmpty);
  });

  test('edits to an imported event survive re-importing the file', () async {
    await seedImport();
    final original = (await EventService.load()).single;
    await EventService.update(edited(original, 'Edited'));

    await seedImport();
    await EventService.clearDeletedImports('import_calendar');

    expect((await EventService.load()).single.title, 'Edited');
  });

  test('re-importing after deleting an edited event restores the original',
      () async {
    await seedImport();
    final original = (await EventService.load()).single;
    await EventService.update(edited(original, 'Edited'));
    await EventService.delete(original.id);

    await seedImport();
    await EventService.clearDeletedImports('import_calendar');

    expect((await EventService.load()).single.title, 'Summer Camp');
  });

  test('editing a manual event replaces it in place', () async {
    await EventService.add(const Event(id: 'manual-1', title: 'Manual'));
    final original = (await EventService.load()).single;

    await EventService.update(edited(original, 'Renamed'));

    final after = (await EventService.load()).single;
    expect(after.id, 'manual-1');
    expect(after.title, 'Renamed');

    await EventService.delete('manual-1');
    expect(await EventService.load(), isEmpty);
  });
}