import 'package:intl/intl.dart';

DateTime? parseAppDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) {
    return value.isUtc ? value.toLocal() : value;
  }
  if (value is num) {
    final millis = value.abs() > 1000000000000
        ? value.toInt()
        : (value * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
  }
  final raw = value.toString().trim();
  if (raw.isEmpty || raw.toLowerCase() == 'null') return null;

  DateTime? parsed;
  parsed = DateTime.tryParse(raw);
  parsed ??= DateTime.tryParse(raw.replaceAll(' ', 'T'));

  if (parsed == null) {
    for (final pattern in const [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy/MM/dd HH:mm:ss',
      'yyyy-MM-dd',
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy',
    ]) {
      try {
        parsed = DateFormat(pattern).parse(raw, true);
        break;
      } catch (_) {}
    }
  }

  return parsed?.toLocal();
}

String formatAppDateTime(
  dynamic value, {
  String pattern = 'd MMM yyyy • h:mm a',
  String fallback = '--',
}) {
  final dt = value is DateTime ? value : parseAppDate(value);
  if (dt == null) return fallback;
  return DateFormat(pattern).format(dt);
}

String formatAppDate(dynamic value, {String pattern = 'd MMM yyyy'}) {
  return formatAppDateTime(value, pattern: pattern);
}

String formatAppTime(dynamic value, {String pattern = 'h:mm a'}) {
  return formatAppDateTime(value, pattern: pattern);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isYesterday(DateTime date, {DateTime? relativeTo}) {
  final base = (relativeTo ?? DateTime.now()).toLocal();
  final yesterday = DateTime(base.year, base.month, base.day).subtract(
    const Duration(days: 1),
  );
  return isSameDay(date, yesterday);
}
