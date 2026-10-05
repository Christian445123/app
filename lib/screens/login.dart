import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../ui/nav.dart';
import '../ui/theme.dart';

const defaultServer = 'https://zeiterfassung.gamingcommunity.at';

String _deviceName() {
  if (kIsWeb) return 'Web';
  try {
    return Platform.isIOS ? 'iPhone/iPad' : (Platform.isAndroid ? 'Android' : Platform.operatingSystem);
  } catch (_) {
    return 'App';
  }
}

/// Anmeldung mit Server-Adresse, Personalnummer und Passwort.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _server = TextEditingController();
  final _login = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _server.text = s.server.isNotEmpty ? s.server : defaultServer;
  }

  @override
  void dispose() {
    _server.dispose();
    _login.dispose();
    _pass.dispose();
    super.dispose();
  }

  String get _serverUrl {
    var v = _server.text.trim();
    if (v.isNotEmpty && !v.startsWith('http')) v = 'https://$v';
    return v.replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> _probe() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final r = await context.read<Session>().probe(_serverUrl);
      setState(() => _info = 'Verbunden mit „${r.s('app')}“ (Version ${r.s('version')}).');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Bitte Personalnummer und Passwort eingeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await context.read<Session>().login(_serverUrl, _login.text, _pass.text, _deviceName());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: t.colorScheme.primary, borderRadius: BorderRadius.circular(20)),
                    child: const Center(child: Text('⏱', style: TextStyle(fontSize: 38))),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Zeiterfassung', textAlign: TextAlign.center, style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Mit deiner Personalnummer anmelden', textAlign: TextAlign.center, style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('server'),
                  controller: _server,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Server-Adresse',
                    suffixIcon: IconButton(tooltip: 'Verbindung prüfen', icon: const Icon(Icons.wifi_tethering), onPressed: _busy ? null : _probe),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('login'),
                  controller: _login,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'Personalnummer'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('password'),
                  controller: _pass,
                  obscureText: _hide,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Passwort',
                    suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _hide = !_hide)),
                  ),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppTheme.danger))),
                if (_info != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_info!, style: const TextStyle(color: AppTheme.ok))),
                const SizedBox(height: 18),
                FilledButton(
                  key: const Key('submit'),
                  onPressed: _busy ? null : _submit,
                  child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Anmelden'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Start-/Standardpasswort muss vor der ersten Nutzung geändert werden.
class ForcePasswordScreen extends StatelessWidget {
  const ForcePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passwort festlegen')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.lock_reset, size: 56),
          const SizedBox(height: 16),
          const Text('Du verwendest ein Start- bzw. Standardpasswort. Bitte lege jetzt ein eigenes Passwort fest.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => changePassword(context, forced: true), child: const Text('Passwort festlegen')),
          TextButton(onPressed: () => context.read<Session>().logout(), child: const Text('Abmelden')),
        ]),
      ),
    );
  }
}
