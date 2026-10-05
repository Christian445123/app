# Zeiterfassung – App (Android)

Flutter-App (Android/Samsung) für das Zeiterfassungssystem. Sie enthält alle Funktionen des Webpanels und spricht ausschließlich über die
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

### GitHub Actions

`.github/workflows/build.yml` prüft bei jedem Push (analyze + Tests), baut die Android-APK/AAB und legt sie als Artefakte ab. Ein Tag `v1.0.0` erzeugt zusätzlich ein GitHub-Release mit der APK.

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

## Installation auf dem Handy

**Android (Samsung & Co.)**
1. Im GitHub-Repo unter *Releases* (bzw. *Actions → Artefakte*) die Datei `app-release.apk` herunterladen – am Handy im Browser.
2. Antippen → beim ersten Mal „Installation aus dieser Quelle zulassen“ bestätigen → *Installieren*.
3. App „Zeiterfassung“ öffnen, Server-Adresse prüfen, mit Personalnummer anmelden.

Die App ist nur für Android (Samsung & Co.) vorgesehen; eine iPhone-Version ist nicht eingeplant.

## Updates der App

* Neue Version: `version:` in `pubspec.yaml` erhöhen, committen, Tag setzen (`git tag v1.1.0 && git push --tags`) – der
  Workflow baut APK/AAB und legt die APK als GitHub-Release ab.
* Der Server liest das neueste GitHub-Release selbst: In der `.env` des **Webpanels** einmalig `APP_GITHUB_REPO=Besitzer/Zeiterfassung-App` eintragen.
  Danach meldet das Webpanel jede neue Version (Tag `v1.1.0`) samt APK-Link automatisch (Abfrage höchstens stündlich) – nichts mehr von Hand ändern.
  Die App zeigt auf der Übersicht „Neue App-Version verfügbar“; Antippen öffnet den Download.
* Optional: `APP_MIN_VERSION` (ältere Versionen = „Update erforderlich“).
* Android: Die neue APK muss mit **demselben Schlüssel** signiert sein wie die installierte, sonst lässt sie sich nicht
  darüber installieren – den Release-Schlüssel (Keystore) deshalb sicher aufbewahren und von Anfang an verwenden
  (siehe „Bauen“).

## Signierschlüssel (wichtig für Updates)

Die APK muss immer mit demselben Schlüssel signiert werden, sonst lässt sie sich nicht über die installierte App
installieren. Der Schlüssel liegt lokal in `signing/` (nicht im Repository!). Die vier Werte aus `signing/GITHUB-SECRETS.txt`
werden einmalig als *Actions-Secrets* im GitHub-Repo hinterlegt (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`). Der Workflow baut die Release-APK dann automatisch damit. Den Ordner `signing/`
zusätzlich sicher sichern – ohne ihn sind keine Updates mehr möglich.
