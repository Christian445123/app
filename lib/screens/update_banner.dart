import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/app_update.dart';
import '../core/session.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Zeigt oben auf der Übersicht, wenn der Server eine neuere App-Version meldet (Download/Store-Link).
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});
  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  AppUpdate? _update;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final s = context.read<Session>();
      final info = await s.probe(s.server);
      final installed = (await PackageInfo.fromPlatform()).version;
      final u = appUpdateFrom(info, installed);
      if (mounted) setState(() => _update = u);
    } on ApiException {
      // kein Hinweis, wenn der Server nicht antwortet
    } catch (_) {
      // z. B. Plattform ohne Paketinfo
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _update;
    if (u == null) return const SizedBox.shrink();
    final color = u.required ? AppTheme.danger : AppTheme.warn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: color.withValues(alpha: .12),
        child: ListTile(
          leading: Icon(Icons.system_update, color: color),
          title: Text(u.required ? 'Update erforderlich (Version ${u.latest})' : 'Neue App-Version ${u.latest} verfügbar'),
          subtitle: Text(u.url.isEmpty ? 'Bitte beim Administrator nachfragen.' : 'Antippen zum Herunterladen/Installieren.'),
          onTap: u.url.isEmpty
              ? null
              : () async {
                  final ok = await launchUrl(Uri.parse(u.url), mode: LaunchMode.externalApplication);
                  if (!ok && context.mounted) toast(context, 'Link konnte nicht geöffnet werden.', error: true);
                },
        ),
      ),
    );
  }
}
