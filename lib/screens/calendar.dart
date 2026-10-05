import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

Color _typeColor(String type, String status) {
  final base = switch (type) {
    'vacation' => const Color(0xFF2563EB),
    'sick' => const Color(0xFFDC2626),
    'doctor' => const Color(0xFF9333EA),
    'comp' => const Color(0xFF0D9488),
    _ => const Color(0xFF64748B),
  };
  return status == 'pending' ? base.withValues(alpha: .45) : base;
}

/// Urlaubsplaner: Monatskalender, wer wann abwesend ist (Raster Mitarbeiter × Tage).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return PageScaffold(
      navKey: 'calendar',
      title: 'Urlaubsplaner',
      body: Column(children: [
        MonthBar(month: _month, onChanged: (m) => setState(() => _month = m)),
        Expanded(
          child: Loader<Json>(
            key: ValueKey(Fmt.ym(_month)),
            load: () => s.api.get('calendar', {'month': Fmt.ym(_month)}),
            builder: (context, r, reload) => _Grid(cal: r.o('calendar') ?? {}),
          ),
        ),
      ]),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.cal});
  final Json cal;

  static const _cell = 30.0;
  static const _nameW = 110.0;

  @override
  Widget build(BuildContext context) {
    final days = cal.l('days');
    final users = cal.l('users');
    final t = Theme.of(context);
    if (users.isEmpty) return const EmptyHint('Keine Mitarbeiter.');

    Widget head(Json d) {
      final holiday = d.s('holiday').isNotEmpty;
      final weekend = d.i('dow') >= 6;
      return Container(
        width: _cell,
        height: 40,
        alignment: Alignment.center,
        color: holiday ? AppTheme.warn.withValues(alpha: .25) : (weekend ? t.colorScheme.surfaceContainerHighest : null),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(d.s('weekday'), style: const TextStyle(fontSize: 9)),
          Text('${int.parse(d.s('date').substring(8))}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    Widget cell(Json d, Json c) {
      final a = c.o('absence');
      final holiday = d.s('holiday').isNotEmpty;
      final works = c.b('works');
      Color? bg;
      if (a != null) {
        bg = _typeColor(a.s('type'), a.s('status'));
      } else if (holiday) {
        bg = AppTheme.warn.withValues(alpha: .18);
      } else if (!works) {
        bg = t.colorScheme.surfaceContainerHighest.withValues(alpha: .6);
      }
      return Container(
        width: _cell,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, border: Border.all(color: t.colorScheme.outlineVariant.withValues(alpha: .4), width: .5)),
        child: a == null ? null : Text(Fmt.absenceLetters[a.s('type')] ?? '', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  const SizedBox(width: _nameW, height: 40),
                  for (final u in users)
                    Container(width: _nameW, height: 34, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 8), child: Text(u.s('name'), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  Container(width: _nameW, height: 30, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 8), child: const Text('Anwesend', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                ]),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(children: [
                      Row(children: [for (final d in days) head(d)]),
                      for (final u in users)
                        Row(children: [
                          for (final d in days) cell(d, (u.o('cells') ?? {}).o(d.s('date')) ?? {}),
                        ]),
                      Row(children: [
                        for (final d in days)
                          Container(width: _cell, height: 30, alignment: Alignment.center, child: Text('${d.i('working') - d.i('off')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 6, children: [
            for (final e in const [('vacation', 'Urlaub'), ('sick', 'Krank'), ('doctor', 'Arzt'), ('comp', 'Zeitausgleich'), ('other', 'Sonstiges')])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 14, height: 14, color: _typeColor(e.$1, 'approved')),
                const SizedBox(width: 4),
                Text(e.$2, style: const TextStyle(fontSize: 12)),
              ]),
            const Text('blass = beantragt · gelb = Feiertag/geschlossen', style: TextStyle(fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}
