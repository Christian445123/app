import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Betrieb: Öffnungszeiten je Wochentag, Feiertage (standardmäßig geschlossen, aber änderbar) und eigene Sondertage.
class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});
  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  int _year = DateTime.now().year;
  int _version = 0;

  void _reload() => setState(() => _version++);

  /// Öffnungszeiten: Wochentag → [von, bis] oder null (geschlossen).
  Map<int, List<String>?> _hours(Json b) {
    final raw = b.o('opening_hours') ?? {};
    final out = <int, List<String>?>{};
    for (var d = 1; d <= 7; d++) {
      final v = raw['$d'];
      out[d] = v is List && v.length >= 2 ? ['${v[0]}', '${v[1]}'] : null;
    }
    return out;
  }

  /// Speichert alle Öffnungszeiten. Rückgabe: Fehlermeldung oder null.
  Future<String?> _saveHours(Map<int, List<String>?> h) async {
    final s = context.read<Session>();
    final open = <String, bool>{};
    final from = <String, String>{};
    final to = <String, String>{};
    h.forEach((d, v) {
      if (v != null) {
        open['$d'] = true;
        from['$d'] = v[0];
        to['$d'] = v[1];
      }
    });
    try {
      await s.api.post('business/hours', {'open': open, 'from': from, 'to': to});
    } on ApiException catch (e) {
      if (e.isAuth) await s.expire();
      return e.message;
    }
    if (mounted) {
      toast(context, 'Öffnungszeiten gespeichert.');
      _reload();
    }
    return null;
  }

  Future<void> _editDay(Map<int, List<String>?> all, int d) async {
    final cur = all[d];
    await showFormSheet(
      context,
      title: 'Öffnungszeit ${Fmt.weekdays[d]}',
      fields: [
        FieldDef('open', 'Geöffnet', FieldType.checkbox, initial: cur != null ? '1' : '0'),
        FieldDef('from', 'Von', FieldType.time, initial: cur?[0] ?? '07:00', required: true),
        FieldDef('to', 'Bis', FieldType.time, initial: cur?[1] ?? '18:30', required: true),
      ],
      onSave: (v) async {
        final next = Map<int, List<String>?>.from(all);
        next[d] = v['open'] == '1' ? [v['from'] ?? '', v['to'] ?? ''] : null;
        return _saveHours(next);
      },
    );
  }

  Future<void> _special(Json? day, {String? date, String? name}) async {
    final s = context.read<Session>();
    var saved = false;
    await showFormSheet(
      context,
      title: day == null && date == null ? 'Sondertag hinzufügen' : 'Sondertag',
      fields: [
        FieldDef('date', 'Datum', FieldType.date, initial: day?.s('date') ?? date ?? Fmt.iso(DateTime.now()), required: true),
        FieldDef('kind', 'Art', FieldType.dropdown, initial: day?.s('kind') ?? (date != null ? 'open' : 'closed'), options: const [MapEntry('closed', 'Betrieb geschlossen'), MapEntry('open', 'Betrieb geöffnet')]),
        FieldDef('name', 'Bezeichnung', FieldType.text, initial: day?.s('name') ?? name ?? ''),
        FieldDef('open_from', 'Geöffnet von (optional)', FieldType.time, initial: day?.s('open_from') ?? '', hint: 'nur bei „geöffnet“; leer = reguläre Zeiten'),
        FieldDef('open_to', 'Geöffnet bis (optional)', FieldType.time, initial: day?.s('open_to') ?? ''),
      ],
      onSave: (v) async {
        try {
          await s.api.post('business/special_save', {'date': v['date'], 'kind': v['kind'], 'name': v['name'], 'open_from': v['open_from'], 'open_to': v['open_to']});
          saved = true;
          return null;
        } on ApiException catch (e) {
          if (e.isAuth) await s.expire();
          return e.message;
        }
      },
    );
    if (saved && mounted) _reload();
  }

  Future<void> _deleteSpecial(String date) async {
    final s = context.read<Session>();
    final r = await guard(context, () => s.api.post('business/special_delete', {'date': date}));
    if (r != null && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return PageScaffold(
      navKey: 'business',
      title: 'Betrieb',
      fab: FloatingActionButton.extended(onPressed: () => _special(null), icon: const Icon(Icons.add), label: const Text('Sondertag')),
      body: Loader<Json>(
        key: ValueKey('$_year-$_version'),
        load: () => s.api.get('business', {'year': '$_year'}),
        builder: (context, r, reload) {
          final b = r.o('business') ?? {};
          final hours = _hours(b);
          final holidays = b.l('holidays');
          final specials = b.l('special_days');
          return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
            const SectionTitle('Öffnungszeiten'),
            Card(
              child: Column(children: [
                for (var d = 1; d <= 7; d++)
                  ListTile(
                    dense: true,
                    title: Text(Fmt.weekdays[d]),
                    trailing: Text(hours[d] == null ? 'geschlossen' : '${hours[d]![0]} – ${hours[d]![1]}',
                        style: TextStyle(fontWeight: FontWeight.w600, color: hours[d] == null ? AppTheme.danger : null)),
                    onTap: () => _editDay(hours, d),
                  ),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Mitarbeiter können Zeiten immer von Hand eintragen – auch an geschlossenen Tagen.', style: TextStyle(fontSize: 12)),
            ),
            SectionTitle('Feiertage', trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () => setState(() => _year--), icon: const Icon(Icons.chevron_left)),
              Text('$_year', style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(onPressed: () => setState(() => _year++), icon: const Icon(Icons.chevron_right)),
            ])),
            Card(
              child: Column(children: [
                for (final h in holidays)
                  ListTile(
                    dense: true,
                    title: Text(h.s('name')),
                    subtitle: Text('${h.s('weekday')} ${Fmt.date(h.s('date'))}'),
                    trailing: Pill(h.b('open') ? 'geöffnet' : 'geschlossen', color: h.b('open') ? AppTheme.ok : AppTheme.warn),
                    onTap: () async {
                      if (h.b('open')) {
                        await _deleteSpecial(h.s('date'));
                      } else {
                        await _special(null, date: h.s('date'), name: h.s('name'));
                      }
                    },
                  ),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Antippen: geschlossenen Feiertag öffnen bzw. wieder auf „geschlossen“ stellen.', style: TextStyle(fontSize: 12)),
            ),
            const SectionTitle('Eigene Sondertage'),
            if (specials.isEmpty)
              const Card(child: EmptyHint('Keine Sondertage.'))
            else
              Card(
                child: Column(children: [
                  for (final sp in specials)
                    ListTile(
                      dense: true,
                      title: Text(sp.s('name').isEmpty ? (sp.s('kind') == 'closed' ? 'Geschlossen' : 'Geöffnet') : sp.s('name')),
                      subtitle: Text('${sp.s('weekday')} ${Fmt.date(sp.s('date'))}${sp.s('open_from').isEmpty ? '' : ' · ${sp.s('open_from')}–${sp.s('open_to')}'}'),
                      leading: Icon(sp.s('kind') == 'closed' ? Icons.lock_outline : Icons.lock_open, color: sp.s('kind') == 'closed' ? AppTheme.warn : AppTheme.ok),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteSpecial(sp.s('date'))),
                      onTap: () => _special(sp),
                    ),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}
