class ActivityRecord {
  final String scoutName;
  final DateTime? date;
  final String activity;
  final String event;
  final String location;
  final String notes;

  const ActivityRecord({
    required this.scoutName,
    this.date,
    required this.activity,
    this.event = '',
    this.location = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'scoutName': scoutName,
        'date': date?.toIso8601String(),
        'activity': activity,
        'event': event,
        'location': location,
        'notes': notes,
      };

  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    return ActivityRecord(
      scoutName: json['scoutName']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      activity: json['activity']?.toString() ?? '',
      event: json['event']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}
