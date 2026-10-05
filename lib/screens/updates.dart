import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Webpanel-Updates von GitHub: prüfen, einspielen, Modus wählen, Backups wiederherstellen.
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});
  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  int _version = 0;
  bool _busy = false;
  String? _log;

  Future<void> _run(Future<Json> Function() action, {String? done}) async {
    setState(() => _busy = true);
    final r = await guard(context, action);
    if (!mounted) return;
    setState(() {
      _busy = false;
      final res = r?.o('result');
      if (res != null) _log = res.s('log');
    });
    if (r != null) {
      final res = r.o('result');
      if (res != null && !res.b('success')) {
        toast(context, 'Update fehlgeschlagen – siehe Protokoll.', error: true);
      } else if (done != null) {
        toast(context, done);
      }
      setState(() => _version++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return PageScaffold(
      navKey: 'updates',
      title: 'Webpanel-Updates',
      body: Loader<Json>(
        key: ValueKey(_version),
        load: () => s.api.get('updates'),
        builder: (context, r, reload) {
          final u = r.o('updates') ?? {};
          final latest = u.o('latest');
          final available = latest != null && latest.b('available');
          final backups = u.strs('backups');
          final env = u.o('env') ?? {};
          return ListView(padding: const EdgeInsets.all(12), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Version ${u.s('version')}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Quelle: ${u.s('repo')} (${u.s('branch')}) · Modus: ${u.s('mode') == 'git' ? 'Git' : 'ZIP'}'),
                  if (u.s('current_sha').isNotEmpty) Text('Installierter Stand: ${u.s('current_sha').substring(0, u.s('current_sha').length < 7 ? u.s('current_sha').length : 7)}'),
                  if (u.s('last_update').isNotEmpty) Text('Letztes Update: ${u.s('last_update')}'),
                  const SizedBox(height: 10),
                  if (latest == null)
                    const Text('Noch nicht geprüft.')
                  else
                    Row(children: [
                      Pill(available ? 'Update verfügbar' : 'Aktuell', color: available ? AppTheme.warn : AppTheme.ok),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${latest.s('short')} – ${latest.s('message')}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _run(() => s.api.post('updates/panel_check'), done: 'Prüfung abgeschlossen.'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Auf Updates prüfen'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (!await confirmDialog(context, 'Webpanel jetzt von GitHub aktualisieren? Die Datenbank wird dabei automatisch migriert.', ok: 'Aktualisieren')) return;
                              if (!context.mounted) return;
                              await _run(() => s.api.post('updates/panel_update'), done: 'Webpanel aktualisiert.');
                            },
                      icon: const Icon(Icons.system_update_alt),
                      label: const Text('Jetzt aktualisieren'),
                    ),
                  ]),
                  if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                ]),
              ),
            ),
            const SectionTitle('Automatisches Update'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  DropdownButtonFormField<String>(
                    initialValue: ['off', 'notify', 'auto'].contains(u.s('panel_update_mode')) ? u.s('panel_update_mode') : 'off',
                    decoration: const InputDecoration(labelText: 'Update-Modus'),
                    items: const [
                      DropdownMenuItem(value: 'off', child: Text('Nur per Button')),
                      DropdownMenuItem(value: 'notify', child: Text('Hinweis bei neuer Version')),
                      DropdownMenuItem(value: 'auto', child: Text('Automatisch einspielen')),
                    ],
                    onChanged: (v) async {
                      final res = await guard(context, () => s.api.post('updates/settings', {'panel_update_mode': v}));
                      if (res != null && context.mounted) toast(context, 'Gespeichert.');
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(u.b('webhook_configured') ? 'GitHub-Webhook aktiv (${u.s('webhook_path')}).' : 'Kein Webhook-Secret gesetzt (DEPLOY_WEBHOOK_SECRET in der .env).', style: const TextStyle(fontSize: 12)),
                  Text('Server: ZIP ${env.b('zip') ? 'ja' : 'nein'} · Git ${env.b('git') ? 'ja' : 'nein'} · Schreibrechte ${env.b('writable') ? 'ja' : 'nein'}', style: const TextStyle(fontSize: 12)),
                ]),
              ),
            ),
            if (backups.isNotEmpty) ...[
              const SectionTitle('Sicherungen'),
              Card(
                child: Column(children: [
                  for (final b in backups)
                    ListTile(
                      dense: true,
                      title: Text(b),
                      trailing: TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                if (!await confirmDialog(context, 'Sicherung $b wiederherstellen?', ok: 'Wiederherstellen', danger: true)) return;
                                if (!context.mounted) return;
                                await _run(() => s.api.post('updates/panel_restore', {'name': b}), done: 'Wiederhergestellt.');
                              },
                        child: const Text('Wiederherstellen'),
                      ),
                    ),
                ]),
              ),
            ],
            if (_log != null && _log!.isNotEmpty) ...[
              const SectionTitle('Protokoll'),
              Card(child: Padding(padding: const EdgeInsets.all(12), child: SelectableText(_log!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)))),
            ],
          ]);
        },
      ),
    );
  }
}
