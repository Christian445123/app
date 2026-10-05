import 'package:intl/intl.dart';

/// Anzeigeformate (Deutsch/Österreich) für Zeiten, Datum und Bezeichnungen.
class Fmt {
  static const weekdays = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  static const months = [
    '', 'Jänner', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
  ];

  /// Sekunden → "h:mm"
  static String hm(num seconds) {
    final neg = seconds < 0;
    final s = seconds.abs().round();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '${neg ? '-' : ''}$h:${m.toString().padLeft(2, '0')}';
  }

  /// Mit "+" bei positiven Werten (Plus-/Minusstunden).
  static String signed(num seconds) => '${seconds > 0 ? '+' : ''}${hm(seconds)}';

  static String minutes(num min) => hm(min * 60);

  static String days(num v) {
    final t = v.toStringAsFixed(1);
    return (t.endsWith('.0') ? t.substring(0, t.length - 2) : t).replaceAll('.', ',');
  }

  static String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static DateTime parse(String iso) => DateTime.tryParse(iso) ?? DateTime.now();
  static String ym(DateTime d) => DateFormat('yyyy-MM').format(d);

  static String date(String iso) =>
      iso.length >= 10 ? '${iso.substring(8, 10)}.${iso.substring(5, 7)}.${iso.substring(0, 4)}' : iso;

  /// "Mo 05.10."
  static String day(String iso) {
    if (iso.length < 10) return iso;
    final d = parse(iso);
    return '${weekdays[d.weekday]} ${iso.substring(8, 10)}.${iso.substring(5, 7)}.';
  }

  static String monthLabel(DateTime d) => '${months[d.month]} ${d.year}';

  static String dateTime(String s) {
    if (s.length < 16) return s;
    return '${date(s.substring(0, 10))} ${s.substring(11, 16)}';
  }

  static const absenceTypes = {
    'vacation': 'Urlaub',
    'sick': 'Krankenstand',
    'doctor': 'Arzt',
    'comp': 'Zeitausgleich',
    'other': 'Sonstiges',
    'away': 'abwesend',
  };
  static String absence(String key) => absenceTypes[key] ?? key;

  static const absenceStatus = {'pending': 'Offen', 'approved': 'Genehmigt', 'rejected': 'Abgelehnt'};
  static String status(String key) => absenceStatus[key] ?? key;

  static const absenceLetters = {'vacation': 'U', 'sick': 'K', 'doctor': 'A', 'comp': 'Z', 'other': 'S', 'away': '–'};
}
