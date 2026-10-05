// Prüft die App-Client-Klassen gegen einen echten Server.
// Start: flutter test test/integration_test.dart --dart-define=API_URL=http://127.0.0.1:8094 --dart-define=API_PASS=TestPass123
// (Admin 1000 und Mitarbeiter 2001 müssen dieses Passwort haben.) Ohne API_URL wird der Test übersprungen.
import 'package:flutter_test/flutter_test.dart';
import 'package:zeiterfassung/core/api.dart';
import 'package:zeiterfassung/core/format.dart';

const _url = String.fromEnvironment('API_URL');
const _pass = String.fromEnvironment('API_PASS');

Future<Api> _login(String nr) async {
  final r = await Api(baseUrl: _url).post('auth/login', {'login': nr, 'password': _pass, 'device': 'test'});
  return Api(baseUrl: _url, token: r['token'] as String);
}

void main() {
  final skip = _url.isEmpty ? 'API_URL nicht gesetzt' : null;

  test('Info und falscher Login', () async {
    final info = await Api(baseUrl: _url).get('info');
    expect(info.s('app'), isNotEmpty);
    expect(
      () => Api(baseUrl: _url).post('auth/login', {'login': '1000', 'password': 'falsch', 'device': 't'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'login_failed')),
    );
  }, skip: skip);

  test('Vollzugriff: alle Leserouten liefern lesbare Daten', () async {
    final api = await _login('1000');
    final me = await api.get('me');
    expect(me.o('user')!.s('role'), 'Vollzugriff');
    expect(me.o('user')!.b('time_tracking'), isFalse);
    expect(me.o('user')!.strs('permissions'), contains('roles.manage'));

    final users = await api.get('users/lookup');
    expect(users.l('users'), isNotEmpty);
    final uid = users.l('users').first.i('id');

    final week = await api.get('schedule', {'week': '2026-10-05'});
    final sched = week.o('schedule')!;
    expect(sched.strs('days'), hasLength(7));
    expect(sched.l('users'), isNotEmpty);
    final cells = sched.l('users').first.o('cells');
    expect(cells, isNotNull);
    expect(cells!.keys, contains('2026-10-05'));
    expect(week.o('business')!.o('2026-10-05')!.has('open'), isTrue);

    expect((await api.get('entries', {'user_id': '0', 'from': '2026-01-01', 'to': '2026-12-31'})).l('entries'), isA<List>());
    final rep = await api.get('report', {'month': '2026-09', 'user_id': '$uid'});
    expect(rep.o('report')!.l('rows'), hasLength(30));
    expect((await api.get('months', {'month': '2026-09'})).l('rows'), isNotEmpty);
    expect((await api.get('absences')).l('absences'), isA<List>());
    final cal = (await api.get('calendar', {'month': '2026-10'})).o('calendar')!;
    expect(cal.l('days'), hasLength(31));
    expect((await api.get('users')).l('users'), isNotEmpty);
    final roles = await api.get('roles');
    expect(roles.l('roles'), isNotEmpty);
    expect(roles.o('permissions')!.keys, contains('hours.own'));
    final biz = (await api.get('business', {'year': '2026'})).o('business')!;
    expect(biz.o('opening_hours')!['1'], isA<List>());
    expect(biz.o('opening_hours')!['7'], anyOf(isNull, isA<List>()));
    expect(biz.l('holidays'), isNotEmpty);
    expect((await api.get('updates')).o('updates')!.s('version'), isNotEmpty);
  }, skip: skip);

  test('Mitarbeiter: eigener Eintrag, kein Zugriff auf Verwaltung', () async {
    final api = await _login('2001');
    final now = DateTime.now();
    final d1 = Fmt.iso(DateTime(now.year, now.month, now.day));
    final d2 = Fmt.iso(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)));
    final me = await api.get('me');
    expect(me.o('user')!.b('time_tracking'), isTrue);

    await api.post('entries/manual', {'kind': 'work', 'date': d1, 'start': '08:00', 'end': '12:30', 'break_min': 0, 'note': 'App-Test'});
    var entries = (await api.get('entries', {'from': d1, 'to': d1})).l('entries');
    final mine = entries.where((e) => e.s('note') == 'App-Test').toList();
    expect(mine, isNotEmpty);
    expect(mine.first.i('worked_seconds'), 16200);
    await api.post('entries/save', {'id': mine.first.i('id'), 'date': d1, 'start': '08:00', 'end': '13:00', 'break_min': 30, 'note': 'App-Test'});
    entries = (await api.get('entries', {'from': d1, 'to': d1})).l('entries');
    expect(entries.firstWhere((e) => e.s('note') == 'App-Test').i('worked_seconds'), 16200);
    for (final e in entries.where((e) => e.s('note') == 'App-Test')) {
      await api.post('entries/delete', {'id': e.i('id')});
    }

    await api.post('entries/manual', {'kind': 'doctor', 'date': d2, 'start': '', 'end': '', 'break_min': 0, 'note': 'App-Test'});
    final abs = (await api.get('absences')).l('absences').where((a) => a.s('note') == 'App-Test').toList();
    expect(abs, isNotEmpty);
    expect(abs.first.s('type'), 'doctor');
    await api.post('absences/delete', {'id': abs.first.i('id')});

    for (final route in ['users', 'roles', 'business', 'updates']) {
      expect(() => api.get(route), throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)), reason: route);
    }
  }, skip: skip);
}
