import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

/// Ablage für Server-Adresse und Token (verschlüsselt auf dem Gerät; in Tests im Speicher).
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureStore implements KeyValueStore {
  const SecureStore();
  static const _s = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class MemoryStore implements KeyValueStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

/// Angemeldeter Benutzer, Rechte und API-Zugang für die ganze App.
class Session extends ChangeNotifier {
  Session(this.store, {this.apiFactory});

  final KeyValueStore store;
  final ApiBase Function(String server, String? token)? apiFactory;

  ApiBase? _api;
  Json? user;
  String server = '';
  bool starting = true;

  ApiBase get api => _api!;
  bool get loggedIn => _api != null && user != null;
  bool get mustChangePassword => user?['must_change_password'] == true;
  String get name => user?['name'] as String? ?? '';
  String get role => user?['role'] as String? ?? '';
  String get personnelNumber => user?['personnel_number'] as String? ?? '';
  int get userId => (user?['id'] as num?)?.toInt() ?? 0;
  bool get tracksTime => user?['time_tracking'] != false;
  Set<String> get permissions => ((user?['permissions'] as List?) ?? const []).map((e) => '$e').toSet();

  bool can(String perm) => permissions.contains(perm);
  bool canAny(Iterable<String> perms) => perms.any(can);

  ApiBase _make(String server, String? token) =>
      apiFactory != null ? apiFactory!(server, token) : Api(baseUrl: server, token: token);

  /// Beim Start: gespeicherte Sitzung wiederherstellen.
  Future<void> restore() async {
    server = await store.read('server') ?? '';
    final token = await store.read('token');
    if (server.isNotEmpty && token != null) {
      try {
        _api = _make(server, token);
        final me = await _api!.get('me');
        user = me.o('user');
      } on ApiException catch (e) {
        if (e.isAuth) {
          await store.delete('token');
          _api = null;
          user = null;
        }
        // bei Netzwerkfehlern bleibt die Sitzung erhalten; der Benutzer sieht dann einen Fehler mit „Erneut versuchen“
      }
    }
    starting = false;
    notifyListeners();
  }

  /// Verbindungstest: liefert Name/Version des Servers.
  Future<Json> probe(String serverUrl) => _make(serverUrl, null).get('info');

  Future<void> login(String serverUrl, String login, String password, String device) async {
    final api = _make(serverUrl, null);
    final r = await api.post('auth/login', {'login': login.trim(), 'password': password, 'device': device});
    server = serverUrl;
    final token = r['token'] as String;
    _api = _make(serverUrl, token);
    user = r.o('user');
    await store.write('server', serverUrl);
    await store.write('token', token);
    notifyListeners();
  }

  /// Benutzerdaten (Rechte, Passwortpflicht) neu laden; liefert die komplette `me`-Antwort.
  Future<Json> refresh() async {
    final me = await api.get('me');
    user = me.o('user');
    notifyListeners();
    return me;
  }

  Future<void> logout() async {
    try {
      await _api?.post('auth/logout');
    } catch (_) {
      // Token wird lokal ohnehin verworfen
    }
    await store.delete('token');
    _api = null;
    user = null;
    notifyListeners();
  }

  /// Sitzung ist serverseitig abgelaufen.
  Future<void> expire() async {
    await store.delete('token');
    _api = null;
    user = null;
    notifyListeners();
  }
}
