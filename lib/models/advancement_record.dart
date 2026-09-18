class AdvancementRecord {
  final String memberId;
  final String firstName;
  final String middleName;
  final String lastName;
  final String advancementType;
  final String advancement;
  final String version;
  final DateTime? dateCompleted;
  final bool approved;
  final bool awarded;

  const AdvancementRecord({
    required this.memberId,
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    required this.advancementType,
    required this.advancement,
    this.version = '',
    this.dateCompleted,
    this.approved = false,
    this.awarded = false,
  });

  String get fullName => [firstName, middleName, lastName]
      .where((part) => part.trim().isNotEmpty)
      .join(' ');

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'advancementType': advancementType,
        'advancement': advancement,
        'version': version,
        'dateCompleted': dateCompleted?.toIso8601String(),
        'approved': approved,
        'awarded': awarded,
      };

  factory AdvancementRecord.fromJson(Map<String, dynamic> json) {
    return AdvancementRecord(
      memberId: json['memberId']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      middleName: json['middleName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      advancementType: json['advancementType']?.toString() ?? '',
      advancement: json['advancement']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      dateCompleted: parseAdvancementDate(json['dateCompleted']?.toString() ?? ''),
      approved: json['approved'] == true,
      awarded: json['awarded'] == true,
    );
  }

  static DateTime? parseAdvancementDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed;
    final parts = trimmed.split(RegExp(r'[/-]'));
    if (parts.length == 3) {
      final month = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (month != null && day != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  static bool parseFlag(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed == '1' || trimmed == 'true' || trimmed == 'yes' || trimmed == 'y';
  }
}
