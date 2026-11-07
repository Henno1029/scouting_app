import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';
import '../models/event_plan.dart';
import 'event_service.dart';

/// Stores plans on this device, keyed by event id. Event ids stay the same when
/// an event is edited, so a plan follows its event.
class EventPlanService {
  static const String _key = 'event_plans';

  static Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  /// The saved plan for [event], or a starter plan if there isn't one yet.
  static Future<EventPlan> load(Event event) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = _decode(prefs.getString(_key))[event.id];
    if (stored is Map) {
      return EventPlan.fromJson(Map<String, dynamic>.from(stored));
    }
    return template(event);
  }

  static Future<void> save(EventPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    // No await between the read and the write, so quick successive saves can't
    // overwrite each other.
    final plans = _decode(prefs.getString(_key));
    plans[plan.eventId] = plan.toJson();
    await prefs.setString(_key, jsonEncode(plans));
  }

  /// Saves [plan] and writes its summary into the description of every day in
  /// [days], which is how the plan reaches the calendar and the PDF export.
  static Future<void> saveToCalendar(EventPlan plan, List<Event> days) async {
    await save(plan);
    for (final day in days) {
      await EventService.update(Event(
        id: day.id,
        title: day.title,
        date: day.date,
        location: day.location,
        type: day.type,
        description: mergeDescription(day.description, plan),
        activities: day.activities,
      ));
    }
  }

  static const String _summaryStart = 'Event plan';

  static final RegExp _existingSummary =
      RegExp('(^|\\n)$_summaryStart( \\(\\d+ min\\))?:[\\s\\S]*\$');

  /// [description] with its plan summary replaced by the one for [plan]. Text
  /// before the summary is kept. The summary is always last, so anything typed
  /// after it is replaced too.
  static String mergeDescription(String description, EventPlan plan) {
    final kept = description.replaceFirst(_existingSummary, '').trim();
    final summary = describe(plan);
    return [kept, summary].where((part) => part.isNotEmpty).join('\n');
  }

  /// A text summary of [plan], or an empty string if it has nothing in it.
  static String describe(EventPlan plan) {
    final items = plan.items
        .where((item) => item.title.isNotEmpty && !_isUntouchedTemplateRow(item))
        .toList();
    final total = items.fold<int>(0, (sum, item) => sum + item.minutes);
    final notes = plan.notes.trim();
    if (items.isEmpty && plan.requirements.isEmpty && notes.isEmpty) return '';

    final totalLabel = total > 0 ? ' ($total min)' : '';
    return [
      '$_summaryStart$totalLabel: ${items.map(describeItem).join('; ')}'.trim(),
      if (plan.requirements.isNotEmpty)
        'Covers: ${plan.requirements.join(', ')}',
      if (notes.isNotEmpty) 'Notes: $notes',
    ].join('\n');
  }

  static String describeItem(PlanItem item) {
    final text = StringBuffer(item.title);
    if (item.minutes > 0) text.write(' ${item.minutes} min');
    if (item.who.isNotEmpty) text.write(' (${item.who})');
    if (item.target.isNotEmpty) text.write(' by ${item.target}');
    if (item.notes.isNotEmpty) text.write(': ${item.notes}');
    return text.toString();
  }

  /// A starter row nobody has filled in, which the summary leaves out.
  static bool _isUntouchedTemplateRow(PlanItem item) {
    final isEmpty = item.minutes == 0 &&
        item.who.isEmpty &&
        item.notes.isEmpty &&
        item.target.isEmpty;
    if (!isEmpty) return false;
    return [..._meeting, ..._phases]
        .any((row) => row.title == item.title);
  }

  /// A starter agenda for the event's type, meant to be edited.
  static EventPlan template(Event event) => EventPlan(
        eventId: event.id,
        items: event.isMeeting ? _meeting : _phases,
      );

  /// The sections of the official Meeting Plan. The minutes add up to the 90
  /// the form prints, leaving out Preopening and After the Meeting, which fall
  /// outside the meeting. The three skills levels run at the same time.
  static const List<PlanItem> _meeting = [
    PlanItem(title: 'Preopening', minutes: 15),
    PlanItem(title: 'Opening Ceremony', minutes: 5),
    PlanItem(title: 'Group Instruction', minutes: 10),
    PlanItem(title: 'Skills Instruction: Essential', minutes: 30),
    PlanItem(title: 'Skills Instruction: Challenging'),
    PlanItem(title: 'Skills Instruction: Advanced'),
    PlanItem(title: 'Breakout Groups (Patrol Meetings)', minutes: 15),
    PlanItem(title: 'Game or Challenge', minutes: 20),
    PlanItem(title: 'Closing', minutes: 10),
    PlanItem(title: 'After the Meeting', minutes: 10),
  ];

  /// The worksheet's own examples of phases, plus a wrap-up.
  static const List<PlanItem> _phases = [
    PlanItem(title: 'Choose a location'),
    PlanItem(title: 'Set the agenda'),
    PlanItem(title: 'Secure equipment'),
    PlanItem(title: 'Carry out the event'),
    PlanItem(title: 'Clean up and review'),
  ];
}
