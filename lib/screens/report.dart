import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'entry_form.dart';

/// Monatsauswertung: Ist, Soll, Plus-/Minusstunden, Urlaub und jeder Tag einzeln.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _user = '';
  List<MapEntry<String, String>> _users = [];

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    if (s.can('reports.view_all')) {
      loadUsers(s.api).then((u) {
        if (mounted) setState(() => _users = u);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return PageScaffold(
      navKey: 'report',
      title: 'Auswertung',
      body: Column(children: [
        MonthBar(month: _month, onChanged: (m) => setState(() => _month = m)),
        if (s.can('reports.view_all'))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: _user,
              isExpanded: true,
              items: [
                DropdownMenuItem(value: '', child: Text(s.tracksTime ? 'Meine Auswertung' : 'Mitarbeiter wählen …')),
                for (final u in _users) DropdownMenuItem(value: u.key, child: Text(u.value)),
              ],
              onChanged: (v) => setState(() => _user = v ?? ''),
            ),
          ),
        Expanded(
          child: (_user.isEmpty && !s.tracksTime)
              ? const EmptyHint('Verwaltungskonto: keine eigene Auswertung. Mitarbeiter oben wählen.')
              : Loader<Json>(
                  key: ValueKey('${Fmt.ym(_month)}-$_user'),
                  load: () => s.api.get('report', {'month': Fmt.ym(_month), if (_user.isNotEmpty) 'user_id': _user}),
                  builder: (context, r, reload) => _ReportBody(data: r),
                ),
        ),
      ]),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final rep = data.o('report') ?? {};
    final emp = data.o('employee') ?? {};
    final vac = rep.o('vacation');
    final ot = rep.o('overtime') ?? {};
    final rows = rep.l('rows');
    final balance = rep.i('balance');
    final t = Theme.of(context);

    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text(emp.s('name'), style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (data.b('closed')) const Pill('Monat abgeschlossen', color: AppTheme.ok),
        ]),
      ),
      Wrap(spacing: 10, runSpacing: 10, children: [
        StatTile(label: 'Ist', value: '${Fmt.hm(rep.i('worked'))} h'),
        StatTile(label: 'Soll', value: '${Fmt.hm(rep.i('target'))} h'),
        StatTile(label: 'Monatssaldo', value: '${Fmt.signed(balance)} h', color: AppTheme.signColor(context, balance)),
        StatTile(label: 'Überstundenkonto', value: '${Fmt.signed(ot.i('seconds'))} h', color: AppTheme.signColor(context, ot.i('seconds')), sub: 'seit ${Fmt.date(ot.s('since'))}'),
        if (vac != null)
          StatTile(
            label: 'Resturlaub ${vac.i('year')}',
            value: '${Fmt.days(vac.d('remaining'))} Tage',
            sub: 'genommen ${Fmt.days(vac.d('taken'))} · beantragt ${Fmt.days(vac.d('pending'))}',
          ),
      ]),
      const SectionTitle('Tage'),
      Card(
        child: Column(children: [
          for (final d in rows) _DayTile(d: d),
        ]),
      ),
    ]);
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.d});
  final Json d;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final worked = d.i('worked');
    final target = d.i('target');
    final abs = d.o('absence');
    final holiday = d.s('holiday');
    final off = !d.b('workday') && worked == 0 && abs == null;
    final dim = off || (d.b('closed') && worked == 0);
    final diff = worked - target;
    final sub = <String>[
      if (holiday.isNotEmpty) holiday,
      if (abs != null) Fmt.absence(abs.s('type')) + (abs.has('hours') ? ' (${abs.s('hours')} h)' : '') + (abs.s('status') == 'pending' ? ' – offen' : ''),
      if (d.has('first') && worked > 0) '${d.s('first').substring(11, 16)}–${d.s('last').length >= 16 ? d.s('last').substring(11, 16) : ''}',
    ];
    return ListTile(
      dense: true,
      tileColor: dim ? t.colorScheme.surfaceContainerHighest.withValues(alpha: .35) : null,
      title: Text(Fmt.day(d.s('date')), style: TextStyle(fontWeight: FontWeight.w600, color: dim ? t.colorScheme.onSurfaceVariant : null)),
      subtitle: sub.isEmpty ? null : Text(sub.join(' · ')),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(worked > 0 ? '${Fmt.hm(worked)} h' : '–', style: const TextStyle(fontWeight: FontWeight.w700)),
        if (target > 0 || worked > 0)
          Text('Soll ${Fmt.hm(target)}  ${Fmt.signed(diff)}', style: TextStyle(fontSize: 11, color: AppTheme.signColor(context, diff))),
      ]),
    );
  }
}
