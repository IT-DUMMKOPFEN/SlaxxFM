import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/settings.dart';

class _Section {
  final IconData icon;
  final String title;
  final List<String> lines; // "• " = bullet, "## " = sub heading
  const _Section(this.icon, this.title, this.lines);
}

const _de = <_Section>[
  _Section(Icons.waving_hand_rounded, 'Willkommen bei SlaxxFM', [
    'SlaxxFM spielt freie Internet-Musiksender aus der ganzen Welt – sortiert nach Ländern, ohne Anmeldung und ohne Werbung von uns.',
    'Die Senderliste stammt aus der Community-Datenbank radio-browser.info (rund 40.000 Sender) und aus kuratierten Listen auf GitHub.',
  ]),
  _Section(Icons.public_rounded, 'Länder und Sender', [
    '• Links (bzw. auf dem Handy auf der Startseite) siehst du alle Länder mit der Anzahl ihrer Sender.',
    '• Ein Klick auf ein Land zeigt dessen Sender als Kacheln.',
    '• Ein Klick auf eine Kachel spielt den Sender sofort ab.',
    '• „Favoriten“ (Stern) und „International“ stehen immer ganz oben. Unter „International“ findest du Sender ohne festes Land, z. B. aus den kuratierten Listen.',
    '• Über dem Länder-Verzeichnis kannst du nach einem Land suchen.',
    '## Suche',
    '• Das Feld „Sender suchen…“ durchsucht alle Länder nach Name und Genre (z. B. „jazz“, „80s“, „techno“).',
    '• Mit dem ✕ im Suchfeld kommst du zurück zum gewählten Land.',
  ]),
  _Section(Icons.play_circle_rounded, 'Abspielen und Lautstärke', [
    '• Unten befindet sich die Player-Leiste: Stopp, vorheriger Sender, Abspielen/Pause, nächster Sender und Favorit.',
    '• Ganz rechts unten: Lautstärke-Regler (mit − und +) und der Stumm-Knopf. Ein erneuter Klick auf den Stumm-Knopf schaltet den Ton wieder ein.',
    '• Vorheriger/Nächster wechselt innerhalb der Liste, aus der du den Sender gestartet hast (Land, Favoriten oder Suchergebnis).',
    '• Pause bei Live-Radio: Beim Fortsetzen verbindet sich SlaxxFM neu mit dem Live-Stream – du hörst also wieder „live“.',
    '• Auf dem Handy öffnet ein Tipp auf die Player-Leiste den großen Player mit allen Infos und der Visualisierung.',
    '## Senderinfos',
    'Neben dem Senderbild stehen Name, Land und – wenn der Sender es mitschickt – der aktuelle Titel. Unter „Details“ findest du Sprache, Genres, Webseite, Codec, Bitrate, Abtastrate, ICY-Infos und die Stream-Adresse (Klick kopiert sie).',
  ]),
  _Section(Icons.star_rounded, 'Favoriten', [
    '• Der Stern auf einer Kachel oder im Player fügt den Sender zu den Favoriten hinzu bzw. entfernt ihn.',
    '• Favoriten werden beim Aufräumen nie entfernt.',
    '## Exportieren und importieren',
    '• Menü (⋮) oder Einstellungen → „Favoriten exportieren (SlaxxFM)“ speichert eine .json-Datei mit allen Infos – ideal als Sicherung oder für ein anderes Gerät.',
    '• „Als M3U-Playlist exportieren“ erzeugt eine Playlist, die auch VLC, Winamp, Kodi usw. abspielen können.',
    '• „Favoriten importieren“ liest eine SlaxxFM-Datei oder eine beliebige M3U-Playlist ein. Sender, die noch nicht in der Liste sind, werden automatisch hinzugefügt.',
  ]),
  _Section(Icons.refresh_rounded, 'Senderliste aktualisieren und aufräumen', [
    '## Aktualisieren (⟳)',
    'Lädt die komplette, aktuelle Senderliste neu herunter. Das dauert je nach Verbindung ein paar Sekunden.',
    '## Doppelte entfernen',
    'Findet Sender mit derselben Stream-Adresse oder demselben Namen im selben Land. Der beste Eintrag (mit Logo, mehr Stimmen, höherer Bitrate) bleibt erhalten.',
    '## Streams prüfen',
    'Testet jeden Stream wirklich: Liefert er Audio? Defekte Streams werden entfernt.',
    '## Automatisch aufräumen (Besen)',
    'Macht alles in einem Schritt: Doppelte entfernen, alle Streams prüfen, defekte entfernen und gesperrte Streams mit „VPN“ markieren. Du kannst wählen, ob nur das aktuelle Land oder alle Länder geprüft werden. Alle Länder dauern eine Weile – der Fortschritt wird oben angezeigt und kann abgebrochen werden.',
    '• Entfernte Sender kannst du in den Einstellungen jederzeit wiederherstellen.',
  ]),
  _Section(Icons.vpn_lock_rounded, 'Das VPN-Label', [
    'Manche Sender sind nur in ihrem Heimatland hörbar (Geoblocking). Antwortet ein Stream mit „Zugriff verweigert“ (HTTP 401, 403 oder 451), bekommt er unten rechts das orange Label „VPN“.',
    '• Mit einem VPN-Dienst, der eine Verbindung in das Land des Senders herstellt, funktioniert der Stream meist.',
    '• In den Einstellungen kannst du solche Sender ganz ausblenden.',
    '• Hinweis: Selten blockieren Server auch einfach Programme statt Länder – dann hilft auch ein VPN nicht.',
  ]),
  _Section(Icons.graphic_eq_rounded, 'Visualisierung', [
    'Im freien Bereich unter den Senderinfos (bzw. über der Player-Leiste) läuft eine Visualisierung zur Musik.',
    '• Ein Klick (Handy: Tipp) auf die Visualisierung wechselt zum nächsten Effekt; der Name wird kurz eingeblendet.',
    '• 22 Effekte: Equalizer, Regenbogen-Equalizer, runder Equalizer, Sternenflug (runder, drehender Equalizer mit Sternen, die auf dich zufliegen), Sound Wave, Farbwellen, Diskolicht, Diskokugel, Feuerwerk, Lasershow, Tunnel, Synthwave mit Retro-Sonne, VU-Meter, Wellenringe, Nordlichter, Kaleidoskop, Plasma, Spektrum-Berge, Blasen, Galaxie-Spirale, LED-Spektrum und Planeten.',
    '• In den Einstellungen kannst du jeden Effekt einzeln ein- und ausschalten. Sind alle aus (und die Tänzer auch), verschwindet die Visualisierung.',
    '## Tanzende Leute',
    'Wenn Musik läuft, füllt sich die Tanzfläche: schwarze Silhouetten in drei versetzten Reihen vor buntem Club-Licht. Es gibt Disco- und Partytänzer, Ballett (Tutu, Spitzenschuhe, Arabesque, Pirouette, Grand Jeté), Sprünge, Drehungen und Paare (Swing, Drehung unter dem Arm, Tanzhaltung). Die Bewegungen gehen fließend im Takt ineinander über, jede Person hat ihren eigenen Groove. Bei Sprache (Nachrichten, Moderation) setzen sie sich aus. Oben rechts in der Visualisierung siehst du das erkannte Tempo (BPM) bzw. „Sprache“.',
    '• Die Tänzer sind standardmäßig an und lassen sich in den Einstellungen ausschalten.',
    '## Wie wird gemessen?',
    '• Linux: SlaxxFM misst die echte Lautstärke des Streams und erkennt daraus Beats, BPM sowie Musik oder Sprache.',
    '• Android: Mit der Einstellung „Echte Audio-Analyse“ wird das echte Spektrum gemessen. Android verlangt dafür die Mikrofon-Berechtigung – SlaxxFM nimmt aber nichts auf, sondern liest nur die eigene Audioausgabe.',
    '• Windows, macOS und Android ohne diese Option: Die Audio-Engine hat dort keine Messfunktion. Die Effekte laufen dann musikalisch animiert, das Tempo wird aus dem Genre des Senders geschätzt (angezeigt mit „~“). Bei Talk-, Nachrichten- und Sportsendern erkennt SlaxxFM „Sprache“ am Genre.',
  ]),
  _Section(Icons.phone_android_rounded, 'Android, Hintergrund und Android Auto', [
    '• SlaxxFM spielt im Hintergrund und bei ausgeschaltetem Bildschirm weiter. In der Benachrichtigung und auf dem Sperrbildschirm gibt es Abspielen/Pause, Stopp und Weiter/Zurück.',
    '• Bricht ein Stream ab (z. B. beim Wechsel zwischen WLAN und Mobilfunk), verbindet sich SlaxxFM automatisch neu.',
    '• Bei Anrufen pausiert die Wiedergabe, bei Navigationsansagen wird sie leiser; beim Abziehen des Kopfhörers stoppt sie.',
    '• Falls dein Handy die App trotzdem beendet (häufig bei Xiaomi, Huawei, Samsung): Einstellungen → Apps → SlaxxFM → Akku → „Nicht optimieren“ bzw. „Uneingeschränkt“.',
    '## Android Auto',
    'Im Auto findest du SlaxxFM in der Medien-Übersicht mit den Bereichen Favoriten, Zuletzt gehört und Länder. Per Sprachbefehl („Spiele Radio Paradise auf SlaxxFM“) wird gesucht und abgespielt; Weiter/Zurück wechselt den Sender.',
    '• Da SlaxxFM nicht aus dem Play Store kommt, musst du einmalig in Android Auto den Entwicklermodus aktivieren (10× auf „Version“ tippen) und dann unter Entwicklereinstellungen „Unbekannte Quellen“ einschalten.',
  ]),
  _Section(Icons.settings_rounded, 'Einstellungen', [
    '• Darstellung: Hell, Dunkel oder wie das System. Der Mond/Sonne-Knopf oben wechselt schnell.',
    '• Sprache: Deutsch, Englisch oder wie das System.',
    '• Nur Musiksender: blendet reine Nachrichten-, Talk-, Sport- und Religionssender aus (Standard: an).',
    '• Sortierung: beliebt, A–Z oder nach Bitrate.',
    '• Parallele Stream-Prüfungen: mehr = schnelleres Aufräumen, aber mehr Netzlast.',
  ]),
  _Section(Icons.build_circle_rounded, 'Probleme lösen', [
    '• Ein Sender spielt nicht: Viele Sender ändern ihre Adressen. Nutze „Aktualisieren“ und danach „Automatisch aufräumen“ für das Land.',
    '• „VPN“ an einem Sender: siehe Abschnitt VPN-Label.',
    '• Keine Senderliste: Prüfe die Internetverbindung und tippe auf Aktualisieren. Beim ersten Start sind bereits über 600 Sender eingebaut.',
    '• Linux: SlaxxFM braucht libmpv (Paket „libmpv2“ bzw. „mpv“).',
    '• Kein Logo: Nicht jeder Sender liefert ein Bild – dann zeigt SlaxxFM die Anfangsbuchstaben.',
  ]),
  _Section(Icons.info_rounded, 'Über SlaxxFM', [
    'Geschrieben von IT-Dummkopfen mit Hilfe einer KI.',
    'Quellen: radio-browser.info, github.com/deroverda/recommended-radio-streams, github.com/mikepierce/internet-radio-streams, github.com/LITUATUI/M3UPT.',
    'Der Quellcode liegt auf GitHub: github.com/IT-DUMMKOPFEN/SlaxxFM',
  ]),
];

const _en = <_Section>[
  _Section(Icons.waving_hand_rounded, 'Welcome to SlaxxFM', [
    'SlaxxFM plays free internet music radio from all over the world – sorted by country, no account needed.',
    'The station list comes from the community database radio-browser.info (about 40,000 stations) and from curated lists on GitHub.',
  ]),
  _Section(Icons.public_rounded, 'Countries and stations', [
    '• On the left (on phones: the start screen) you see all countries with their number of stations.',
    '• Click a country to see its stations as tiles.',
    '• Click a tile to play the station right away.',
    '• "Favorites" (star) and "International" are always at the top. "International" holds stations without a fixed country, e.g. from the curated lists.',
    '• Use the field above the country list to find a country.',
    '## Search',
    '• "Search stations…" searches all countries by name and genre (e.g. "jazz", "80s", "techno").',
    '• The ✕ in the search field takes you back to the selected country.',
  ]),
  _Section(Icons.play_circle_rounded, 'Playback and volume', [
    '• The player bar at the bottom has stop, previous station, play/pause, next station and favorite.',
    '• Bottom right: the volume slider (with − and +) and the mute button. Click mute again to turn the sound back on.',
    '• Previous/next switch within the list you started the station from (country, favorites or search results).',
    '• Pausing live radio: when you resume, SlaxxFM reconnects to the live stream, so you are "live" again.',
    '• On phones, tap the player bar to open the big player with all information and the visualizer.',
    '## Station information',
    'Next to the station picture you see name, country and – if the station sends it – the current song. "Details" shows language, genres, homepage, codec, bitrate, sample rate, ICY data and the stream address (click to copy).',
  ]),
  _Section(Icons.star_rounded, 'Favorites', [
    '• The star on a tile or in the player adds or removes a favorite.',
    '• Favorites are never removed by the clean-up.',
    '## Export and import',
    '• Menu (⋮) or Settings → "Export favorites (SlaxxFM)" saves a .json file with all details – perfect as a backup or for another device.',
    '• "Export as M3U playlist" creates a playlist that VLC, Winamp, Kodi etc. can play as well.',
    '• "Import favorites" reads a SlaxxFM file or any M3U playlist. Stations that are not in the list yet are added automatically.',
  ]),
  _Section(Icons.refresh_rounded, 'Updating and cleaning the station list', [
    '## Update (⟳)',
    'Downloads the complete, current station list again. This takes a few seconds depending on your connection.',
    '## Remove duplicates',
    'Finds stations with the same stream address or the same name in the same country. The best entry (with logo, more votes, higher bitrate) is kept.',
    '## Check streams',
    'Really tests every stream: does it deliver audio? Broken streams are removed.',
    '## Auto clean up (broom)',
    'Does everything in one step: remove duplicates, check all streams, remove broken ones and mark geo-blocked streams with "VPN". Choose the current country or all countries. All countries take a while – progress is shown at the top and can be cancelled.',
    '• Removed stations can be restored in the settings at any time.',
  ]),
  _Section(Icons.vpn_lock_rounded, 'The VPN label', [
    'Some stations can only be heard in their home country (geo-blocking). If a stream answers "access denied" (HTTP 401, 403 or 451), it gets the orange "VPN" label in the bottom right corner.',
    '• With a VPN service connecting to the station\'s country the stream usually works.',
    '• You can hide these stations completely in the settings.',
    '• Note: rarely a server blocks programs rather than countries – then a VPN does not help either.',
  ]),
  _Section(Icons.graphic_eq_rounded, 'Visualizer', [
    'The free space below the station information (or above the player bar) shows a visualizer that moves with the music.',
    '• Click (tap on phones) the visualizer to switch to the next effect; its name is shown briefly.',
    '• 22 effects: equalizer, rainbow equalizer, round equalizer, star flight (round spinning equalizer with stars flying towards you), sound wave, colour waves, disco lights, disco ball, fireworks, laser show, tunnel, synthwave with retro sun, VU meters, ripples, northern lights, kaleidoscope, plasma, spectrum mountains, bubbles, galaxy spiral, LED spectrum and planets.',
    '• Each effect can be switched on or off in the settings. If all are off (and the dancers too), the visualizer disappears.',
    '## Dancers',
    'While music is playing, the dance floor fills up: black silhouettes in three staggered rows in front of colourful club light. There are disco and party dancers, ballet (tutu, pointe shoes, arabesque, pirouette, grand jeté), jumps, spins and couples (swing, twirl under the arm, closed hold). The moves flow into each other on the beat and every person has their own groove. During speech (news, presenters) they take a break. The detected tempo (BPM) or "Speech" is shown in the top right corner of the visualizer.',
    '• The dancers are on by default and can be switched off in the settings.',
    '## How is it measured?',
    '• Linux: SlaxxFM measures the real loudness of the stream and detects beats, BPM and music vs. speech from it.',
    '• Android: with "Real audio analysis" the real spectrum is measured. Android requires the microphone permission for this – SlaxxFM does not record anything, it only reads its own audio output.',
    '• Windows, macOS and Android without this option: the audio engine has no measuring function there. The effects are animated musically and the tempo is estimated from the station genre (shown with "~"). Talk, news and sports stations are recognised as "speech" by their genre.',
  ]),
  _Section(Icons.phone_android_rounded, 'Android, background and Android Auto', [
    '• SlaxxFM keeps playing in the background and with the screen off. The notification and the lock screen offer play/pause, stop and next/previous.',
    '• If a stream drops (e.g. when switching between Wi-Fi and mobile data), SlaxxFM reconnects automatically.',
    '• Playback pauses during calls, gets quieter for navigation prompts and stops when you unplug your headphones.',
    '• If your phone still closes the app (common on Xiaomi, Huawei, Samsung): Settings → Apps → SlaxxFM → Battery → "Don\'t optimise" / "Unrestricted".',
    '## Android Auto',
    'In the car SlaxxFM appears in the media apps with Favorites, Recently played and Countries. Voice commands ("Play Radio Paradise on SlaxxFM") search and play; next/previous switch the station.',
    '• Because SlaxxFM does not come from the Play Store, enable developer mode in Android Auto once (tap "Version" 10 times) and then turn on "Unknown sources" in the developer settings.',
  ]),
  _Section(Icons.settings_rounded, 'Settings', [
    '• Appearance: light, dark or system. The moon/sun button at the top switches quickly.',
    '• Language: German, English or system.',
    '• Music stations only: hides pure news, talk, sports and religious stations (default: on).',
    '• Sorting: popular, A–Z or by bitrate.',
    '• Parallel stream checks: more = faster clean-up, but more network load.',
  ]),
  _Section(Icons.build_circle_rounded, 'Troubleshooting', [
    '• A station does not play: many stations change their addresses. Use "Update" and then "Auto clean up" for the country.',
    '• "VPN" on a station: see the VPN label section.',
    '• No station list: check your internet connection and press update. More than 600 stations are built in for the first start.',
    '• Linux: SlaxxFM needs libmpv (package "libmpv2" or "mpv").',
    '• No logo: not every station provides a picture – SlaxxFM then shows its initials.',
  ]),
  _Section(Icons.info_rounded, 'About SlaxxFM', [
    'Written by IT-Dummkopfen with the help of an AI.',
    'Sources: radio-browser.info, github.com/deroverda/recommended-radio-streams, github.com/mikepierce/internet-radio-streams, github.com/LITUATUI/M3UPT.',
    'Source code on GitHub: github.com/IT-DUMMKOPFEN/SlaxxFM',
  ]),
];

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final sections = settings.effectiveLanguage == 'de' ? _de : _en;
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('help')),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'de', label: Text('DE')),
                    ButtonSegment(value: 'en', label: Text('EN')),
                  ],
                  selected: {settings.effectiveLanguage},
                  onSelectionChanged: (v) => settings.setLanguage(v.first),
                ),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                itemCount: sections.length,
                itemBuilder: (context, i) {
                  final sec = sections[i];
                  return Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainer,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: i == 0,
                        leading:
                            Icon(sec.icon, color: theme.colorScheme.primary),
                        title: Text(sec.title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final l in sec.lines) _line(theme, l)],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _line(ThemeData theme, String l) {
    if (l.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(l.substring(3),
            style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
      );
    }
    if (l.startsWith('• ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('•  ',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          Expanded(
              child: Text(l.substring(2),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4))),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(l, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
    );
  }
}
