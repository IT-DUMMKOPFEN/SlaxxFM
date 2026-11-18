# SlaxxFM

Schlanker Player für freie Internet-Musiksender – nach Ländern sortiert.
Für Windows, Linux, macOS (Intel + Apple Silicon) und Android.

*Geschrieben von IT-Dummkopfen mit Hilfe einer KI.*

## Funktionen

- **Länder → Sender → Abspielen**: Land anklicken zeigt dessen Sender, Sender anklicken spielt den Stream.
- **Senderliste aktualisieren** (⟳): lädt alle als funktionierend bekannten Sender von
  [radio-browser.info](https://www.radio-browser.info) (Community-Datenbank, ~40.000 Sender) und die kuratierten GitHub-Listen.
- **Doppelte entfernen**: gleiche Stream-URL oder gleicher Name im selben Land → der beste Eintrag bleibt (mit Logo, mehr Stimmen, höherer Bitrate).
- **Streams prüfen**: testet jeden Stream wirklich (liefert er Audio?). Nicht funktionierende werden entfernt.
- **Automatisch aufräumen** (🧹): Doppelte entfernen + alle Streams prüfen + defekte entfernen + VPN markieren – für ein Land oder alle.
- **VPN-Label** unten rechts: Streams, die mit HTTP 401/403/451 antworten (regional gesperrt), bzw. beim Abspielen „403 Forbidden“ melden.
- **Player-Leiste** unten: Stopp, Zurück, Abspielen/Pause, Weiter, Favorit; rechts Lautstärkeregler und Stumm-Knopf.
- **Visualisierung** mit 9 Effekten (Equalizer, Regenbogen, rund, Sternenflug, Sound Wave, Farbwellen, Diskolicht, Diskokugel, Feuerwerk) – Klick wechselt, jeder Effekt einzeln abschaltbar.
- **Tanzfläche**: eine Menge schwarzer Silhouetten in drei Reihen mit natürlichen Bewegungen echter Tänzer (Umrisse aus freien Green-Screen-Videos, `tool/extract_dancers.py`), Tempo passend zu den BPM; abschaltbar.
- **Puffer** 0 / 3 / 5 Sekunden (Standard 3 s) gegen kurze Stream-Aussetzer.
- **Favoriten exportieren/importieren** (SlaxxFM-JSON oder M3U-Playlist).
- **Hilfe** auf Deutsch und Englisch in der App.
- **Senderbild + Infos**: Logo, Land, Sprache, Genres, Homepage, Codec, Bitrate, Abtastrate und – sofern der Sender ICY-Metadaten liefert – der aktuelle Titel, ICY-Name/-Genre.
- **Nur Musiksender** (Einstellung, Standard an): blendet reine Nachrichten-, Talk-, Sport- und Religionssender aus.
- **Hell / Dunkel / System**, Deutsch / Englisch.
- Responsives Layout: Desktop 3 Spalten (Länder | Sender | Player), Tablet 2 Spalten + Playerleiste, Handy Länderliste → Senderliste mit Mini-Player.
- Entfernte Sender lassen sich in den Einstellungen wiederherstellen.

## Android

- **Hintergrundwiedergabe**: Vordergrund-Dienst mit Medien-Benachrichtigung, CPU-Wakelock und WLAN-Lock – der Stream läuft auch bei ausgeschaltetem Bildschirm weiter.
- **Automatisches Neuverbinden**, wenn ein Stream abbricht oder hängen bleibt (z. B. Wechsel WLAN ↔ Mobilfunk).
- **Audio-Fokus**: pausiert bei Anrufen, wird bei Navigationsansagen leiser, stoppt beim Abziehen des Kopfhörers.
- **Android Auto**: Favoriten, Zuletzt gehört, Länder → Sender; Sprachsuche („Spiele … auf SlaxxFM“), Weiter/Zurück wechselt den Sender.
  Da die App nicht aus dem Play Store kommt, muss in Android Auto einmalig *Entwicklereinstellungen → Unbekannte Quellen* aktiviert werden
  (Entwicklermodus: in Android Auto 10× auf „Version“ tippen).
- Falls ein Hersteller (Xiaomi, Huawei, Samsung …) die App trotzdem beendet: in den Akku-Einstellungen für SlaxxFM „Nicht optimieren“ wählen.

## Senderquellen

| Quelle | Inhalt |
|---|---|
| [radio-browser.info](https://www.radio-browser.info) | Hauptquelle, alle Länder, Logos, Tags, Codec, Bitrate |
| [deroverda/recommended-radio-streams](https://github.com/deroverda/recommended-radio-streams) | kuratierte Genre-Playlists (unter „International“) |
| [mikepierce/internet-radio-streams](https://github.com/mikepierce/internet-radio-streams) | kuratierte Sender (KEXP, NTS, FIP, SomaFM, Radio Paradise …), Ländern zugeordnet |
| [LITUATUI/M3UPT](https://github.com/LITUATUI/M3UPT) | portugiesische Radiosender mit Logos |

Ein Schnappschuss der GitHub-Listen liegt in `assets/curated_stations.json` (621 Sender) und wird beim ersten Start sofort angezeigt.
Neu erzeugen: `python3 tool/build_curated.py <ordner-mit-den-geklonten-repos> assets/curated_stations.json`.

liveradiostream.com und worldfreeradio.com sind Webseiten ohne offene Liste/API und werden deshalb nicht automatisch ausgelesen.

## Bauen

### Über GitHub Actions (empfohlen)
Workflow `.github/workflows/build.yml`: unter *Actions → Build SlaxxFM → Run workflow* starten oder ein Tag `v1.0.0` pushen
(dann wird automatisch ein Release mit allen Dateien erstellt):

- `SlaxxFM-windows-x64.zip`
- `SlaxxFM-linux-x64.tar.gz`
- `SlaxxFM-macos-universal.zip`
- `SlaxxFM-android-universal.apk` + Split-APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`)

### Lokal
Die Plattformordner werden von `flutter create` erzeugt und anschließend gepatcht (Internet-Rechte, http-Streams, App-Name, Icon):

```bash
./setup.sh              # macOS / Linux
.\setup.ps1             # Windows
flutter run -d macos    # bzw. windows / linux / Android-Gerät
```

**Linux** braucht libmpv: `sudo apt install libmpv-dev mpv` (zum Starten reicht `libmpv2` bzw. `mpv`).

## Technik

Flutter + [media_kit](https://pub.dev/packages/media_kit) (libmpv) – wie SlaxxTV.

```
lib/
  main.dart                     App, Themes
  l10n.dart                     Texte DE/EN
  models/station.dart           Sender-Modell
  services/radio_browser.dart   radio-browser.info API (Server-Fallback)
  services/curated_sources.dart GitHub-Listen + M3U-Parser
  services/station_repository.dart  Cache, Länder, Doppelte, Prüfen, Aufräumen
  services/stream_tester.dart   Stream-Test (ok / VPN / defekt)
  services/player_service.dart  Player + ICY-Metadaten
  ui/...                        Oberfläche
```
