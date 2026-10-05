import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'api.dart';

/// Hinweis auf eine neue App-Version (vom Server über `info`, gepflegt in der .env des Webpanels).
class AppUpdate {
  AppUpdate({required this.latest, required this.required, required this.url});
  final String latest;
  final bool required;
  final String url;
}

/// Vergleicht Versionsnummern wie "1.2.10" (Zahl für Zahl). Negativ: a < b.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v.split('+').first.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
    if (p != q) return p < q ? -1 : 1;
  }
  return 0;
}

/// Liefert ein Update, wenn der Server eine neuere Version meldet als [installed]; sonst null.
/// [android] steuert, welcher Link gilt (Standard: aktuelle Plattform).
AppUpdate? appUpdateFrom(Json info, String installed, {bool? android}) {
  final u = info.o('app_update');
  if (u == null) return null;
  final isAndroid = android ?? (!kIsWeb && Platform.isAndroid);
  final latest = u.s('latest');
  final min = u.s('min');
  final url = isAndroid ? u.s('android_url') : u.s('ios_url');
  final needed = min.isNotEmpty && compareVersions(installed, min) < 0;
  if (!needed && (latest.isEmpty || compareVersions(installed, latest) >= 0)) return null;
  return AppUpdate(latest: latest.isEmpty ? min : latest, required: needed, url: url);
}
