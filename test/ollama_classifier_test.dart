import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/services/ollama_classifier.dart';
import 'package:scouting_app/services/program_grid_parser.dart';

void main() {
  test('keyword classifier recognizes common troop event types', () {
    expect(
      ProgramTypeClassifier.keywordType('Court of Honor', 'Event'),
      'Court of Honor',
    );
    expect(
      ProgramTypeClassifier.keywordType('Crossover COH', 'Special Event'),
      'Court of Honor',
    );
    expect(
      ProgramTypeClassifier.keywordType('Klondike Camp', 'Event'),
      'Campout',
    );
    expect(
      ProgramTypeClassifier.keywordType('B & G Pool Party', 'Meeting'),
      'Swim',
    );
    expect(
      ProgramTypeClassifier.keywordType('Food Drive Cleanup', 'Special Event'),
      'Service Project',
    );
    expect(
      ProgramTypeClassifier.keywordType('Star Trek', 'Other'),
      'Other',
      reason: 'unknown titles keep the column-provided type',
    );
  });

  test('applyKeywords copies drafts and only touches the type field', () {
final drafts = [
        ProgramEventDraft(
          title: 'Court of Honor',
          date: DateTime(2027, 3, 3),
          type: 'Event',
          location: 'Hall',
          notes: 'Week 2',
        ),
        ProgramEventDraft(
          title: 'Gear Check',
          date: DateTime(2027, 3, 10),
          type: 'Event',
        ),
      ];
    final result = ProgramTypeClassifier.applyKeywords(drafts);

    expect(result.length, 2);
    expect(result[0].type, 'Court of Honor');
    expect(result[0].title, 'Court of Honor');
    expect(result[0].location, 'Hall');
    expect(result[0].notes, 'Week 2');
    expect(result[1].type, 'Event',
        reason: 'no keyword matches, original type is preserved');
  });

  test('ollama classifier returns empty map when host is unreachable', () async {
    final classifier = OllamaTypeClassifier(
      host: 'http://127.0.0.1:1',
      timeout: const Duration(milliseconds: 300),
    );
    final result = await classifier.classifyTitles(['Court of Honor']);
    expect(result, isEmpty);
  });
}