import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/widgets.dart';

/// Mitarbeiter für Auswahllisten (nur mit passendem Recht erlaubt; Verwaltungskonten ohne Zeiterfassung fehlen).
Future<List<MapEntry<String, String>>> loadUsers(ApiBase api) async {
  final r = await api.get('users/lookup');
  return r.l('users').map((u) => MapEntry(u.s('id'), '${u.s('name')} (${u.s('personnel_number')})')).toList();
}

const absenceKinds = [
  MapEntry('work', 'Arbeitszeit'),
  MapEntry('doctor', 'Arzt'),
  MapEntry('sick', 'Krankenstand'),
  MapEntry('vacation', 'Urlaub'),
  MapEntry('comp', 'Zeitausgleich'),
  MapEntry('other', 'Sonstiges'),
];

/// Stunden eintragen oder ändern. Bei neuen Einträgen auch Arzt/Krank/Urlaub/… (ohne Von/Bis = ganzer Tag).
/// Rückgabe: true = gespeichert.
Future<bool> showEntryForm(BuildContext context, {Json? entry}) async {
  final s = context.read<Session>();
  var users = <MapEntry<String, String>>[];
  if (entry == null && s.can('hours.edit_all')) {
    users = await guard(context, () => loadUsers(s.api)) ?? [];
  }
  if (!context.mounted) return false;
  final withKinds = entry == null && s.canAny(['absences.request', 'absences.manage']);
  final isNew = entry == null;
  var saved = false;

  await showFormSheet(
    context,
    title: isNew ? 'Stunden eintragen' : 'Eintrag bearbeiten',
    okLabel: isNew ? 'Eintragen' : 'Speichern',
    fields: [
      if (isNew && users.isNotEmpty) FieldDef('user_id', 'Mitarbeiter', FieldType.dropdown, initial: '${s.userId}', options: users),
      if (!isNew) FieldDef('info', 'Mitarbeiter: ${entry.s('user_name')}', FieldType.info),
      if (withKinds) const FieldDef('kind', 'Art', FieldType.dropdown, initial: 'work', options: absenceKinds),
      FieldDef('date', 'Datum', FieldType.date, initial: entry?.s('date') ?? Fmt.iso(DateTime.now()), required: true),
      FieldDef('start', 'Von', FieldType.time, initial: entry?.s('start') ?? '08:00'),
      FieldDef('end', 'Bis', FieldType.time, initial: entry?.s('end') ?? '16:30'),
      FieldDef('break_min', 'Pause (Minuten)', FieldType.number, initial: isNew ? '30' : '${entry.i('break_min')}',
          hint: 'Ende vor Beginn = Nachtschicht. Arzt/Krank & Co.: Von/Bis leeren = ganzer Tag.'),
      FieldDef('note', 'Notiz', FieldType.multiline, initial: entry?.s('note') ?? ''),
    ],
    onSave: (v) async {
      try {
        if (isNew) {
          await s.api.post('entries/manual', {
            'kind': v['kind'] ?? 'work',
            'user_id': int.tryParse(v['user_id'] ?? '') ?? 0,
            'date': v['date'],
            'start': v['start'],
            'end': v['end'],
            'break_min': int.tryParse(v['break_min'] ?? '') ?? 0,
            'note': v['note'],
          });
        } else {
          await s.api.post('entries/save', {
            'id': entry.i('id'),
            'date': v['date'],
            'start': v['start'],
            'end': v['end'],
            'break_min': int.tryParse(v['break_min'] ?? '') ?? 0,
            'note': v['note'],
          });
        }
        saved = true;
        return null;
      } on ApiException catch (e) {
        if (e.isAuth) await s.expire();
        return e.message;
      }
    },
  );
  return saved;
}
