import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _statusText = {
  'ok': 'pünktlich',
  'late': 'verspätet',
  'short': 'zu kurz',
  'missing': 'nicht erschienen',
  'pending': 'noch offen',
  'excused': 'entschuldigt',
  'unplanned': 'ungeplant',
  'future': 'geplant',
};

Color _statusColor(String s) => switch (s) {
      'ok' => AppTheme.ok,
      'late' || 'short' || 'pending' => AppTheme.warn,
      'missing' => AppTheme.danger,
      'unplanned' => const Color(0xFF9333EA),
      _ => const Color(0xFF64748B),
    };

DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

int _toMin(String hm) {
  final p = hm.split(':');
  if (p.length < 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

/// Dienstplan: Woche (Soll je Mitarbeiter, Einteilen) und Tag (Zeitleiste Soll gegen Ist).
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _week = _monday(DateTime.now());
  String _day = Fmt.iso(DateTime.now());
  bool _dayView = false;
  int _version = 0;

  void _reload() => setState(() => _version++);

  Future<void> _shiftForm(Json data, {Json? shift, String? userId, String? date}) async {
    final s = context.read<Session>();
    final sched = data.o('schedule') ?? {};
    final users = sched.l('users').map((u) => MapEntry(u.s('id'), u.s('name'))).toList();
    if (users.isEmpty) {
      toast(context, 'Keine Mitarbeiter vorhanden.', error: true);
      return;
    }
    final day = date ?? shift?.s('shift_date') ?? _day;
    final biz = (data.o('business') ?? {}).o(day);
    final defFrom = (biz != null && biz.b('open') && biz.s('from').isNotEmpty) ? biz.s('from') : '08:00';
    final defTo = (biz != null && biz.b('open') && biz.s('to').isNotEmpty) ? biz.s('to') : '16:00';
    var saved = false;
    await showFormSheet(
      context,
      title: shift == null ? 'Schicht einteilen' : 'Schicht bearbeiten',
      fields: [
        FieldDef('user_id', 'Mitarbeiter', FieldType.dropdown, initial: userId ?? users.first.key, options: users),
        FieldDef('shift_date', 'Datum', FieldType.date, initial: day, required: true),
        FieldDef('start_time', 'Beginn', FieldType.time, initial: shift?.s('start') ?? defFrom, required: true),
        FieldDef('end_time', 'Ende', FieldType.time, initial: shift?.s('end') ?? defTo, required: true, hint: 'Ende vor Beginn = über Mitternacht'),
        FieldDef('break_min', 'Pause (Minuten)', FieldType.number, initial: '${shift?.i('break_min') ?? 0}'),
        FieldDef('note', 'Notiz', FieldType.text, initial: shift?.s('note') ?? ''),
      ],
      extraAction: shift == null
          ? null
          : Builder(
              builder: (c) => TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                label: const Text('Löschen', style: TextStyle(color: AppTheme.danger)),
                onPressed: () async {
                  if (!await confirmDialog(c, 'Schicht löschen?', ok: 'Löschen', danger: true)) return;
                  if (!c.mounted) return;
                  final r = await guard(c, () => s.api.post('shifts/delete', {'id': shift.i('id')}));
                  if (r != null && c.mounted) {
                    saved = true;
                    Navigator.pop(c);
                  }
                },
              ),
            ),
      onSave: (v) async {
        try {
          final r = await s.api.post('shifts/save', {
            'id': shift?.i('id') ?? 0,
            'user_id': int.tryParse(v['user_id'] ?? '') ?? 0,
            'shift_date': v['shift_date'],
            'start_time': v['start_time'],
            'end_time': v['end_time'],
            'break_min': int.tryParse(v['break_min'] ?? '') ?? 0,
            'note': v['note'],
          });
          saved = true;
          if (r.s('warning').isNotEmpty && mounted) toast(context, r.s('warning'));
          return null;
        } on ApiException catch (e) {
          if (e.isAuth) await s.expire();
          return e.message;
        }
      },
    );
    if (saved && mounted) _reload();
  }

  Future<void> _copyWeek() async {
    final s = context.read<Session>();
    if (!await confirmDialog(context, 'Alle Schichten der Vorwoche in diese (leere) Woche kopieren?', ok: 'Kopieren')) return;
    if (!mounted) return;
    final r = await guard(context, () => s.api.post('shifts/copy_week', {'week': Fmt.iso(_week)}));
    if (r != null && mounted) {
      toast(context, '${r.i('copied')} Schichten kopiert.');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final weekIso = Fmt.iso(_week);
    return PageScaffold(
      navKey: 'schedule',
      title: 'Dienstplan',
      actions: [
        if (s.can('schedule.edit'))
          PopupMenuButton<String>(
            onSelected: (v) => v == 'copy' ? _copyWeek() : null,
            itemBuilder: (_) => const [PopupMenuItem(value: 'copy', child: Text('Vorwoche kopieren'))],
          ),
      ],
      body: Loader<Json>(
        key: ValueKey('$weekIso-$_version'),
        load: () => s.api.get('schedule', {'week': weekIso}),
        builder: (context, data, reload) {
          final sched = data.o('schedule') ?? {};
          final canEdit = data.b('can_edit');
          final days = sched.strs('days');
          if (!days.contains(_day)) _day = days.isEmpty ? _day : days.first;
          return Stack(children: [
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(children: [
                  IconButton(onPressed: () => setState(() => _week = _week.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _week = _monday(DateTime.now())),
                      child: Text('KW ${sched.i('kw')} · ${Fmt.date(sched.s('week_start')).substring(0, 6)} – ${Fmt.date(sched.s('week_end'))}',
                          textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  IconButton(onPressed: () => setState(() => _week = _week.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
                ]),
              ),
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('Woche'), icon: Icon(Icons.view_week)), ButtonSegment(value: true, label: Text('Tag'), icon: Icon(Icons.view_timeline))],
                selected: {_dayView},
                onSelectionChanged: (v) => setState(() => _dayView = v.first),
              ),
              Expanded(
                child: _dayView
                    ? _DayView(
                        data: data,
                        day: _day,
                        onDay: (d) => setState(() => _day = d),
                        onShift: canEdit ? (sh, uid, date) => _shiftForm(data, shift: sh, userId: uid, date: date) : null,
                      )
                    : _WeekView(data: data, onShift: canEdit ? (sh, uid, date) => _shiftForm(data, shift: sh, userId: uid, date: date) : null),
              ),
            ]),
            if (canEdit)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: () => _shiftForm(data),
                  icon: const Icon(Icons.add),
                  label: const Text('Einteilen'),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

typedef ShiftTap = void Function(Json? shift, String? userId, String? date);

class _WeekView extends StatelessWidget {
  const _WeekView({required this.data, required this.onShift});
  final Json data;
  final ShiftTap? onShift;

  @override
  Widget build(BuildContext context) {
    final sched = data.o('schedule') ?? {};
    final users = sched.l('users');
    final biz = data.o('business') ?? {};
    final today = Fmt.iso(DateTime.now());
    final t = Theme.of(context);

    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
      for (final d in sched.strs('days'))
        Builder(builder: (context) {
          final b = biz.o(d) ?? {};
          final closed = !b.b('open');
          final planned = (sched.o('day_planned') ?? {}).i(d);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: d == today ? t.colorScheme.primaryContainer.withValues(alpha: .35) : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(Fmt.day(d), style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  if (closed) Pill(b.s('reason').isEmpty ? 'geschlossen' : b.s('reason'), color: AppTheme.warn) else Text('${b.s('from')}–${b.s('to')}', style: t.textTheme.bodySmall),
                  const Spacer(),
                  Text('$planned eingeteilt · ${Fmt.minutes((sched.o('day_plan_min') ?? {}).i(d))} h', style: t.textTheme.bodySmall),
                ]),
                const SizedBox(height: 6),
                for (final u in users)
                  Builder(builder: (context) {
                    final c = (u.o('cells') ?? {}).o(d) ?? {};
                    final shifts = c.l('shifts');
                    final abs = c.o('absence');
                    final status = c.s('status');
                    if (shifts.isEmpty && abs == null && status != 'unplanned') return const SizedBox.shrink();
                    final act = c.o('actual') ?? {};
                    return InkWell(
                      onTap: onShift == null ? null : () => onShift!(shifts.isEmpty ? null : shifts.first, '${u.i('id')}', d),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            flex: 3,
                            child: Text(u.s('name'), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 4,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              for (final sh in shifts)
                                GestureDetector(
                                  onTap: onShift == null ? null : () => onShift!(sh..['shift_date'] = d, '${u.i('id')}', d),
                                  child: Text('${sh.s('start')}–${sh.s('end')}${sh.s('note').isEmpty ? '' : ' · ${sh.s('note')}'}'),
                                ),
                              if (abs != null) Text(Fmt.absence(abs.s('type')), style: TextStyle(color: t.colorScheme.primary, fontSize: 12)),
                              if (u.b('show_actual') && act.has('first'))
                                Text('Ist ${act.s('first')}–${act.s('last')} (${Fmt.minutes(act.i('worked_min'))} h)', style: t.textTheme.bodySmall),
                            ]),
                          ),
                          if (status.isNotEmpty && _statusText.containsKey(status)) Pill(_statusText[status]!, color: _statusColor(status)),
                        ]),
                      ),
                    );
                  }),
                if (planned == 0 && !users.any((u) => ((u.o('cells') ?? {}).o(d) ?? {}).o('absence') != null))
                  Text(closed ? 'Betrieb geschlossen' : 'Niemand eingeteilt', style: t.textTheme.bodySmall),
              ]),
            ),
          );
        }),
      Text('Wochenstunden Soll/Plan/Ist je Mitarbeiter:', style: t.textTheme.labelLarge),
      const SizedBox(height: 4),
      Card(
        child: Column(children: [
          for (final u in users)
            ListTile(
              dense: true,
              title: Text(u.s('name')),
              subtitle: Text('Plan ${Fmt.minutes(u.i('plan_min'))} h${u.b('show_actual') ? ' · Soll ${Fmt.minutes(u.i('soll_min'))} h · Ist ${Fmt.minutes(u.i('ist_min'))} h' : ''}'),
            ),
        ]),
      ),
    ]);
  }
}

class _DayView extends StatelessWidget {
  const _DayView({required this.data, required this.day, required this.onDay, required this.onShift});
  final Json data;
  final String day;
  final ValueChanged<String> onDay;
  final ShiftTap? onShift;

  @override
  Widget build(BuildContext context) {
    final sched = data.o('schedule') ?? {};
    final users = sched.l('users');
    final b = (data.o('business') ?? {}).o(day) ?? {};
    final t = Theme.of(context);
    final days = sched.strs('days');

    // Zeitachse: Öffnungszeit ± 1 h, erweitert um tatsächlich vorkommende Zeiten
    var from = b.b('open') && b.s('from').isNotEmpty ? _toMin(b.s('from')) : 7 * 60;
    var to = b.b('open') && b.s('to').isNotEmpty ? _toMin(b.s('to')) : 18 * 60;
    for (final u in users) {
      final c = (u.o('cells') ?? {}).o(day) ?? {};
      for (final sh in c.l('shifts')) {
        from = from < _toMin(sh.s('start')) ? from : _toMin(sh.s('start'));
        final e = _toMin(sh.s('end'));
        if (e > _toMin(sh.s('start')) && e > to) to = e;
      }
      for (final e in (c.o('actual') ?? {}).l('entries')) {
        from = from < _toMin(e.s('start')) ? from : _toMin(e.s('start'));
        if (e.has('end') && _toMin(e.s('end')) > to) to = _toMin(e.s('end'));
      }
    }
    from = (from ~/ 60) * 60;
    to = ((to + 59) ~/ 60) * 60;
    if (to <= from) to = from + 60;
    final span = (to - from).toDouble();

    Widget bar(double w, int s, int e, Color c, String label, {VoidCallback? onTap}) {
      final left = (s - from) / span * w;
      final width = ((e - s) / span * w).clamp(4.0, w);
      return Positioned(
        left: left.clamp(0.0, w),
        width: width,
        top: 0,
        bottom: 0,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(label, maxLines: 1, overflow: TextOverflow.clip, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ),
      );
    }

    return Column(children: [
      SizedBox(
        height: 56,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
          for (final d in days)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
              child: ChoiceChip(label: Text(Fmt.day(d)), selected: d == day, onSelected: (_) => onDay(d)),
            ),
        ]),
      ),
      if (!b.b('open'))
        Padding(padding: const EdgeInsets.all(8), child: Pill('Betrieb geschlossen${b.s('reason').isEmpty ? '' : ' (${b.s('reason')})'}', color: AppTheme.warn)),
      Expanded(
        child: LayoutBuilder(builder: (context, cons) {
          const nameW = 92.0;
          final w = cons.maxWidth - nameW - 24;
          return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: [
            Row(children: [
              const SizedBox(width: nameW),
              SizedBox(
                width: w,
                height: 18,
                child: Stack(children: [
                  for (var h = from; h <= to; h += 60)
                    Positioned(left: (h - from) / span * w - 8, child: Text('${h ~/ 60}', style: const TextStyle(fontSize: 10))),
                ]),
              ),
            ]),
            for (final u in users)
              Builder(builder: (context) {
                final c = (u.o('cells') ?? {}).o(day) ?? {};
                final shifts = c.l('shifts');
                final act = c.o('actual') ?? {};
                final entries = act.l('entries');
                final abs = c.o('absence');
                final status = c.s('status');
                return Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(u.s('name'), style: const TextStyle(fontWeight: FontWeight.w700))),
                        if (abs != null) Pill(Fmt.absence(abs.s('type')), color: t.colorScheme.primary),
                        if (status.isNotEmpty && _statusText.containsKey(status)) ...[const SizedBox(width: 6), Pill(_statusText[status]!, color: _statusColor(status))],
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const SizedBox(width: nameW - 8, child: Text('Soll (Plan)', style: TextStyle(fontSize: 11))),
                        SizedBox(
                          width: w,
                          height: 22,
                          child: Stack(children: [
                            Container(color: t.colorScheme.surfaceContainerHighest.withValues(alpha: .5)),
                            for (final sh in shifts)
                              bar(w, _toMin(sh.s('start')), _toMin(sh.s('end')) <= _toMin(sh.s('start')) ? to : _toMin(sh.s('end')), t.colorScheme.primary,
                                  '${sh.s('start')}–${sh.s('end')}', onTap: onShift == null ? null : () => onShift!(sh..['shift_date'] = day, '${u.i('id')}', day)),
                          ]),
                        ),
                      ]),
                      if (u.b('show_actual')) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const SizedBox(width: nameW - 8, child: Text('Ist (Zeiten)', style: TextStyle(fontSize: 11))),
                          SizedBox(
                            width: w,
                            height: 22,
                            child: Stack(children: [
                              Container(color: t.colorScheme.surfaceContainerHighest.withValues(alpha: .5)),
                              for (final e in entries)
                                bar(w, _toMin(e.s('start')), e.has('end') ? (_toMin(e.s('end')) <= _toMin(e.s('start')) ? to : _toMin(e.s('end'))) : _toMin(e.s('start')) + 30,
                                    AppTheme.ok, '${e.s('start')}–${e.has('end') ? e.s('end') : 'läuft'}'),
                            ]),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Plan ${Fmt.minutes(c.i('plan_min'))} h${u.b('show_actual') ? ' · Soll ${Fmt.minutes(c.i('target_min'))} h · Ist ${Fmt.minutes(act.i('worked_min'))} h${c.i('late_min') > 0 ? ' · ${c.i('late_min')} Min. verspätet' : ''}' : ''}',
                        style: t.textTheme.bodySmall,
                      ),
                    ]),
                  ),
                );
              }),
          ]);
        }),
      ),
    ]);
  }
}
