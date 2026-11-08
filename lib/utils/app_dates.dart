class AppDates {
  static DateTime? parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed;
    final parts = trimmed.split(RegExp(r'[/-]'));
    if (parts.length == 3) {
      final month = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      var year = int.tryParse(parts[2]);
      if (month != null &&
          day != null &&
          year != null &&
          month >= 1 &&
          month <= 12) {
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  /// Whole years old on [on], or null if [birthday] is after it.
  static int? ageOn(DateTime birthday, DateTime on) {
    var age = on.year - birthday.year;
    if (on.month < birthday.month ||
        (on.month == birthday.month && on.day < birthday.day)) {
      age--;
    }
    return age < 0 ? null : age;
  }

  /// "3/14/2013" style, for showing a date.
  static String label(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  static String dayKey(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
