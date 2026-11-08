/// One row of a plan's agenda, or one planning phase for the Scout Planning
/// Worksheet.
class PlanItem {
  final String title;
  final int minutes;
  final String who;
  final String notes;

  /// Target date, used by the Scout Planning Worksheet's phases.
  final String target;

  const PlanItem({
    required this.title,
    this.minutes = 0,
    this.who = '',
    this.notes = '',
    this.target = '',
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'minutes': minutes,
    'who': who,
    'notes': notes,
    'target': target,
  };

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      title: json['title']?.toString() ?? '',
      minutes: int.tryParse(json['minutes']?.toString() ?? '') ?? 0,
      who: json['who']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
    );
  }
}

/// The plan for one calendar event, linked by the event's id.
class EventPlan {
  final String eventId;
  final List<PlanItem> items;

  /// Requirements to cover, as "Rank id" such as "Tenderfoot 3a".
  final Set<String> requirements;

  /// Materials, gear and anything else to remember.
  final String notes;

  /// Answers to the official form's own questions, by field key.
  final Map<String, String> details;

  const EventPlan({
    required this.eventId,
    this.items = const [],
    this.requirements = const {},
    this.notes = '',
    this.details = const {},
  });

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'items': items.map((item) => item.toJson()).toList(),
    'requirements': requirements.toList(),
    'notes': notes,
    'details': details,
  };

  factory EventPlan.fromJson(Map<String, dynamic> json) {
    return EventPlan(
      eventId: json['eventId']?.toString() ?? '',
      items: (json['items'] as List? ?? const [])
          .map(
            (item) => PlanItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      requirements: (json['requirements'] as List? ?? const [])
          .map((id) => id.toString())
          .toSet(),
      notes: json['notes']?.toString() ?? '',
      details: (json['details'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }
}
