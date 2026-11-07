import 'event.dart';

/// One real-world event, which may be stored as several calendar days. Imports
/// expand a campout's date range into one [Event] per day so that each day shows
/// on the calendar.
class EventGroup {
  /// Every day of the event, in date order. Never empty, and each has a date.
  final List<Event> days;

  const EventGroup(this.days);

  Event get first => days.first;

  /// The first day's id identifies the group, which also links it to its plan.
  String get id => first.id;

  DateTime get start => first.date!;

  DateTime get end => days.last.date!;

  bool get isMultiDay => _dayNumber(start) != _dayNumber(end);

  /// "10/2/2099", "10/2 to 10/4/2099", or with both years if they differ.
  String get dateLabel {
    final last = '${end.month}/${end.day}/${end.year}';
    if (!isMultiDay) return last;
    final opening = start.year == end.year
        ? '${start.month}/${start.day}'
        : '${start.month}/${start.day}/${start.year}';
    return '$opening to $last';
  }

  /// A count of days, using UTC so daylight saving changes can't skew it.
  static int _dayNumber(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  static String _matchKey(Event event) =>
      '${event.title.trim().toLowerCase()}|${event.type.trim().toLowerCase()}';

  /// Combines dated events with the same title and type on consecutive days.
  /// Undated events are left out. The result is in order of start date.
  static List<EventGroup> combine(List<Event> events) {
    final dated = events.where((event) => event.date != null).toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));

    final groups = <List<Event>>[];
    final openGroup = <String, List<Event>>{};
    for (final event in dated) {
      final key = _matchKey(event);
      final open = openGroup[key];
      if (open != null &&
          _dayNumber(event.date!) - _dayNumber(open.last.date!) <= 1) {
        open.add(event);
      } else {
        final group = [event];
        groups.add(group);
        openGroup[key] = group;
      }
    }
    return groups.map(EventGroup.new).toList();
  }
}
