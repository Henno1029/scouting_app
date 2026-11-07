import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/services/advancement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'import_advancement': jsonEncode([
        {
          'firstName': 'Henry',
          'middleName': '',
          'lastName': 'Welle',
          'advancementType': 'Merit Badges',
          'advancement': 'Chess MB',
          'version': '2013',
          'dateCompleted': '07/17/2025',
          'approved': 'True',
          'awarded': 'False',
        },
        {
          'firstName': 'Henry',
          'middleName': '',
          'lastName': 'Welle',
          'advancementType': 'Rank',
          'advancement': 'Life Scout Rank',
          'version': '2016',
          'dateCompleted': '07/07/2026',
          'approved': 'True',
          'awarded': 'True',
        },
        {
          'firstName': 'Henry',
          'middleName': '',
          'lastName': 'Welle',
          'advancementType': 'Awards',
          'advancement': "Firem'n Chit (Scouts BSA)",
          'dateCompleted': '02/04/2024',
          'approved': 'True',
          'awarded': 'True',
        },
        {
          'firstName': 'Henry',
          'middleName': '',
          'lastName': 'Welle',
          'advancementType': 'Camping Merit Badge Requirements',
          'advancement': 'Camp at least 20 nights',
          'dateCompleted': '01/01/2025',
        },
        {
          'firstName': 'Someone',
          'middleName': '',
          'lastName': 'Else',
          'advancementType': 'Merit Badges',
          'advancement': 'Cooking MB',
          'dateCompleted': '05/05/2025',
        },
      ]),
    });
  });

  test('lists earned advancement including plural Merit Badges type', () async {
    final entries =
        await AdvancementService.importedAdvancements('Henry Welle');
    final types = entries.map((entry) => entry.type).toSet();
    expect(types, containsAll(['Merit Badges', 'Rank', 'Awards']));
    expect(entries.length, 3);

    final badge = entries.firstWhere((entry) => entry.isMeritBadge);
    expect(badge.displayTitle, 'Chess');
    expect(badge.approved, isTrue);
    expect(badge.awarded, isFalse);
  });

  test('only matches the requested scout', () async {
    final entries =
        await AdvancementService.importedAdvancements('Henry Welle');
    expect(entries.any((entry) => entry.title == 'Cooking MB'), isFalse);
  });

  test('requirement rows are separated from earned advancement', () async {
    final earned =
        await AdvancementService.importedAdvancements('Henry Welle');
    expect(earned.any((entry) => entry.isRequirement), isFalse);

    final requirements =
        await AdvancementService.importedRequirements('Henry Welle');
    expect(requirements.length, 1);
    expect(requirements.single.type, contains('Requirements'));
  });

  test('the shared index gives the same answers as a single lookup', () async {
    final index = await AdvancementIndex.load();
    final single = await AdvancementService.importedAdvancements('Henry Welle');
    expect(index.advancements('Henry Welle').map((e) => e.title),
        single.map((e) => e.title));
    expect(index.requirements('Henry Welle').single.title,
        'Camp at least 20 nights');
    expect(index.rank('Henry Welle'), 'Life');
    expect(index.advancements('Someone Else').single.title, 'Cooking MB');
    expect(index.advancements('Nobody Here'), isEmpty);
    expect(index.rank(''), isNull);
  });

  test('imported rank resolves the highest rank from long titles', () async {
    expect(await AdvancementService.importedRank('Henry Welle'), 'Life');
  });
}
