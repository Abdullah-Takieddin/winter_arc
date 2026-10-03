/// Date helpers. Days are local calendar dates with the time stripped; day
/// arithmetic goes through UTC so a DST switch never shifts a day count.
library;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String _two(int n) => n.toString().padLeft(2, '0');

/// Storage key, e.g. `2026-11-03`.
String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

const _weekdays = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
const _weekdaysShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _months = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];
const _monthsShort = [
  'Jan.',
  'Feb.',
  'März',
  'Apr.',
  'Mai',
  'Juni',
  'Juli',
  'Aug.',
  'Sept.',
  'Okt.',
  'Nov.',
  'Dez.',
];

/// `Montag, 3. November`
String longDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day}. ${_months[d.month - 1]}';

/// `23. Oktober`
String dayMonth(DateTime d) => '${d.day}. ${_months[d.month - 1]}';

/// `1. Okt.`
String shortDate(DateTime d) => '${d.day}. ${_monthsShort[d.month - 1]}';

/// `Mo`
String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

/// `Mi, 1. Okt.`
String dayLabel(DateTime d) => '${weekdayShort(d)}, ${shortDate(d)}';

/// Minutes since midnight → `23:04`.
String clock(int minutes) => '${_two(minutes ~/ 60 % 24)}:${_two(minutes % 60)}';

/// A duration in minutes → `7:08`.
String hm(int minutes) => '${minutes ~/ 60}:${_two(minutes % 60)}';

/// A goal duration → `8 h` or `7:30 h`.
String hoursLabel(int minutes) => minutes % 60 == 0 ? '${minutes ~/ 60} h' : '${hm(minutes)} h';

/// German thousands grouping: 3120 → `3.120`.
String grouped(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}
