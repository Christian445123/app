import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:zeiterfassung/core/api.dart';
import 'package:zeiterfassung/core/app_update.dart';
import 'package:zeiterfassung/core/format.dart';
import 'package:zeiterfassung/core/session.dart';
import 'package:zeiterfassung/main.dart';
import 'package:zeiterfassung/ui/nav.dart';
import 'package:zeiterfassung/ui/theme.dart';

const _employeePerms = ['hours.own', 'schedule.view', 'absences.request'];
const _allPerms = [
  'hours.own', 'schedule.view', 'absences.request', 'hours.view_all', 'hours.edit_all', 'reports.view_all', 'schedule.edit',
  'absences.manage', 'users.view', 'users.manage', 'roles.manage', 'overtime.manage', 'months.close', 'business.manage', 'updates.manage',
];

class FakeApi implements ApiBase {
  FakeApi(this.perms, {this.tracks = true});
  final List<String> perms;
  final bool tracks;
  final List<String> calls = [];

  Json get _user => {
        'id': 7, 'name': 'Max Muster', 'personnel_number': '1007', 'role': 'Test',
        'permissions': perms, 'must_change_password': false, 'time_tracking': tracks,
      };

  @override
  Future<Json> get(String route, [Map<String, String>? query]) async {
    calls.add('GET $route');
    switch (route) {
      case 'me':
        return {
          'ok': true,
          'user': _user,
          'recent_entries': [
            {'id': 1, 'user_id': 7, 'user_name': 'Max Muster', 'date': '2026-10-01', 'start': '08:00', 'end': '16:30', 'break_min': 30, 'worked_seconds': 28800, 'note': 'Test', 'editable': true}
          ],
          'dashboard': {
            'today_seconds': 3600,
            'week': {'worked': 7200, 'target': 144000},
            'month': {'worked': 7200, 'target': 144000, 'closed': false},
            'overtime_seconds': -5400,
            'vacation': {'year': 2026, 'entitlement': 25, 'carryover': 0, 'taken': 3, 'pending': 1, 'remaining': 22, 'remaining_after_pending': 21},
            'shifts': [
              {'id': 1, 'date': '2026-10-06', 'start': '08:00', 'end': '16:00', 'minutes': 450, 'note': ''}
            ],
          },
        };
      case 'entries':
        return {'ok': true, 'entries': []};
      case 'absences':
        return {'ok': true, 'absences': [], 'vacation': null, 'can_manage': perms.contains('absences.manage')};
      case 'months':
        return {'ok': true, 'rows': [], 'can_close_all': true};
      case 'calendar':
        return {'ok': true, 'calendar': {'days': [], 'users': []}};
      case 'users':
        return {'ok': true, 'users': [], 'can_manage': true};
      case 'roles':
        return {'ok': true, 'roles': [], 'permissions': {'hours.own': 'Eigene Stunden'}, 'can_manage': true};
      case 'business':
        return {
          'ok': true,
          'business': {
            'year': 2026,
            'opening_hours': {'1': ['07:00', '18:30'], '2': ['07:00', '18:30'], '3': ['07:00', '18:30'], '4': ['07:00', '18:30'], '5': ['07:00', '18:30'], '6': ['07:30', '13:00'], '7': null},
            'holidays': [
              {'date': '2026-12-25', 'name': 'Christtag', 'weekday': 'Fr', 'open': false, 'open_from': null, 'open_to': null}
            ],
            'special_days': [],
          },
        };
      case 'updates':
        return {'ok': true, 'updates': {'version': '2.0.0', 'repo': 'a/b', 'branch': 'main', 'mode': 'zip', 'backups': [], 'env': {}, 'panel_update_mode': 'off'}};
      case 'schedule':
        return {
          'ok': true,
          'can_edit': perms.contains('schedule.edit'),
          'schedule': {
            'week_start': '2026-10-05', 'week_end': '2026-10-11', 'kw': 41,
            'days': ['2026-10-05', '2026-10-06', '2026-10-07', '2026-10-08', '2026-10-09', '2026-10-10', '2026-10-11'],
            'day_plan_min': {'2026-10-05': 480}, 'day_planned': {'2026-10-05': 1},
            'users': [
              {
                'id': 7, 'name': 'Max Muster', 'show_actual': true, 'plan_min': 480, 'soll_min': 2400, 'ist_min': 0,
                'cells': {
                  '2026-10-05': {
                    'shifts': [
                      {'id': 3, 'start': '08:00', 'end': '16:00', 'break_min': 0, 'minutes': 480, 'note': ''}
                    ],
                    'plan_min': 480, 'target_min': 480, 'status': 'ok', 'late_min': 0,
                    'actual': {'entries': [], 'worked_min': 0, 'first': null, 'last': null},
                    'absence': null,
                  }
                },
              }
            ],
          },
          'business': {
            '2026-10-05': {'open': true, 'from': '07:00', 'to': '18:30', 'reason': ''},
          },
        };
      case 'report':
        return {
          'ok': true,
          'closed': false,
          'employee': {'name': 'Max Muster'},
          'report': {
            'worked': 0, 'target': 0, 'balance': 0, 'rows': [],
            'overtime': {'seconds': 0, 'since': '2026-01-01'}, 'vacation': null,
          },
        };
    }
    return {'ok': true};
  }

  @override
  Future<Json> post(String route, [Object? body]) async {
    calls.add('POST $route');
    return {'ok': true};
  }
}

Future<(Session, FakeApi)> _startApp(WidgetTester tester, List<String> perms, {bool tracks = true}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await initializeDateFormatting('de_AT');
  NavRegistry.items = buildNav();
  final fake = FakeApi(perms, tracks: tracks);
  final store = MemoryStore()..data['server'] = 'https://example.test';
  store.data['token'] = 'tok';
  final session = Session(store, apiFactory: (s, t) => fake);
  await session.restore();
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: session,
    child: MaterialApp(
      theme: AppTheme.build(Brightness.light),
      locale: const Locale('de', 'AT'),
      supportedLocales: const [Locale('de', 'AT')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: const Root(),
    ),
  ));
  await tester.pumpAndSettle();
  return (session, fake);
}

void main() {
  updateTests();
  group('Fmt', () {
    test('Stunden formatieren', () {
      expect(Fmt.hm(3600), '1:00');
      expect(Fmt.hm(5400), '1:30');
      expect(Fmt.hm(-5400), '-1:30');
      expect(Fmt.signed(600), '+0:10');
      expect(Fmt.days(8.5), '8,5');
      expect(Fmt.days(25), '25');
      expect(Fmt.date('2026-10-05'), '05.10.2026');
    });
  });

  testWidgets('Mitarbeiter sieht nur seine Bereiche', (tester) async {
    await _startApp(tester, _employeePerms);
    expect(find.textContaining('Hallo Max'), findsOneWidget);
    expect(find.text('Plus-/Minusstunden'.toUpperCase()), findsOneWidget);
    expect(find.textContaining('-1:30'), findsOneWidget);
    expect(find.byKey(const Key('addEntry')), findsOneWidget);

    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Dienstplan'), findsOneWidget);
    expect(find.text('Zeiten'), findsOneWidget);
    expect(find.text('Abwesenheiten'), findsOneWidget);
    expect(find.text('Mitarbeiter'), findsNothing);
    expect(find.text('Rollen & Rechte'), findsNothing);
    expect(find.text('Betrieb'), findsNothing);
    expect(find.text('Webpanel-Updates'), findsNothing);
  });

  testWidgets('Vollzugriff sieht alle Bereiche, Verwaltungskonto ohne Zeiterfassung', (tester) async {
    await _startApp(tester, _allPerms, tracks: false);
    expect(find.byKey(const Key('addEntry')), findsNothing);
    expect(find.textContaining('Verwaltungskonto'), findsOneWidget);

    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    for (final l in ['Übersicht', 'Dienstplan', 'Zeiten', 'Auswertung', 'Monatsabschluss', 'Urlaubsplaner', 'Abwesenheiten', 'Mitarbeiter', 'Rollen & Rechte', 'Betrieb', 'Webpanel-Updates']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
  });

  for (final entry in {
    'Dienstplan': 'KW 41',
    'Zeiten': 'Keine Einträge im Zeitraum.',
    'Auswertung': 'Max Muster',
    'Monatsabschluss': 'Keine Mitarbeiter.',
    'Urlaubsplaner': 'Keine Mitarbeiter.',
    'Abwesenheiten': 'Keine Einträge.',
    'Mitarbeiter': 'Neu',
    'Rollen & Rechte': 'Neue Rolle',
    'Betrieb': 'Christtag',
    'Webpanel-Updates': 'Version 2.0.0',
  }.entries) {
    testWidgets('Bereich ${entry.key} lädt', (tester) async {
      await _startApp(tester, _allPerms);
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text(entry.key)));
      await tester.pumpAndSettle();
      expect(find.textContaining(entry.value), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Stunden eintragen sendet entries/manual', (tester) async {
    final (_, fake) = await _startApp(tester, _employeePerms);
    await tester.tap(find.byKey(const Key('addEntry')));
    await tester.pumpAndSettle();
    expect(find.text('Stunden eintragen'), findsWidgets);
    await tester.tap(find.text('Eintragen'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('POST entries/manual'));
  });
}

void updateTests() {
  group('App-Update', () {
    test('Versionsvergleich', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('1.0.0+5', '1.0.0'), 0);
    });
    test('Hinweis nur bei neuerer Version', () {
      final info = {'app_update': {'latest': '1.2.0', 'min': '', 'android_url': 'https://a/apk', 'ios_url': 'https://i'}};
      expect(appUpdateFrom(info, '1.2.0', android: true), isNull);
      final u = appUpdateFrom(info, '1.1.0', android: true)!;
      expect(u.url, 'https://a/apk');
      expect(u.required, isFalse);
      expect(appUpdateFrom(info, '1.1.0', android: false)!.url, 'https://i');
      final req = {'app_update': {'latest': '1.2.0', 'min': '1.1.5', 'android_url': '', 'ios_url': ''}};
      expect(appUpdateFrom(req, '1.1.0', android: true)!.required, isTrue);
      expect(appUpdateFrom({'app_update': {'latest': '', 'min': '', 'android_url': '', 'ios_url': ''}}, '1.0.0'), isNull);
    });
  });
}
