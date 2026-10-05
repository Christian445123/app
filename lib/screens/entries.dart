import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/widgets.dart';
import 'entry_form.dart';

/// Zeiten: eigene (bzw. mit Recht alle) Einträge im Zeitraum; eintragen, ändern, löschen.
class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key});
  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  String _user = ''; // '' = ich, '0' = alle, sonst Benutzer-ID
  List<MapEntry<String, String>> _users = [];
  int _version = 0;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    if (s.can('hours.view_all')) {
      loadUsers(s.api).then((u) {
        if (mounted) setState(() => _users = u);
      }).catchError((_) {});
    }
  }

  Future<void> _pick(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => from ? _from = d : _to = d);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final canAdd = s.canAny(['hours.own', 'hours.edit_all']);
    final viewAll = s.can('hours.view_all');
    return PageScaffold(
      navKey: 'entries',
      title: 'Zeiten',
      fab: canAdd
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await showEntryForm(context);
                if (!ok || !context.mounted) return;
                toast(context, 'Eingetragen.');
                setState(() => _version++);
              },
              icon: const Icon(Icons.add),
              label: const Text('Eintragen'),
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ActionChip(avatar: const Icon(Icons.calendar_today, size: 16), label: Text('Von ${Fmt.date(Fmt.iso(_from))}'), onPressed: () => _pick(true)),
            ActionChip(avatar: const Icon(Icons.calendar_today, size: 16), label: Text('Bis ${Fmt.date(Fmt.iso(_to))}'), onPressed: () => _pick(false)),
            if (viewAll)
              DropdownButton<String>(
                value: _user,
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Meine Zeiten')),
                  const DropdownMenuItem(value: '0', child: Text('Alle Mitarbeiter')),
                  for (final u in _users) DropdownMenuItem(value: u.key, child: Text(u.value)),
                ],
                onChanged: (v) => setState(() => _user = v ?? ''),
              ),
          ]),
        ),
        Expanded(
          child: Loader<Json>(
            key: ValueKey('$_version-${Fmt.iso(_from)}-${Fmt.iso(_to)}-$_user'),
            load: () => s.api.get('entries', {
              'from': Fmt.iso(_from),
              'to': Fmt.iso(_to),
              if (viewAll && _user.isNotEmpty) 'user_id': _user,
            }),
            builder: (context, r, reload) {
              final rows = r.l('entries');
              final total = rows.fold<int>(0, (a, e) => a + e.i('worked_seconds'));
              final showName = viewAll && _user == '0';
              return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
                if (rows.isEmpty)
                  const EmptyHint('Keine Einträge im Zeitraum.')
                else
                  Card(
                    child: Column(children: [
                      for (final e in rows)
                        Dismissible(
                          key: ValueKey('e${e.i('id')}'),
                          direction: e.b('editable') ? DismissDirection.endToStart : DismissDirection.none,
                          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                          confirmDismiss: (_) => confirmDialog(context, 'Eintrag wirklich löschen?', ok: 'Löschen', danger: true),
                          onDismissed: (_) async {
                            final ok = await guard(context, () => s.api.post('entries/delete', {'id': e.i('id')}));
                            if (ok != null) await reload();
                          },
                          child: ListTile(
                            title: Text('${Fmt.day(e.s('date'))}  ${e.s('start')}–${e.has('end') ? e.s('end') : 'offen'}'),
                            subtitle: Text([
                              if (showName) e.s('user_name'),
                              if (e.i('break_min') > 0) 'Pause ${e.i('break_min')} Min.',
                              if (e.s('note').isNotEmpty) e.s('note'),
                            ].join(' · ')),
                            trailing: Text('${Fmt.hm(e.i('worked_seconds'))} h', style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: e.b('editable')
                                ? () async {
                                    if (await showEntryForm(context, entry: e)) await reload();
                                  }
                                : null,
                          ),
                        ),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Summe: ${Fmt.hm(total)} h (${rows.length} Einträge)', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (rows.any((e) => e.b('editable'))) const Text('Tipp: Eintrag antippen = bearbeiten, nach links wischen = löschen.', style: TextStyle(fontSize: 12)),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
