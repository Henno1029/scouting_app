class Event {
  final String id;
  final String title;
  final DateTime? date;
  final String location;
  final String type;
  final String description;
  final List<String> activities;

  const Event({
    required this.id,
    required this.title,
    this.date,
    this.location = '',
    this.type = '',
    this.description = '',
    this.activities = const [],
  });

  bool get isMeeting => type.trim().toLowerCase() == 'meeting';

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date?.toIso8601String(),
    'location': location,
    'type': type,
    'description': description,
    'activities': activities,
  };

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      location: json['location']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      activities:
          (json['activities'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}
