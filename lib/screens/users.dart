import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Mitarbeiterverwaltung: Stammdaten, Rolle, Arbeitszeitmodell (Stunden je Wochentag), Urlaub, Überstunden-Buchungen.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  int _version = 0;

  void _reload() => setState(() => _version++);

  String _dayHoursText(Json u) {
    final dh = u.o('day_hours') ?? {};
    final keys = dh.keys.map((k) => int.tryParse(k) ?? 0).where((k) => k >= 1 && k <= 7).toList()..sort();
    return keys.map((k) => '$k:${dh['$k']}').join(',');
  }

  Future<void> _edit(Json? u) async {
    final s = context.read<Session>();
    final roles = await guard(context, () => s.api.get('roles'));
    if (roles == null || !mounted) return;
    final roleOpts = roles.l('roles').map((r) => MapEntry(r.s('id'), r.s('name'))).toList();
    final isNew = u == null;
    var saved = false;
    await showFormSheet(
      context,
      title: isNew ? 'Neuer Mitarbeiter' : 'Mitarbeiter bearbeiten',
      fields: [
        FieldDef('full_name', 'Name', FieldType.text, initial: u?.s('name') ?? '', required: true),
        FieldDef('personnel_number', 'Personalnummer', FieldType.text, initial: u?.s('personnel_number') ?? '', hint: isNew ? 'leer = automatisch vergeben' : null),
        FieldDef('role_id', 'Rolle', FieldType.dropdown, initial: u?.s('role_id') ?? '', options: roleOpts),
        FieldDef('day_hours', 'Arbeitszeitmodell (Soll-Stunden je Tag)', FieldType.dayHours, initial: u == null ? '1:8,2:8,3:8,4:8,5:8' : _dayHoursText(u)),
        FieldDef('time_tracking', 'Zeiterfassung aktiv', FieldType.checkbox, initial: (u?.b('time_tracking') ?? true) ? '1' : '0', hint: 'Aus = Verwaltungskonto (keine Stunden, kein Dienstplan, kein Urlaub)'),
        FieldDef('vacation_days', 'Urlaubsanspruch/Jahr (Tage)', FieldType.number, initial: u != null && u.has('vacation_days_override') ? '${u.d('vacation_days_override')}' : '', hint: 'leer = automatisch 5 Wochen'),
        FieldDef('vacation_carryover', 'Urlaubsübertrag (Tage)', FieldType.number, initial: u == null ? '0' : '${u.d('vacation_carryover')}'),
        FieldDef('vacation_carryover_year', 'Übertrag gilt für Jahr', FieldType.number, initial: u != null && u.has('vacation_carryover_year') ? u.s('vacation_carryover_year') : '${DateTime.now().year}'),
        FieldDef('start_date', 'Eintrittsdatum', FieldType.optDate, initial: u?.s('start_date') ?? ''),
        if (!isNew) FieldDef('active', 'Aktiv (darf sich anmelden)', FieldType.checkbox, initial: u.b('active') ? '1' : '0'),
        FieldDef('password', isNew ? 'Start-Passwort' : 'Neues Passwort (optional)', FieldType.password,
            required: isNew, hint: 'mindestens 8 Zeichen · muss beim ersten Login geändert werden'),
      ],
      onSave: (v) async {
        final dh = <String, double>{};
        for (final p in (v['day_hours'] ?? '').split(',')) {
          final kv = p.split(':');
          if (kv.length == 2) dh[kv[0]] = double.tryParse(kv[1]) ?? 0;
        }
        try {
          await s.api.post('users/save', {
            'id': u?.i('id') ?? 0,
            'full_name': v['full_name'],
            'personnel_number': v['personnel_number'],
            'role_id': int.tryParse(v['role_id'] ?? '') ?? 0,
            'day_hours': dh,
            'time_tracking': v['time_tracking'] == '1',
            'vacation_days': v['vacation_days'],
            'vacation_carryover': v['vacation_carryover'],
            'vacation_carryover_year': int.tryParse(v['vacation_carryover_year'] ?? '') ?? 0,
            'start_date': v['start_date'],
            'active': v['active'] != '0',
            'password': v['password'],
          });
          saved = true;
          return null;
        } on ApiException catch (e) {
          if (e.isAuth) await s.expire();
          return e.message;
        }
      },
    );
    if (saved && mounted) {
      toast(context, 'Gespeichert.');
      _reload();
    }
  }

  Future<void> _overtime(Json u) async {
    final s = context.read<Session>();
    var saved = false;
    await showFormSheet(
      context,
      title: 'Überstunden buchen – ${u.s('name')}',
      okLabel: 'Buchen',
      fields: [
        FieldDef('info', 'Aktueller Stand: ${Fmt.signed(u.i('overtime_seconds'))} h. Auszahlung = negative Stunden, Korrektur/Übertrag = positive.', FieldType.info),
        FieldDef('hours', 'Stunden (+/−)', FieldType.number, required: true, hint: 'z. B. -10 oder 2,5'),
        FieldDef('date', 'Datum', FieldType.date, initial: Fmt.iso(DateTime.now()), required: true),
        const FieldDef('note', 'Notiz', FieldType.text),
      ],
      onSave: (v) async {
        try {
          await s.api.post('overtime/adjust', {'user_id': u.i('id'), 'hours': v['hours'], 'date': v['date'], 'note': v['note']});
          saved = true;
          return null;
        } on ApiException catch (e) {
          if (e.isAuth) await s.expire();
          return e.message;
        }
      },
    );
    if (saved && mounted) {
      toast(context, 'Gebucht.');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return PageScaffold(
      navKey: 'users',
      title: 'Mitarbeiter',
      fab: s.can('users.manage')
          ? FloatingActionButton.extended(onPressed: () => _edit(null), icon: const Icon(Icons.person_add), label: const Text('Neu'))
          : null,
      body: Loader<Json>(
        key: ValueKey(_version),
        load: () => s.api.get('users'),
        builder: (context, r, reload) {
          final users = r.l('users');
          final manage = r.b('can_manage');
          return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
            for (final u in users)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: manage ? () => _edit(u) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${u.s('name')}  ·  Nr. ${u.s('personnel_number')}', style: const TextStyle(fontWeight: FontWeight.w700))),
                        if (!u.b('active')) const Pill('Inaktiv', color: AppTheme.danger),
                      ]),
                      const SizedBox(height: 4),
                      Text('${u.s('role')}${u.b('time_tracking') ? ' · ${Fmt.days(u.d('weekly_hours'))} h/Woche · ${((u['work_days'] as List?) ?? []).map((d) => Fmt.weekdays[(d as num).toInt()]).join(' ')}': ' · Verwaltungskonto (keine Zeiterfassung)'}'),
                      if (u.b('time_tracking')) ...[
                        Text('Überstunden: ${Fmt.signed(u.i('overtime_seconds'))} h', style: TextStyle(color: AppTheme.signColor(context, u.i('overtime_seconds')))),
                        Text('Urlaub ${u.o('vacation')?.i('year') ?? ''}: ${Fmt.days(u.o('vacation')?.d('remaining') ?? 0)} Tage übrig von ${Fmt.days((u.o('vacation')?.d('entitlement') ?? 0) + (u.o('vacation')?.d('carryover') ?? 0))}'),
                      ],
                      if (s.can('overtime.manage') && u.b('time_tracking'))
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(onPressed: () => _overtime(u), icon: const Icon(Icons.more_time, size: 18), label: const Text('Überstunden buchen')),
                        ),
                    ]),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
