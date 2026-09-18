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
}