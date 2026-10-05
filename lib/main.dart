import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/session.dart';
import 'screens/absences.dart';
import 'screens/business.dart';
import 'screens/calendar.dart';
import 'screens/entries.dart';
import 'screens/login.dart';
import 'screens/months.dart';
import 'screens/overview.dart';
import 'screens/report.dart';
import 'screens/roles.dart';
import 'screens/schedule.dart';
import 'screens/updates.dart';
import 'screens/users.dart';
import 'ui/nav.dart';
import 'ui/theme.dart';

/// Alle Bereiche der App. Welche davon sichtbar sind, bestimmt die Rolle des Benutzers (Rechte vom Server).
List<NavItem> buildNav() => [
      NavItem('overview', 'Übersicht', Icons.dashboard_outlined, (s) => true, () => const OverviewScreen()),
      NavItem('schedule', 'Dienstplan', Icons.view_timeline_outlined, (s) => s.can('schedule.view'), () => const ScheduleScreen()),
      NavItem('entries', 'Zeiten', Icons.schedule, (s) => s.canAny(['hours.own', 'hours.view_all']), () => const EntriesScreen()),
      NavItem('report', 'Auswertung', Icons.bar_chart, (s) => s.canAny(['hours.own', 'reports.view_all']), () => const ReportScreen()),
      NavItem('months', 'Monatsabschluss', Icons.lock_clock,
          (s) => s.canAny(['hours.own', 'hours.view_all', 'reports.view_all', 'months.close', 'months.close_own']), () => const MonthsScreen()),
      NavItem('calendar', 'Urlaubsplaner', Icons.beach_access_outlined,
          (s) => s.canAny(['schedule.view', 'absences.request', 'absences.manage']), () => const CalendarScreen()),
      NavItem('absences', 'Abwesenheiten', Icons.event_busy_outlined, (s) => s.canAny(['absences.request', 'absences.manage']), () => const AbsencesScreen()),
      NavItem('users', 'Mitarbeiter', Icons.people_outline, (s) => s.canAny(['users.view', 'users.manage']), () => const UsersScreen()),
      NavItem('roles', 'Rollen & Rechte', Icons.admin_panel_settings_outlined, (s) => s.can('roles.manage'), () => const RolesScreen()),
      NavItem('business', 'Betrieb', Icons.store_outlined, (s) => s.can('business.manage'), () => const BusinessScreen()),
      NavItem('updates', 'Webpanel-Updates', Icons.system_update_alt, (s) => s.can('updates.manage'), () => const UpdatesScreen()),
    ];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_AT');
  NavRegistry.items = buildNav();
  final session = Session(const SecureStore());
  runApp(ChangeNotifierProvider.value(value: session, child: const ZeitApp()));
  await session.restore();
}

class ZeitApp extends StatelessWidget {
  const ZeitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zeiterfassung',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      locale: const Locale('de', 'AT'),
      supportedLocales: const [Locale('de', 'AT'), Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Root(),
    );
  }
}

/// Zeigt je nach Zustand: Start, Anmeldung, Pflicht-Passwortwechsel oder die App.
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    if (s.starting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!s.loggedIn) return const LoginScreen();
    if (s.mustChangePassword) return const ForcePasswordScreen();
    return Navigator(
      key: ValueKey('nav-${s.userId}'),
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const OverviewScreen()),
    );
  }
}
