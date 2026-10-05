import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'entry_form.dart';
import 'update_banner.dart';

/// Startseite: Plus-/Minusstunden, Urlaub, Stunden eintragen, nächste Schichten, letzte Einträge (nur eigene Daten).
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});
  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final canEnter = s.can('hours.own') && s.tracksTime;
    return PageScaffold(
      navKey: 'overview',
      title: 'Hallo ${s.name.split(' ').first}',
      body: Loader<Json>(
        key: ValueKey(_version),
        load: () => s.refresh(),
        builder: (context, me, reload) => _OverviewBody(me: me, reload: reload),
      ),
      fab: canEnter
          ? FloatingActionButton.extended(
              key: const Key('addEntry'),
              onPressed: () async {
                final ok = await showEntryForm(context);
                if (!ok || !context.mounted) return;
                toast(context, 'Eingetragen.');
                setState(() => _version++);
              },
              icon: const Icon(Icons.add),
              label: const Text('Stunden eintragen'),
            )
          : null,
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.me, required this.reload});
  final Json me;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final d = me.o('dashboard') ?? {};
    final week = d.o('week') ?? {};
    final month = d.o('month');
    final vac = d.o('vacation');
    final recent = me.l('recent_entries');
    final shifts = d.l('shifts');
    final ot = d.i('overtime_seconds');
    final tracks = s.tracksTime;

    return ListView(padding: const EdgeInsets.all(16), children: [
      const UpdateBanner(),
      if (!tracks)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Dies ist ein Verwaltungskonto: Hier wird keine Zeit erfasst. Du kannst Mitarbeiter einteilen, Urlaube und Rollen verwalten und Einstellungen vornehmen.'),
          ),
        ),
      if (tracks && s.can('hours.own'))
        Wrap(spacing: 10, runSpacing: 10, children: [
          StatTile(label: 'Heute', value: '${Fmt.hm(d.i('today_seconds'))} h'),
          StatTile(label: 'Diese Woche', value: '${Fmt.hm(week.i('worked'))} h', sub: 'von ${Fmt.hm(week.i('target'))} h Soll'),
          if (month != null)
            StatTile(
              label: 'Dieser Monat',
              value: '${Fmt.hm(month.i('worked'))} h',
              sub: month.b('closed') ? 'Monat abgeschlossen' : 'Soll ${Fmt.hm(month.i('target'))} h',
            ),
          StatTile(
            label: 'Plus-/Minusstunden',
            value: '${Fmt.signed(ot)} h',
            sub: ot < 0 ? 'Minusstunden' : (ot > 0 ? 'Überstunden' : 'ausgeglichen'),
            color: AppTheme.signColor(context, ot),
          ),
          if (vac != null)
            StatTile(
              label: 'Resturlaub ${vac.i('year')}',
              value: '${Fmt.days(vac.d('remaining'))} Tage',
              sub: 'von ${Fmt.days(vac.d('entitlement') + vac.d('carryover'))} · ${Fmt.days(vac.d('pending'))} beantragt',
            ),
        ]),
      if (s.can('schedule.view')) ...[
        const SectionTitle('Meine Schichten (nächste 7 Tage)'),
        if (shifts.isEmpty)
          const Card(child: EmptyHint('Keine Schichten eingeplant.'))
        else
          Card(
            child: Column(children: [
              for (final sh in shifts)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.event_available),
                  title: Text('${Fmt.day(sh.s('date'))}  ${sh.s('start')}–${sh.s('end')}'),
                  subtitle: sh.s('note').isEmpty ? null : Text(sh.s('note')),
                  trailing: Text('${Fmt.minutes(sh.i('minutes'))} h'),
                ),
            ]),
          ),
      ],
      if (tracks && s.can('hours.own')) ...[
        const SectionTitle('Meine letzten Einträge'),
        if (recent.isEmpty)
          const Card(child: EmptyHint('Noch keine Einträge in den letzten 60 Tagen.'))
        else
          Card(
            child: Column(children: [
              for (final e in recent)
                ListTile(
                  dense: true,
                  title: Text('${Fmt.day(e.s('date'))}  ${e.s('start')}–${e.has('end') ? e.s('end') : '?'}'),
                  subtitle: e.s('note').isEmpty ? null : Text(e.s('note')),
                  trailing: Text('${Fmt.hm(e.i('worked_seconds'))} h', style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: e.b('editable')
                      ? () async {
                          if (await showEntryForm(context, entry: e)) await reload();
                        }
                      : null,
                ),
            ]),
          ),
      ],
      const SizedBox(height: 80),
    ]);
  }
}
