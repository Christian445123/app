import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'entry_form.dart';

Color statusColor(String s) => s == 'approved' ? AppTheme.ok : (s == 'rejected' ? AppTheme.danger : AppTheme.warn);

/// Abwesenheiten (Urlaub, Krank, Arzt, Zeitausgleich, Sonstiges): beantragen, genehmigen/ablehnen, löschen; Urlaubskonto.
class AbsencesScreen extends StatefulWidget {
  const AbsencesScreen({super.key});
  @override
  State<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends State<AbsencesScreen> {
  int _version = 0;

  static const _types = [
    MapEntry('vacation', 'Urlaub'),
    MapEntry('sick', 'Krankenstand'),
    MapEntry('doctor', 'Arzt'),
    MapEntry('comp', 'Zeitausgleich'),
    MapEntry('other', 'Sonstiges'),
  ];

  Future<void> _create(bool manage) async {
    final s = context.read<Session>();
    var users = <MapEntry<String, String>>[];
    if (manage) users = await guard(context, () => loadUsers(s.api)) ?? [];
    if (!mounted) return;
    final today = Fmt.iso(DateTime.now());
    var saved = false;
    await showFormSheet(
      context,
      title: manage ? 'Abwesenheit eintragen' : 'Abwesenheit beantragen',
      okLabel: manage ? 'Eintragen' : 'Beantragen',
      fields: [
        if (manage && users.isNotEmpty) FieldDef('user_id', 'Mitarbeiter', FieldType.dropdown, initial: '${s.userId}', options: users),
        const FieldDef('type', 'Art', FieldType.dropdown, initial: 'vacation', options: _types),
        FieldDef('date_from', 'Von', FieldType.date, initial: today, required: true),
        FieldDef('date_to', 'Bis', FieldType.date, initial: today, required: true),
        const FieldDef('hours', 'Stunden (nur 1 Tag, leer = ganzer Tag)', FieldType.number, hint: 'z. B. 2 für Arzttermin'),
        const FieldDef('note', 'Notiz', FieldType.text),
      ],
      onSave: (v) async {
        try {
          await s.api.post('absences/create', {
            'user_id': int.tryParse(v['user_id'] ?? '') ?? 0,
            'type': v['type'],
            'date_from': v['date_from'],
            'date_to': v['date_to'],
            'hours': v['hours'],
            'note': v['note'],
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
      toast(context, manage ? 'Eingetragen.' : 'Antrag gestellt.');
      setState(() => _version++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return PageScaffold(
      navKey: 'absences',
      title: 'Abwesenheiten',
      fab: FloatingActionButton.extended(
        onPressed: () => _create(s.can('absences.manage')),
        icon: const Icon(Icons.add),
        label: Text(s.can('absences.manage') ? 'Eintragen' : 'Beantragen'),
      ),
      body: Loader<Json>(
        key: ValueKey(_version),
        load: () => s.api.get('absences'),
        builder: (context, r, reload) {
          final rows = r.l('absences');
          final vac = r.o('vacation');
          final manage = r.b('can_manage');
          return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
            if (vac != null)
              Wrap(spacing: 10, runSpacing: 10, children: [
                StatTile(label: 'Anspruch ${vac.i('year')}', value: '${Fmt.days(vac.d('entitlement'))} Tage', sub: vac.d('carryover') > 0 ? '+ ${Fmt.days(vac.d('carryover'))} Übertrag' : null),
                StatTile(label: 'Genommen', value: '${Fmt.days(vac.d('taken'))} Tage', sub: '${Fmt.days(vac.d('pending'))} beantragt'),
                StatTile(label: 'Resturlaub', value: '${Fmt.days(vac.d('remaining'))} Tage', sub: 'nach Anträgen ${Fmt.days(vac.d('remaining_after_pending'))}'),
                StatTile(label: 'Krank / Arzt', value: '${Fmt.days(vac.d('sick_days'))} / ${Fmt.days(vac.d('doctor_days'))}', sub: 'Tage (genehmigt)'),
              ]),
            SectionTitle(manage ? 'Alle Abwesenheiten' : 'Meine Abwesenheiten'),
            if (rows.isEmpty)
              const Card(child: EmptyHint('Keine Einträge.'))
            else
              Card(
                child: Column(children: [
                  for (final a in rows) _AbsenceTile(a: a, manage: manage, onChanged: () => setState(() => _version++)),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}

class _AbsenceTile extends StatelessWidget {
  const _AbsenceTile({required this.a, required this.manage, required this.onChanged});
  final Json a;
  final bool manage;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.read<Session>();
    final range = a.s('date_from') == a.s('date_to') ? Fmt.date(a.s('date_from')) : '${Fmt.date(a.s('date_from'))} – ${Fmt.date(a.s('date_to'))}';
    final status = a.s('status');
    Future<void> setStatus(String st) async {
      final r = await guard(context, () => s.api.post('absences/status', {'id': a.i('id'), 'status': st}));
      if (r != null) onChanged();
    }

    return ListTile(
      title: Row(children: [
        Flexible(child: Text('${Fmt.absence(a.s('type'))}${a.has('hours') ? ' (${a.s('hours')} h)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Pill(Fmt.status(status), color: statusColor(status)),
      ]),
      subtitle: Text([if (manage) a.s('user_name'), range, if (a.s('note').isNotEmpty) a.s('note')].join(' · ')),
      trailing: PopupMenuButton<String>(
        enabled: (manage || a.b('deletable')),
        onSelected: (v) async {
          if (v == 'delete') {
            if (!await confirmDialog(context, 'Eintrag löschen?', ok: 'Löschen', danger: true)) return;
            if (!context.mounted) return;
            final r = await guard(context, () => s.api.post('absences/delete', {'id': a.i('id')}));
            if (r != null) onChanged();
          } else {
            await setStatus(v);
          }
        },
        itemBuilder: (_) => [
          if (manage && status != 'approved') const PopupMenuItem(value: 'approved', child: Text('Genehmigen')),
          if (manage && status != 'rejected') const PopupMenuItem(value: 'rejected', child: Text('Ablehnen')),
          if (manage && status != 'pending') const PopupMenuItem(value: 'pending', child: Text('Auf „Offen“ setzen')),
          if (a.b('deletable')) const PopupMenuItem(value: 'delete', child: Text('Löschen')),
        ],
      ),
    );
  }
}
