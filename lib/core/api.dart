import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;

/// Fehler der API (Netzwerk, Anmeldung, fehlende Rechte, Validierung). [message] ist für Benutzer bestimmt.
class ApiException implements Exception {
  ApiException(this.message, {this.code = 'error', this.status = 0});
  final String message;
  final String code;
  final int status;

  /// Sitzung abgelaufen / nicht angemeldet.
  bool get isAuth => code == 'not_logged_in';
  bool get mustChangePassword => code == 'password_change_required';
  bool get isNetwork => code == 'network';

  @override
  String toString() => message;
}

/// Schnittstelle zur API – in Tests durch eine Attrappe ersetzbar.
abstract class ApiBase {
  Future<Json> get(String route, [Map<String, String>? query]);
  Future<Json> post(String route, [Object? body]);
}

/// Echter Zugriff auf `<Server>/api/index.php?route=…` (Token im Header X-Auth-Token).
class Api implements ApiBase {
  Api({required this.baseUrl, this.token, http.Client? client}) : _client = client ?? http.Client();

  String baseUrl;
  String? token;
  final http.Client _client;

  Uri _uri(String route, Map<String, String>? query) {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/api/index.php').replace(queryParameters: {'route': route, ...?query});
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        if (token != null) 'X-Auth-Token': token!,
      };

  Future<Json> _send(String method, String route, {Map<String, String>? query, Object? body}) async {
    final uri = _uri(route, query);
    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 30)));
    } on TimeoutException {
      throw ApiException('Der Server antwortet nicht (Zeitüberschreitung).', code: 'network');
    } catch (_) {
      throw ApiException('Server nicht erreichbar. Bitte Internetverbindung und Server-Adresse prüfen.', code: 'network');
    }
    Json data;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw ApiException('Ungültige Antwort vom Server (HTTP ${res.statusCode}). Stimmt die Server-Adresse?',
          code: 'bad_response', status: res.statusCode);
    }
    if (res.statusCode >= 400 || data['ok'] != true) {
      throw ApiException((data['error'] as String?) ?? 'Unbekannter Fehler (HTTP ${res.statusCode})',
          code: (data['code'] as String?) ?? 'error', status: res.statusCode);
    }
    return data;
  }

  @override
  Future<Json> get(String route, [Map<String, String>? query]) => _send('GET', route, query: query);

  @override
  Future<Json> post(String route, [Object? body]) => _send('POST', route, body: body ?? <String, dynamic>{});

  void close() => _client.close();
}

/// Bequemer, fehlertoleranter Zugriff auf JSON-Antworten.
extension JsonX on Map<String, dynamic> {
  String s(String k) => this[k] == null ? '' : '${this[k]}';
  int i(String k) => (this[k] is num) ? (this[k] as num).round() : int.tryParse('${this[k]}') ?? 0;
  double d(String k) => (this[k] is num) ? (this[k] as num).toDouble() : double.tryParse('${this[k]}') ?? 0;
  bool b(String k) => this[k] == true || this[k] == 1 || this[k] == '1';
  bool has(String k) => this[k] != null;
  List<Json> l(String k) => (this[k] is List) ? (this[k] as List).whereType<Map<String, dynamic>>().toList() : <Json>[];
  List<String> strs(String k) => (this[k] is List) ? (this[k] as List).map((e) => '$e').toList() : <String>[];
  Json? o(String k) => this[k] is Map<String, dynamic> ? this[k] as Json : null;
}
