import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/services/calculation_pdf_service.dart';
import 'package:scouting_app/services/requirement_calculator.dart';

void main() {
  // PDFs load their font from the app's bundled assets.
  TestWidgetsFlutterBinding.ensureInitialized();

  final event = Event(
    id: 'camp',
    title: 'Fall Campout',
    type: 'Campout',
    location: 'Test Lake',
    date: DateTime(2099, 10, 2),
  );

  ScoutRequirements resultFor(ScoutProgress scout) =>
      ScoutRequirements(scout, RequirementCalculator.available(event, scout));

  int pageCount(List<int> bytes) =>
      RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

  test('builds a PDF covering every result state', () async {
    final bytes = await CalculationPdfService.build(
      event: event,
      troopName: 'Troop 000',
      results: [
        resultFor(const ScoutProgress(
          name: 'Alex Tester',
          rank: 'Second Class',
          unreadableRows: 2,
        )),
        resultFor(const ScoutProgress(name: 'Sam Tester', rank: 'Eagle')),
      ],
    );

    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('characters the default PDF font lacks do not break the build',
      () async {
    final bytes = await CalculationPdfService.build(
      event: Event(
        id: 'unicode',
        title: 'Scout’s Day — Café … \u{1F3D5}',
        type: 'Campout',
        date: DateTime(2099, 10, 2),
      ),
      troopName: 'Troop № 000',
      results: [
        resultFor(const ScoutProgress(name: 'Łukasz 李 Tester')),
      ],
    );

    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('common punctuation is swapped for versions the font can draw', () {
    expect(
      CalculationPdfService.printable('Scout’s “Day” — 1–2…'),
      'Scout\'s "Day" - 1-2...',
    );
  });

  test('a long list flows onto more pages', () async {
    final bytes = await CalculationPdfService.build(
      event: event,
      troopName: 'Troop 000',
      results: [
        for (var i = 0; i < 40; i++)
          resultFor(ScoutProgress(name: 'Scout $i')),
      ],
    );

    expect(pageCount(bytes), greaterThan(1));
  });
}
