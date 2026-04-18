class TimeUtils {
  /// Parse "HH:mm" string into a DateTime on the given date (defaults to today).
  static DateTime parseHHmm(String hhmm, [DateTime? date]) {
    final base = date ?? DateTime.now();
    final parts = hhmm.split(':');
    return DateTime(
      base.year, base.month, base.day,
      int.parse(parts[0]), int.parse(parts[1]),
    );
  }

  /// Format a DateTime to "HH:mm" (24-hour).
  static String toHHmm(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Format a TimeOfDay to "HH:mm" string.
  static String timeOfDayToHHmm(dynamic tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
  }

  /// Display "07:30" as "7:30 AM", "13:00" as "1:00 PM".
  static String toDisplayTime(String hhmm) {
    final parts = hhmm.split(':');
    int hour = int.parse(parts[0]);
    final min = parts[1];
    final suffix = hour < 12 ? 'AM' : 'PM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour:$min $suffix';
  }

  /// Convert weekday int (1=Mon … 6=Sat) to short key like 'M', 'Th'.
  static String dayKey(DateTime dt) {
    const map = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun'
    };
    return map[dt.weekday] ?? 'Mon';
  }

  /// Full day label from short key.
  static String dayLabel(String key) {
    const map = {
      'Sun': 'Sunday',
      'Mon': 'Monday',
      'Tue': 'Tuesday',
      'Wed': 'Wednesday',
      'Thu': 'Thursday',
      'Fri': 'Friday',
      'Sat': 'Saturday',
    };
    return map[key] ?? key;
  }

  /// Minutes until [startHHmm] from now. Negative = already past.
  static int minutesUntil(String startHHmm) {
    final now = DateTime.now();
    final start = parseHHmm(startHHmm, now);
    return start.difference(now).inMinutes;
  }

  /// True if now is within [startHHmm, endHHmm).
  static bool isNowBetween(String startHHmm, String endHHmm) {
    final now = DateTime.now();
    final start = parseHHmm(startHHmm, now);
    final end = parseHHmm(endHHmm, now);
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Parse the end time from a borrow schedule string and return a DateTime.
  ///
  /// Accepts formats like "7:00-9:00", "07:00 - 09:00",
  /// "7:00 AM - 9:00 PM", "7:00AM-9:00PM".
  /// Returns null if the string cannot be parsed.
  static DateTime? parseBorrowEndTime(String schedule) {
    try {
      // Strip spaces then split on '-' keeping only parts with digits
      final parts = schedule
          .split('-')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.length < 2) return null;

      // The end time is the last part
      final rawEnd = parts.last.trim();

      // Remove AM/PM markers and parse
      final ispm = rawEnd.toLowerCase().contains('pm');
      final clean = rawEnd
          .toLowerCase()
          .replaceAll('am', '')
          .replaceAll('pm', '')
          .trim();

      final colonParts = clean.split(':');
      if (colonParts.length < 2) return null;
      int hour = int.parse(colonParts[0].trim());
      final minute = int.parse(colonParts[1].trim());

      // Convert 12-hour → 24-hour
      if (ispm && hour != 12) hour += 12;
      if (!ispm && hour == 12) hour = 0;

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return null;
    }
  }
}
