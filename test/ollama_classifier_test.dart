import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scouting_app/services/official_form_service.dart';
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
      ProgramTypeClassifier.keywordType('Court Of Honor Dinner', 'Event'),
      'Court of Honor',
    );
    expect(
      ProgramTypeClassifier.keywordType('Troop Elections', 'Event'),
      'Elections',
    );
    expect(
      ProgramTypeClassifier.keywordType('Youth Leadership Election', 'Event'),
      'Elections',
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

  test('weekly meetings keep their Meeting type, keywords never hijack them',
      () {
    final drafts = [
      ProgramEventDraft(
        title: 'Klondike Prep',
        date: DateTime(2027, 2, 3),
        type: 'Meeting',
      ),
      ProgramEventDraft(
        title: 'NO MEETING (Ash Wednesday)',
        date: DateTime(2027, 2, 10),
        type: 'Meeting',
      ),
      ProgramEventDraft(
        title: 'B & G Pool Party / Swim Tests',
        date: DateTime(2027, 2, 24),
        type: 'Meeting',
      ),
    ];
    final result = ProgramTypeClassifier.applyKeywords(drafts);
    expect(result.map((d) => d.type).toSet(), {'Meeting'},
        reason: 'week-meeting rows are already typed Meeting by the parser '
            'and must not be reclassified by title keywords');
  });

  test('ollama classifier returns empty map when host is unreachable', () async {
    final classifier = OllamaTypeClassifier(
      host: 'http://127.0.0.1:1',
      timeout: const Duration(milliseconds: 300),
    );
    final result = await classifier.classifyTitles(['Court of Honor']);
    expect(result, isEmpty);
  });

  group('section classifier', () {
    OllamaSectionClassifier replying(String response,
        {int status = 200, void Function(http.Request)? seen}) {
      return OllamaSectionClassifier(
        client: MockClient((request) async {
          seen?.call(request);
          return http.Response(jsonEncode({'response': response}), status);
        }),
      );
    }

    test('sections line up with the form', () {
      expect(OllamaSectionClassifier.sections.keys.toSet(),
          OfficialFormService.meetingSectionTitles.keys.toSet());
    });

    test('asks local Ollama, with thinking off, and returns the section',
        () async {
      late http.Request sent;
      final result = await replying('{"section": "group"}',
          seen: (request) => sent = request).classify('instruction');
      expect(result.reachable, isTrue);
      expect(result.section, 'group');
      expect(sent.url.host, 'localhost');
      final body = jsonDecode(sent.body);
      expect(body['think'], isFalse);
      expect(body['prompt'], contains('Item: "instruction"'));
    });

    test('none and made-up sections mean no section', () async {
      for (final reply in ['{"section": "none"}', '{"section": "lunch"}']) {
        final result = await replying(reply).classify('banana');
        expect(result.reachable, isTrue);
        expect(result.section, isNull);
      }
    });

    test('errors and unusable replies count as unreachable', () async {
      for (final classifier in [
        replying('', status: 500),
        replying(''),
        OllamaSectionClassifier(
          host: 'http://127.0.0.1:1',
          timeout: const Duration(milliseconds: 300),
        ),
      ]) {
        final result = await classifier.classify('instruction');
        expect(result.reachable, isFalse);
        expect(result.section, isNull);
      }
    });
  });
}