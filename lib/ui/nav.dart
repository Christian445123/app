import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import 'widgets.dart';

/// Ein Bereich der App (Seitenmenü). Sichtbar nur, wenn die Rolle ihn erlaubt.
class NavItem {
  const NavItem(this.key, this.label, this.icon, this.allowed, this.build);
  final String key;
  final String label;
  final IconData icon;
  final bool Function(Session) allowed;
  final Widget Function() build;
}

/// Wird in main.dart befüllt (vermeidet zyklische Importe zwischen Menü und Bildschirmen).
class NavRegistry {
  static List<NavItem> items = [];
}

/// Rahmen jedes Bereichs: Titel, Aktionen, Seitenmenü.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.navKey, required this.title, required this.body, this.actions = const [], this.fab});
  final String navKey;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: AppDrawer(current: navKey),
      floatingActionButton: fab,
      body: SafeArea(child: body),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final items = NavRegistry.items.where((i) => i.allowed(s)).toList();
    final t = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            color: t.colorScheme.primary,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('⏱  Zeiterfassung', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text('${s.role} · Nr. ${s.personnelNumber}', style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 13)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
              for (final i in items)
                ListTile(
                  leading: Icon(i.icon),
                  title: Text(i.label),
                  selected: i.key == current,
                  selectedTileColor: t.colorScheme.primaryContainer.withValues(alpha: .5),
                  onTap: () {
                    Navigator.pop(context);
                    if (i.key != current) {
                      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => i.build()), (r) => false);
                    }
                  },
                ),
            ]),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Passwort ändern'),
            onTap: () {
              Navigator.pop(context);
              changePassword(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Abmelden'),
            onTap: () async {
              Navigator.pop(context);
              await context.read<Session>().logout();
            },
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (c, snap) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(snap.hasData ? 'Version ${snap.data!.version} · ${s.server}' : s.server, style: t.textTheme.bodySmall, textAlign: TextAlign.center),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Passwort ändern (freiwillig oder erzwungen). Rückgabe: true = geändert.
Future<bool> changePassword(BuildContext context, {bool forced = false}) async {
  var done = false;
  final session = context.read<Session>();
  await showFormSheet(
    context,
    title: 'Passwort ändern',
    okLabel: 'Passwort ändern',
    fields: [
      FieldDef('info', forced ? 'Du verwendest ein Start- bzw. Standardpasswort. Bitte lege jetzt ein eigenes Passwort fest.' : 'Neues Passwort festlegen.', FieldType.info),
      const FieldDef('old', 'Aktuelles Passwort', FieldType.password, required: true),
      const FieldDef('new', 'Neues Passwort', FieldType.password, required: true, hint: 'mindestens 8 Zeichen'),
      const FieldDef('new2', 'Neues Passwort wiederholen', FieldType.password, required: true),
    ],
    onSave: (v) async {
      if (v['new'] != v['new2']) return 'Die neuen Passwörter stimmen nicht überein.';
      try {
        await session.api.post('auth/password', {'old': v['old'], 'new': v['new']});
        done = true;
        return null;
      } catch (e) {
        return e.toString();
      }
    },
  );
  if (done) {
    await session.refresh();
    if (context.mounted) toast(context, 'Passwort geändert.');
  }
  return done;
}
