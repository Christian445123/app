import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Monatsabschluss: Stunden pro Mitarbeiter automatisch summiert; Monat abschließen bzw. (Verwaltung) wieder öffnen.
class MonthsScreen extends StatefulWidget {
  const MonthsScreen({super.key});
  @override
  State<MonthsScreen> createState() => _MonthsScreenState();
}

class _MonthsScreenState extends State<MonthsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month - 1);
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final ym = Fmt.ym(_month);
    return PageScaffold(
      navKey: 'months',
      title: 'Monatsabschluss',
      body: Column(children: [
        MonthBar(month: _month, onChanged: (m) => setState(() => _month = m)),
        Expanded(
          child: Loader<Json>(
            key: ValueKey('$ym-$_version'),
            load: () => s.api.get('months', {'month': ym}),
            builder: (context, r, reload) {
              final rows = r.l('rows');
              final canAll = r.b('can_close_all');
              final closable = rows.where((x) => !x.b('closed') && x.b('can_close')).length;
              return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Die Stunden werden automatisch summiert. Nach dem Abschluss sind Änderungen am Monat gesperrt; nur die Verwaltung kann ihn wieder öffnen. Abschluss ist erst am letzten Tag des Monats möglich.',
                      style: TextStyle(fontSize: 12)),
                ),
                if (canAll && closable > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.lock),
                      label: Text('Alle offenen abschließen ($closable)'),
                      onPressed: () async {
                        if (!await confirmDialog(context, 'Alle $closable offenen Monate für $ym abschließen?', ok: 'Abschließen')) return;
                        if (!context.mounted) return;
                        final res = await guard(context, () => s.api.post('months/close_all', {'month': ym}));
                        if (res != null && context.mounted) {
                          toast(context, '${res.i('closed')} Monate abgeschlossen.');
                          setState(() => _version++);
                        }
                      },
                    ),
                  ),
                if (rows.isEmpty) const EmptyHint('Keine Mitarbeiter.'),
                for (final m in rows)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${m.s('name')}  ·  Nr. ${m.s('personnel_number')}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          m.b('closed') ? const Pill('Abgeschlossen', color: AppTheme.ok) : const Pill('Offen', color: AppTheme.warn),
                        ]),
                        const SizedBox(height: 6),
                        Text('Ist ${Fmt.hm(m.i('worked'))} h  ·  Soll ${Fmt.hm(m.i('target'))} h  ·  Saldo ${Fmt.signed(m.i('balance'))} h'),
                        Text('Überstundenkonto Monatsende: ${Fmt.signed(m.i('overtime_end'))} h', style: TextStyle(color: AppTheme.signColor(context, m.i('overtime_end')))),
                        if (m.b('closed') && m.s('closed_at').isNotEmpty)
                          Text('Abgeschlossen ${Fmt.dateTime(m.s('closed_at'))}${m.s('closed_by').isEmpty ? '' : ' von ${m.s('closed_by')}'}', style: const TextStyle(fontSize: 12)),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (!m.b('closed') && m.b('can_close'))
                            FilledButton.tonal(
                              onPressed: () async {
                                if (!await confirmDialog(context, 'Monat $ym für ${m.s('name')} abschließen? Danach sind Änderungen gesperrt.', ok: 'Abschließen')) return;
                                if (!context.mounted) return;
                                final res = await guard(context, () => s.api.post('months/close', {'user_id': m.i('user_id'), 'month': ym}));
                                if (res != null && context.mounted) {
                                  toast(context, 'Monat abgeschlossen.');
                                  setState(() => _version++);
                                }
                              },
                              child: const Text('Abschließen'),
                            ),
                          if (m.b('closed') && s.can('months.close'))
                            TextButton(
                              onPressed: () async {
                                if (!await confirmDialog(context, 'Monat $ym für ${m.s('name')} wieder öffnen?', ok: 'Öffnen')) return;
                                if (!context.mounted) return;
                                final res = await guard(context, () => s.api.post('months/reopen', {'user_id': m.i('user_id'), 'month': ym}));
                                if (res != null && context.mounted) {
                                  toast(context, 'Monat wieder geöffnet.');
                                  setState(() => _version++);
                                }
                              },
                              child: const Text('Wieder öffnen'),
                            ),
                        ]),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
