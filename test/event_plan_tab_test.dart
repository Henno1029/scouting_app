import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scouting_app/models/event.dart';
import 'package:scouting_app/models/event_plan.dart';
import 'package:scouting_app/screens/calculation_screen.dart';
import 'package:scouting_app/screens/event_list_screen.dart';
import 'package:scouting_app/services/event_plan_service.dart';
import 'package:scouting_app/services/event_service.dart';
import 'package:scouting_app/services/ollama_classifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final meeting =
      Event(id: 'meet', title: 'Troop Night', type: 'Meeting', date: DateTime(2099, 5, 1));

  Future<void> pumpScreen(WidgetTester tester,
      {OllamaSectionClassifier? classifier}) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'scouts': jsonEncode([
        {'name': 'Alex Tester', 'rank': 'Scout'},
        {'name': 'Sam Tester', 'rank': 'Eagle'},
      ]),
      'events': jsonEncode([meeting.toJson()]),
    });
    await tester.pumpWidget(
        MaterialApp(home: CalculationScreen(sectionClassifier: classifier)));
    await tester.pumpAndSettle();
  }

  Future<void> chooseEvent(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Troop Night').last);
    await tester.pumpAndSettle();
  }

  Future<void> openPlans(WidgetTester tester) async {
    await tester.tap(find.text('Event Plans'));
    await tester.pumpAndSettle();
  }

  Future<EventPlan> savedPlan(WidgetTester tester) async =>
      (await tester.runAsync(() => EventPlanService.load(meeting)))!;

  testWidgets('both tabs exist and print only shows on calculations',
      (WidgetTester tester) async {
    await pumpScreen(tester);
    expect(find.text('Event Calculations'), findsOneWidget);
    expect(find.byIcon(Icons.print_outlined), findsOneWidget);

    await openPlans(tester);
    expect(find.byIcon(Icons.print_outlined), findsNothing);
    expect(find.text('Choose an event to plan it.'), findsOneWidget);
  });

  testWidgets('the chosen event carries over and loads a starter agenda',
      (WidgetTester tester) async {
    await pumpScreen(tester);
    await chooseEvent(tester);
    await openPlans(tester);

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'Breakout Groups (Patrol Meetings)'),
        findsOneWidget);
    expect(find.text('Meeting: 90 min'), findsOneWidget);
    expect(find.text('Fill out Meeting Plan'), findsOneWidget);
  });

  testWidgets('edits save automatically and survive leaving the tab',
      (WidgetTester tester) async {
    await pumpScreen(tester);
    await chooseEvent(tester);
    await openPlans(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Description').first, 'Knot relay');
    await tester.enterText(find.widgetWithText(TextField, '5').first, '10');
    await tester.pump();

    expect(find.text('Meeting: 95 min (the form prints 90)'), findsOneWidget);
    final plan = await savedPlan(tester);
    expect(plan.items.map((i) => i.notes), contains('Knot relay'));

    await tester.tap(find.text('Event Calculations'));
    await tester.pumpAndSettle();
    await openPlans(tester);
    expect(find.widgetWithText(TextField, 'Knot relay'), findsOneWidget);
  });

  OllamaSectionClassifier answering(String section) => OllamaSectionClassifier(
        client: MockClient((_) async => http.Response(
              jsonEncode({'response': jsonEncode({'section': section})}),
              200,
            )),
      );

  Future<void> addRow(WidgetTester tester, String title) async {
    await tester.tap(find.text('Add item'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Item').last, title);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('"instruction" goes into Group Instruction',
      (WidgetTester tester) async {
    await pumpScreen(tester, classifier: answering('group'));
    await chooseEvent(tester);
    await openPlans(tester);

    await addRow(tester, 'instruction');

    expect(find.text('Put "instruction" in Group Instruction'), findsOneWidget);
    final plan = await savedPlan(tester);
    expect(plan.items.length, 10, reason: 'no extra row is left behind');
    final section =
        plan.items.singleWhere((i) => i.title == 'Group Instruction');
    expect(section.notes, isEmpty, reason: 'it only repeats the section name');
    expect(section.minutes, 10);
  });

  testWidgets('a descriptive row keeps its words as the description',
      (WidgetTester tester) async {
    await pumpScreen(tester, classifier: answering('game'));
    await chooseEvent(tester);
    await openPlans(tester);

    await addRow(tester, 'relay race');

    final plan = await savedPlan(tester);
    final section =
        plan.items.singleWhere((i) => i.title == 'Game or Challenge');
    expect(section.notes, 'relay race');
    expect(find.widgetWithText(TextField, 'relay race'), findsOneWidget);
  });

  testWidgets('Undo puts the row back and it is not sorted again',
      (WidgetTester tester) async {
    await pumpScreen(tester, classifier: answering('preopening'));
    await chooseEvent(tester);
    await openPlans(tester);

    await addRow(tester, 'order pizza');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    var plan = await savedPlan(tester);
    expect(plan.items.length, 11);
    expect(plan.items.last.title, 'order pizza');
    expect(plan.items.first.notes, isEmpty);

    await tester.tap(find.widgetWithText(TextField, 'order pizza'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    plan = await savedPlan(tester);
    expect(plan.items.length, 11);
  });

  testWidgets('a name matching a section sorts without asking Ollama',
      (WidgetTester tester) async {
    var asked = false;
    await pumpScreen(
      tester,
      classifier: OllamaSectionClassifier(
        client: MockClient((_) async {
          asked = true;
          return http.Response('{}', 500);
        }),
      ),
    );
    await chooseEvent(tester);
    await openPlans(tester);

    await addRow(tester, 'patrol meetings');

    expect(asked, isFalse);
    expect(find.text('Put "patrol meetings" in Breakout Groups (Patrol Meetings)'),
        findsOneWidget);
  });

  testWidgets('without Ollama, the row stays and says why',
      (WidgetTester tester) async {
    await pumpScreen(
      tester,
      classifier: OllamaSectionClassifier(
        client: MockClient((_) async => http.Response('', 500)),
      ),
    );
    await chooseEvent(tester);
    await openPlans(tester);
    await addRow(tester, 'instruction');
    expect(find.textContaining('Couldn\'t reach Ollama'), findsOneWidget);
    expect((await savedPlan(tester)).items.length, 11);
  });

  testWidgets('with no matching section, the row stays and says why',
      (WidgetTester tester) async {
    await pumpScreen(tester, classifier: answering('none'));
    await chooseEvent(tester);
    await openPlans(tester);
    await addRow(tester, 'banana');
    expect(find.textContaining('didn\'t match a section'), findsOneWidget);
    expect((await savedPlan(tester)).items.length, 11);
  });

  testWidgets('worksheet rows are never sent to Ollama',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var asked = false;
    SharedPreferences.setMockInitialValues({
      'events': jsonEncode([
        Event(
          id: 'camp',
          title: 'Troop Night',
          type: 'Campout',
          date: DateTime(2099, 10, 2),
        ).toJson(),
      ]),
    });
    await tester.pumpWidget(MaterialApp(
      home: CalculationScreen(
        sectionClassifier: OllamaSectionClassifier(
          client: MockClient((_) async {
            asked = true;
            return http.Response('{}', 500);
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await chooseEvent(tester);
    await openPlans(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Choose a location'), 'instruction');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(asked, isFalse);
  });

  testWidgets('form section names are locked, added rows are not',
      (WidgetTester tester) async {
    await pumpScreen(tester);
    await chooseEvent(tester);
    await openPlans(tester);

    final section = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Closing'));
    expect(section.readOnly, isTrue);

    await tester.tap(find.text('Add item'));
    await tester.pump();
    final added = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Item').last);
    expect(added.readOnly, isFalse);
  });

  testWidgets('items can be added, moved and removed',
      (WidgetTester tester) async {
    await pumpScreen(tester);
    await chooseEvent(tester);
    await openPlans(tester);

    await tester.tap(find.text('Add item'));
    await tester.pump();
    var plan = await savedPlan(tester);
    expect(plan.items.length, 11);

    await tester.tap(find.byTooltip('Move down').first);
    await tester.pump();
    plan = await savedPlan(tester);
    expect(plan.items[0].title, 'Opening Ceremony');
    expect(plan.items[1].title, 'Preopening');

    await tester.tap(find.byTooltip('Remove item').first);
    await tester.pump();
    plan = await savedPlan(tester);
    expect(plan.items.length, 10);
    expect(plan.items[0].title, 'Preopening');
    expect(find.widgetWithText(TextField, 'Opening Ceremony'), findsNothing);
  });

  testWidgets('requirements show who needs them and can be ticked',
      (WidgetTester tester) async {
    await pumpScreen(tester);
    await chooseEvent(tester);
    await openPlans(tester);

    expect(find.textContaining('1 of 2 scouts need this'), findsWidgets);
    expect(find.widgetWithText(CheckboxListTile, 'Scout 1a'), findsNothing,
        reason: 'Alex has already earned Scout rank');

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Tenderfoot 1c'));
    await tester.pump();
    final plan = await savedPlan(tester);
    expect(plan.requirements, {'Tenderfoot 1c'});

    expect(find.widgetWithText(CheckboxListTile, 'First Class 7f'), findsNothing);
    await tester.tap(find.textContaining('Show all'));
    await tester.pump();
    expect(
        find.widgetWithText(CheckboxListTile, 'First Class 7f'), findsOneWidget);
  });

  testWidgets('Save writes the plan to the event, typing alone does not',
      (WidgetTester tester) async {
    await pumpScreen(tester);
    await chooseEvent(tester);
    await openPlans(tester);

    await tester.enterText(find.byType(TextField).last, 'Bring rope');
    await tester.pump();
    var events = (await tester.runAsync(EventService.load))!;
    expect(events.single.description, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    events = (await tester.runAsync(EventService.load))!;
    expect(events.single.description, contains('Notes: Bring rope'));
    expect(find.text('Plan saved to the calendar'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Bring rope'), findsOneWidget,
        reason: 'the tab keeps the plan open after saving');
  });

  testWidgets('a campout appears once and Save reaches every day',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final days = [
      for (final day in [2, 3, 4])
        Event(
          id: 'camp$day',
          title: 'Fall Camp',
          type: 'Campout',
          date: DateTime(2099, 10, day),
        ),
    ];
    SharedPreferences.setMockInitialValues({
      'events': jsonEncode(days.map((d) => d.toJson()).toList()),
    });
    await tester.pumpWidget(const MaterialApp(home: CalculationScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('10/2 to 10/4/2099 - Fall Camp'), findsWidgets);
    expect(find.textContaining('10/3/2099'), findsNothing);
    await tester.tap(find.textContaining('Fall Camp').last);
    await tester.pumpAndSettle();

    await openPlans(tester);
    expect(find.widgetWithText(TextField, 'Choose a location'), findsOneWidget);
    expect(find.text('Fill out Scout Planning Worksheet'), findsOneWidget);
    expect(find.text('Scout Planning Worksheet details'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Bring tents');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final events = (await tester.runAsync(EventService.load))!;
    expect(events.length, 3);
    for (final event in events) {
      expect(event.description, contains('Bring tents'));
    }
    expect(find.text('Plan saved to all 3 days on the calendar'), findsOneWidget);
  });

  testWidgets('the saved plan shows in the calendar day sheet',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'events': jsonEncode([
        Event(
          id: 'meet',
          title: 'Troop Night',
          type: 'Meeting',
          date: DateTime(2099, 5, 1),
          description: 'Notes: Bring rope',
        ).toJson(),
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: EventListScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bring rope'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Troop Night'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bring rope'), findsOneWidget);
  });

  testWidgets('notes save', (WidgetTester tester) async {
    await pumpScreen(tester);
    await chooseEvent(tester);
    await openPlans(tester);

    await tester.enterText(find.byType(TextField).last, 'Bring rope');
    await tester.pump();

    final plan = await savedPlan(tester);
    expect(plan.notes, 'Bring rope');
  });
}
