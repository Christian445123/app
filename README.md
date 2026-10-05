# Zeiterfassung – App (iOS & Android)

Flutter-App für das Zeiterfassungssystem. Sie enthält alle Funktionen des Webpanels und spricht ausschließlich über die
REST-API (`<Server>/api/index.php`) mit dem Webpanel. Was jemand sieht und darf, bestimmt die Rolle im Webpanel – die App
baut ihr Menü aus den Rechten, die der Server liefert, und der Server prüft jede Aktion erneut.

## Funktionen

| Bereich | Inhalt |
|---|---|
| Übersicht | Heute/Woche/Monat, Plus-/Minusstunden, Resturlaub, nächste Schichten, letzte Einträge |
| Zeiten | Stunden von Hand eintragen/ändern/löschen (kein Ein-/Ausstempeln); als Art auch Arzt, Krank, Urlaub, Zeitausgleich |
| Auswertung | Monatsauswertung je Tag mit Soll/Ist, Feiertage, Abwesenheiten, Überstundenkonto |
| Monatsabschluss | Monat automatisch summiert, abschließen / (Verwaltung) wieder öffnen |
| Dienstplan | Woche und Tag (Zeitleiste Soll gegen Ist), Mitarbeiter einteilen, Vorwoche kopieren |
| Urlaubsplaner | Monatskalender, wer wann abwesend ist |
| Abwesenheiten | beantragen, genehmigen/ablehnen, Urlaubskonto (5 Wochen) |
| Mitarbeiter | anlegen/bearbeiten, Rolle, Arbeitszeitmodell je Wochentag, Urlaub, Überstunden buchen |
| Rollen & Rechte | Rollen anlegen und Rechte vergeben |
| Betrieb | Öffnungszeiten, Feiertage öffnen/schließen, Sondertage |
| Webpanel-Updates | Update von GitHub prüfen und einspielen |

Das Verwaltungskonto (Admin) hat keine eigene Zeiterfassung – es plant und verwaltet nur.

## Anmeldung

Beim ersten Start die Server-Adresse eintragen (Standard `https://zeiterfassung.gamingcommunity.at`), dann
**Personalnummer + Passwort**. Die App erhält einen Geräte-Token (verschlüsselt im Schlüsselbund bzw. Keystore gespeichert),
das Passwort wird nicht gespeichert. Start-Passwörter müssen beim ersten Login geändert werden. Beim Abmelden wird der Token
auf dem Server gelöscht. Voraussetzung auf dem Server: Webpanel ab Version 2.0 mit Migration `007_app_api` (kommt mit dem
normalen Panel-Update).

## Entwickeln

```bash
flutter pub get
flutter analyze
flutter test                      # Oberflächen-Tests mit simuliertem Server

# Test gegen einen echten Server (zwei Test-Konten mit gleichem Passwort nötig):
flutter test test/integration_test.dart --dart-define=API_URL=http://127.0.0.1:8094 --dart-define=API_PASS=...

flutter run                       # Gerät/Emulator
```

## Bauen

* **Android:** `flutter build apk --release` (Datei `build/app/outputs/flutter-apk/app-release.apk`) bzw.
  `flutter build appbundle --release` für den Play Store. Ohne eigenen Schlüssel wird mit dem Debug-Schlüssel signiert
  (zum Installieren auf eigenen Geräten ok). Für den Play Store einen Upload-Key anlegen und in
  `android/app/build.gradle.kts` unter `signingConfigs` eintragen
  ([Anleitung](https://docs.flutter.dev/deployment/android#sign-the-app)).
* **iOS:** erfordert einen Mac mit Xcode und einen Apple-Developer-Account (99 USD/Jahr). Bundle-ID
  `at.gamingcommunity.zeiterfassung` in Xcode (`ios/Runner.xcworkspace`) mit dem eigenen Team signieren, dann
  `flutter build ipa` und über Xcode/Transporter in TestFlight hochladen. Ohne Mac: GitHub Actions (macOS) – der Workflow
  baut unsigniert zur Kontrolle; für signierte Builds Zertifikat und Provisioning-Profil als GitHub-Secrets hinterlegen.

### GitHub Actions

`.github/workflows/build.yml` prüft bei jedem Push (analyze + Tests), baut die Android-APK/AAB und die iOS-App
(unsigniert) und legt sie als Artefakte ab. Ein Tag `v1.0.0` erzeugt zusätzlich ein GitHub-Release mit der APK.

## Version

Versionsnummer in `pubspec.yaml` (`version: 1.0.0+1`; die Zahl nach `+` ist die Build-Nummer, der Workflow setzt sie
automatisch hoch).

## Aufbau

```
lib/core      API-Client (token), Session/Rechte, Formate
lib/ui        Theme, Menü (nach Rechten), Formular-Sheets, Lade-Hilfen
lib/screens   ein Bildschirm je Bereich
test          Oberflächen-Tests (simulierte API) und Integrationstest (echter Server)
```
