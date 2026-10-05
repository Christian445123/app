import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Rollen & Rechte: Rolle anlegen/bearbeiten/löschen, Rechte per Haken vergeben. „Vollzugriff“ ist fest.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});
  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  int _version = 0;

  Future<void> _edit(Json? role, Json perms) async {
    final s = context.read<Session>();
    final opts = perms.entries.map((e) => MapEntry(e.key, '${e.value}')).toList();
    var saved = false;
    await showFormSheet(
      context,
      title: role == null ? 'Neue Rolle' : 'Rolle bearbeiten',
      fields: [
        FieldDef('name', 'Name', FieldType.text, initial: role?.s('name') ?? '', required: true),
        FieldDef('description', 'Beschreibung', FieldType.text, initial: role?.s('description') ?? ''),
        FieldDef('permissions', 'Rechte', FieldType.multiCheck, initial: role?.strs('permissions').join(',') ?? 'hours.own,schedule.view,absences.request', options: opts),
      ],
      extraAction: (role == null || role.b('system'))
          ? null
          : Builder(
              builder: (c) => TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                label: const Text('Löschen', style: TextStyle(color: AppTheme.danger)),
                onPressed: () async {
                  if (!await confirmDialog(c, 'Rolle „${role.s('name')}“ löschen?', ok: 'Löschen', danger: true)) return;
                  if (!c.mounted) return;
                  final r = await guard(c, () => s.api.post('roles/delete', {'id': role.i('id')}));
                  if (r != null && c.mounted) {
                    saved = true;
                    Navigator.pop(c);
                  }
                },
              ),
            ),
      onSave: (v) async {
        try {
          await s.api.post('roles/save', {
            'id': role?.i('id') ?? 0,
            'name': v['name'],
            'description': v['description'],
            'permissions': (v['permissions'] ?? '').split(',').where((e) => e.isNotEmpty).toList(),
          });
          saved = true;
          return null;
        } on ApiException catch (e) {
          if (e.isAuth) await s.expire();
          return e.message;
        }
      },
    );
    if (saved && mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return PageScaffold(
      navKey: 'roles',
      title: 'Rollen & Rechte',
      body: Loader<Json>(
        key: ValueKey(_version),
        load: () => s.api.get('roles'),
        builder: (context, r, reload) {
          final roles = r.l('roles');
          final perms = r.o('permissions') ?? {};
          final manage = r.b('can_manage');
          return Stack(children: [
            ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
              for (final role in roles)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: manage && !role.b('full') ? () => _edit(role, perms) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(role.s('name'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                          if (role.b('full')) const Pill('Vollzugriff', color: AppTheme.ok),
                          const SizedBox(width: 6),
                          Pill('${role.i('user_count')} Mitarbeiter'),
                        ]),
                        if (role.s('description').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(role.s('description'))),
                        const SizedBox(height: 8),
                        if (role.b('full'))
                          const Text('Alle Rechte (fest, nicht änderbar).', style: TextStyle(fontSize: 12))
                        else
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            for (final p in role.strs('permissions')) Chip(label: Text('${perms[p] ?? p}', style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
                          ]),
                      ]),
                    ),
                  ),
                ),
            ]),
            if (manage)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(onPressed: () => _edit(null, perms), icon: const Icon(Icons.add), label: const Text('Neue Rolle')),
              ),
          ]);
        },
      ),
    );
  }
}
