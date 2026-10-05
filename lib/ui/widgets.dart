import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import 'theme.dart';

/// Kleine Hinweismeldung unten.
void toast(BuildContext context, String message, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppTheme.danger : null,
    behavior: SnackBarBehavior.floating,
  ));
}

/// Führt eine API-Aktion aus und zeigt Fehler verständlich an. Bei abgelaufener Sitzung → Anmeldung.
/// Rückgabe: Ergebnis oder null bei Fehler.
Future<T?> guard<T>(BuildContext context, Future<T> Function() action) async {
  final session = context.read<Session>();
  try {
    return await action();
  } on ApiException catch (e) {
    if (e.isAuth) {
      await session.expire();
      return null;
    }
    if (context.mounted) toast(context, e.message, error: true);
    return null;
  }
}

Future<bool> confirmDialog(BuildContext context, String text, {String ok = 'Ja', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppTheme.danger) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Lädt Daten, zeigt Ladekreis/Fehler (mit „Erneut versuchen“) und unterstützt Herunterziehen zum Aktualisieren.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<Loader<T>> createState() => LoaderState<T>();
}

class LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = _run();
  }

  Future<T> _run() async {
    try {
      return await widget.load();
    } on ApiException catch (e) {
      if (e.isAuth && mounted) await context.read<Session>().expire();
      rethrow;
    }
  }

  Future<void> reload() async {
    final f = _run();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {
      // Fehler zeigt der FutureBuilder
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final msg = snap.error is ApiException ? (snap.error as ApiException).message : 'Fehler: ${snap.error}';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, size: 40),
                const SizedBox(height: 12),
                Text(msg, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: reload, child: const Text('Erneut versuchen')),
              ]),
            ),
          );
        }
        return RefreshIndicator(onRefresh: reload, child: widget.builder(context, snap.data as T, reload));
      },
    );
  }
}

/// Kennzahl-Kachel (kleine Beschriftung, große Zahl, Zusatzzeile).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.sub, this.color, this.width = 165});
  final String label;
  final String value;
  final String? sub;
  final Color? color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant, letterSpacing: .4)),
            const SizedBox(height: 4),
            Text(value, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
            if (sub != null) Text(sub!, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      );
}

/// Kleines farbiges Etikett (Status, Art).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: .15), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Monatsauswahl mit Vor-/Zurück-Pfeilen.
class MonthBar extends StatelessWidget {
  const MonthBar({super.key, required this.month, required this.onChanged});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(onPressed: () => onChanged(DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
        Text(Fmt.monthLabel(month), style: Theme.of(context).textTheme.titleMedium),
        IconButton(onPressed: () => onChanged(DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
      ]);
}

// ---------------------------------------------------------------------------------------------------------------------
// Formular als Bottom-Sheet

enum FieldType { text, multiline, number, password, date, optDate, time, dropdown, checkbox, dayHours, multiCheck, info }

class FieldDef {
  const FieldDef(this.key, this.label, this.type, {this.initial = '', this.options = const [], this.hint, this.required = false, this.maxDate});
  final String key;
  final String label;
  final FieldType type;
  final String initial;
  final List<MapEntry<String, String>> options; // Wert → Text
  final String? hint;
  final bool required;
  final DateTime? maxDate;
}

/// Zeigt ein Formular. [onSave] bekommt die Werte und liefert eine Fehlermeldung (Formular bleibt offen) oder null (Erfolg).
/// Rückgabe: Werte bei Erfolg, sonst null.
Future<Map<String, String>?> showFormSheet(
  BuildContext context, {
  required String title,
  required List<FieldDef> fields,
  String okLabel = 'Speichern',
  Future<String?> Function(Map<String, String> values)? onSave,
  Widget? extraAction,
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => _FormSheet(title: title, fields: fields, okLabel: okLabel, onSave: onSave, extraAction: extraAction),
  );
}

class _FormSheet extends StatefulWidget {
  const _FormSheet({required this.title, required this.fields, required this.okLabel, this.onSave, this.extraAction});
  final String title;
  final List<FieldDef> fields;
  final String okLabel;
  final Future<String?> Function(Map<String, String>)? onSave;
  final Widget? extraAction;

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final Map<String, TextEditingController> _ctl = {};
  final Map<String, String> _val = {};
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      _val[f.key] = f.initial;
      if (const [FieldType.text, FieldType.multiline, FieldType.number, FieldType.password].contains(f.type)) {
        _ctl[f.key] = TextEditingController(text: f.initial);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _collect() {
    final out = Map<String, String>.from(_val);
    _ctl.forEach((k, c) => out[k] = c.text.trim());
    for (final f in widget.fields) {
      if (f.type == FieldType.password) out[f.key] = _ctl[f.key]!.text; // Passwörter nicht trimmen
    }
    return out;
  }

  Future<void> _submit() async {
    final v = _collect();
    for (final f in widget.fields) {
      if (f.required && (v[f.key] ?? '').isEmpty && f.type != FieldType.info) {
        setState(() => _error = 'Bitte „${f.label}“ ausfüllen.');
        return;
      }
    }
    if (widget.onSave != null) {
      setState(() {
        _busy = true;
        _error = null;
      });
      final err = await widget.onSave!(v);
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _busy = false;
          _error = err;
        });
        return;
      }
    }
    if (mounted) Navigator.pop(context, v);
  }

  Future<void> _pickDate(FieldDef f) async {
    final cur = DateTime.tryParse(_val[f.key] ?? '') ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: f.maxDate != null && cur.isAfter(f.maxDate!) ? f.maxDate! : cur,
      firstDate: DateTime(2000),
      lastDate: f.maxDate ?? DateTime(2100),
    );
    if (d != null) setState(() => _val[f.key] = Fmt.iso(d));
  }

  Future<void> _pickTime(FieldDef f) async {
    final parts = (_val[f.key] ?? '').split(':');
    final init = parts.length == 2 ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0) : const TimeOfDay(hour: 8, minute: 0);
    final t = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t != null) setState(() => _val[f.key] = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  Widget _field(FieldDef f) {
    switch (f.type) {
      case FieldType.info:
        return Text(f.label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
      case FieldType.text:
      case FieldType.multiline:
      case FieldType.number:
      case FieldType.password:
        return TextField(
          controller: _ctl[f.key],
          obscureText: f.type == FieldType.password,
          maxLines: f.type == FieldType.multiline ? 3 : 1,
          keyboardType: f.type == FieldType.number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
          decoration: InputDecoration(labelText: f.label + (f.required ? ' *' : ''), helperText: f.hint),
        );
      case FieldType.date:
      case FieldType.optDate:
        final v = _val[f.key] ?? '';
        return InkWell(
          onTap: () => _pickDate(f),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: f.label,
              helperText: f.hint,
              suffixIcon: f.type == FieldType.optDate && v.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _val[f.key] = ''))
                  : const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(v.isEmpty ? '–' : Fmt.date(v)),
          ),
        );
      case FieldType.time:
        final v = _val[f.key] ?? '';
        return InkWell(
          onTap: () => _pickTime(f),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: f.label,
              helperText: f.hint,
              suffixIcon: v.isNotEmpty && !f.required
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _val[f.key] = ''))
                  : const Icon(Icons.schedule, size: 18),
            ),
            child: Text(v.isEmpty ? '–' : v),
          ),
        );
      case FieldType.dropdown:
        final cur = f.options.any((o) => o.key == _val[f.key]) ? _val[f.key] : (f.options.isEmpty ? null : f.options.first.key);
        if (cur != null && _val[f.key] != cur) _val[f.key] = cur;
        return DropdownButtonFormField<String>(
          initialValue: cur,
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label, helperText: f.hint),
          items: [for (final o in f.options) DropdownMenuItem(value: o.key, child: Text(o.value, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => _val[f.key] = v ?? ''),
        );
      case FieldType.checkbox:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          subtitle: f.hint == null ? null : Text(f.hint!),
          value: _val[f.key] == '1',
          onChanged: (v) => setState(() => _val[f.key] = v ? '1' : '0'),
        );
      case FieldType.dayHours:
        return _DayHoursField(label: f.label, hint: f.hint, value: _val[f.key] ?? '', onChanged: (v) => _val[f.key] = v);
      case FieldType.multiCheck:
        final sel = (_val[f.key] ?? '').split(',').where((e) => e.isNotEmpty).toSet();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.label, style: Theme.of(context).textTheme.labelLarge),
          for (final o in f.options)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(o.value),
              value: sel.contains(o.key),
              onChanged: (v) {
                setState(() {
                  v == true ? sel.add(o.key) : sel.remove(o.key);
                  _val[f.key] = sel.join(',');
                });
              },
            ),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(f)),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: AppTheme.danger))),
          Row(children: [
            if (widget.extraAction != null) widget.extraAction!,
            const Spacer(),
            TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Abbrechen')),
            const SizedBox(width: 8),
            FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.okLabel)),
          ]),
        ]),
      ),
    );
  }
}

/// Sieben kleine Eingaben (Mo–So) für die Soll-Stunden je Wochentag; Wert/Rückgabe "1:8,2:6".
class _DayHoursField extends StatefulWidget {
  const _DayHoursField({required this.label, required this.value, required this.onChanged, this.hint});
  final String label;
  final String value;
  final String? hint;
  final ValueChanged<String> onChanged;
  @override
  State<_DayHoursField> createState() => _DayHoursFieldState();
}

class _DayHoursFieldState extends State<_DayHoursField> {
  final List<TextEditingController> _c = List.generate(8, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    for (final p in widget.value.split(',')) {
      final kv = p.split(':');
      if (kv.length == 2) {
        final d = int.tryParse(kv[0]) ?? 0;
        if (d >= 1 && d <= 7) _c[d].text = kv[1];
      }
    }
    widget.onChanged(_encode());
  }

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  String _encode() {
    final out = <String>[];
    for (var d = 1; d <= 7; d++) {
      final v = double.tryParse(_c[d].text.replaceAll(',', '.'));
      if (v != null && v > 0) out.add('$d:$v');
    }
    return out.join(',');
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Row(children: [
        for (var d = 1; d <= 7; d++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextField(
                controller: _c[d],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(labelText: Fmt.weekdays[d], contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10)),
                onChanged: (_) => widget.onChanged(_encode()),
              ),
            ),
          ),
      ]),
      if (widget.hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.hint!, style: Theme.of(context).textTheme.bodySmall)),
    ]);
  }
}
