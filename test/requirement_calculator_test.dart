import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/data/rank_requirements.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/services/advancement_service.dart';
import 'package:scouting_app/services/requirement_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Event eventOfType(String type) =>
      Event(id: type, title: type, type: type, date: DateTime(2099, 1, 1));

  List<String> ids(String type, ScoutProgress progress) =>
      RequirementCalculator.available(eventOfType(type), progress)
          .map((r) => '${r.rank} ${r.id}')
          .toList();

  const newScout = ScoutProgress(name: 'Test Scout');

  Map<String, String> row(String type, String title,
          {String date = '01/01/2025'}) =>
      {
        'firstName': 'Test',
        'lastName': 'Scout',
        'advancementType': type,
        'advancement': title,
        'dateCompleted': date,
      };

  Future<ScoutProgress> loadWith(List<Map<String, String>> rows,
      {String storedRank = ''}) {
    SharedPreferences.setMockInitialValues(
        {'import_advancement': jsonEncode(rows)});
    return RequirementCalculator.load('Test Scout', storedRank);
  }

  test('catalog has no duplicate rank and id pairs', () {
    final keys = rankRequirements.map((r) => '${r.rank} ${r.id}').toList();
    expect(keys.toSet().length, keys.length);
  });

  test('event type decides which requirements apply', () {
    expect(ids('Meeting', newScout), contains('Tenderfoot 3a'));
    expect(ids('Meeting', newScout), isNot(contains('Tenderfoot 1b')));

    expect(ids('Campout', newScout), contains('Tenderfoot 1b'));
    expect(ids('Campout', newScout), contains('Tenderfoot 3a'));
    expect(ids('Campout', newScout), contains('Second Class 1a'));

    expect(ids('Swim', newScout), contains('Second Class 5b'));
    expect(ids('Swim', newScout), isNot(contains('Tenderfoot 3a')));

    expect(ids('Service Project', newScout), contains('Tenderfoot 7b'));
  });

  test('event types with no requirements return nothing', () {
    for (final type in ['PLC', 'Court of Honor', 'No Meeting', 'Holiday', '']) {
      expect(RequirementCalculator.settingsFor(type), isEmpty);
      expect(ids(type, newScout), isEmpty);
    }
  });

  test('earned ranks are skipped', () {
    const scout = ScoutProgress(name: 'Test Scout', rank: 'Tenderfoot');
    final result = ids('Meeting', scout);
    expect(result.any((id) => id.startsWith('Scout ')), isFalse);
    expect(result.any((id) => id.startsWith('Tenderfoot ')), isFalse);
    expect(result, contains('Second Class 2f'));
    expect(result, contains('First Class 3b'));
  });

  test('Star and Life service only open at the rank below', () {
    expect(ids('Service', newScout), isNot(contains('Star 4')));
    expect(
      ids('Service', const ScoutProgress(name: 'T', rank: 'First Class')),
      ['Star 4'],
    );
    expect(
      ids('Service', const ScoutProgress(name: 'T', rank: 'Star')),
      ['Life 4'],
    );
    expect(
      ids('Service', const ScoutProgress(name: 'T', rank: 'Life')),
      isEmpty,
    );
  });

  test('requirement ids are read from the start of a title', () {
    final cases = {
      '1a': '1a',
      '1a. Present yourself': '1a',
      '1a Present yourself': '1a',
      '4.b': '4b',
      '#7b': '7b',
      'Req 2f': '2f',
      'Tenderfoot Rank Requirement 3d': '3d',
      'Second Class 8': '8',
      '5 Pocketknife safety': '5',
    };
    cases.forEach((title, id) {
      expect(RequirementCalculator.requirementIdOf(title), id, reason: title);
    });
    expect(RequirementCalculator.requirementIdOf('Camp for 20 nights'), isNull);
    expect(RequirementCalculator.requirementIdOf('Present yourself'), isNull);
  });

  test('rows are tied to the right rank', () {
    expect(RequirementCalculator.rankOfRow('Tenderfoot Rank Requirements', '1a'),
        'Tenderfoot');
    expect(RequirementCalculator.rankOfRow('Scout Rank Requirements', '1a'),
        'Scout');
    expect(RequirementCalculator.rankOfRow('Star Scout Rank Requirements', '4'),
        'Star');
    expect(RequirementCalculator.rankOfRow('Rank Requirements', 'First Class 3b'),
        'First Class');
    expect(
        RequirementCalculator.rankOfRow('Camping Merit Badge Requirements', '1a'),
        isNull);
    expect(RequirementCalculator.rankOfRow('Nova Award Requirements', '1a'),
        isNull);
  });

  test('completed requirements from imports are removed', () async {
    final progress = await loadWith([
      row('Tenderfoot Rank Requirements', '3a'),
      row('Tenderfoot Rank Requirements', '3b', date: ''),
      row('Second Class Rank Requirements', '6'),
    ]);
    final result = ids('Meeting', progress);
    expect(result, isNot(contains('Tenderfoot 3a')));
    expect(result, contains('Tenderfoot 3b'), reason: 'no completion date');
    expect(result, isNot(contains('Second Class 6a')));
    expect(result, isNot(contains('Second Class 6e')));
    expect(progress.unreadableRows, 0);
  });

  test('imported rank wins over stored rank', () async {
    final progress = await loadWith(
      [row('Rank', 'Second Class Scout Rank')],
      storedRank: 'Tenderfoot',
    );
    expect(progress.rank, 'Second Class');
  });

  test('stored rank is used when no rank was imported', () async {
    final progress = await loadWith([], storedRank: 'Tenderfoot');
    expect(progress.rank, 'Tenderfoot');
  });

  test('unmatched rank rows are counted, others are ignored', () async {
    final progress = await loadWith([
      row('Tenderfoot Rank Requirements', 'Pitch a tent'),
      row('Camping Merit Badge Requirements', 'Camp at least 20 nights'),
    ]);
    expect(progress.unreadableRows, 1);
  });

  test('requirement text stored as type Rank does not raise the rank', () async {
    final progress = await loadWith([
      row('Rank', 'Identify 10 kinds of wildlife'),
      row('Rank', 'Start a fire'),
      row('Rank', 'Tenderfoot Rank'),
    ]);
    expect(progress.rank, 'Tenderfoot');
    expect(progress.unreadableRows, 2);
  });

  test('rankFromTitle only matches a whole rank title', () {
    expect(AdvancementService.rankFromTitle('Life Scout Rank'), 'Life');
    expect(AdvancementService.rankFromTitle('Eagle Scout'), 'Eagle');
    expect(AdvancementService.rankFromTitle('Scout Rank'), 'Scout');
    expect(AdvancementService.rankFromTitle('First Class'), 'First Class');
    expect(AdvancementService.rankFromTitle('Save wildlife'), isNull);
  });
}
