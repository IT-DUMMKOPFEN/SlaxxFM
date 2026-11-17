import 'dart:convert';

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/station.dart';
import 'radio_browser.dart' show kUserAgent;

/// Hand-curated GitHub station lists (suggested by the user):
///  * github.com/deroverda/recommended-radio-streams (playlists/*.m3u)
///  * github.com/mikepierce/internet-radio-streams (*.m3u)
///  * github.com/LITUATUI/M3UPT (radio entries of M3U/M3UPT.m3u)
///
/// A snapshot is bundled in assets/curated_stations.json. On "Update"
/// the lists are fetched live from GitHub; if that fails the snapshot is used.
/// Same id scheme as tool/build_curated.py so snapshot and live data match.
String curatedId(String url) =>
    'cur-${sha1.convert(utf8.encode(url)).toString().substring(0, 16)}';

class CuratedSources {
  static const _deroverdaFiles = [
    'ambient-lo-fi-chill',
    'campus-public-radio',
    'christmas-holiday',
    'classical-opera',
    'decades-oldies-nostalgia',
    'electronic',
    'funk-soul-hip-hop-disco',
    'global-independent-online-communities',
    'jazz-blues',
    'metal-heavy',
    'reggae-dub',
    'rock-indie-alternative-country-folk',
    'video-game-chiptune-soundtracks',
    'world-regional',
  ];

  /// Country of the broadcasters in mikepierce/internet-radio-streams.
  static const Map<String, String> _mikePierceCountry = {
    '313.FM': 'US', '9128.live': 'GB', 'AM-Ambient': 'US',
    'AfterhoursFM': 'NL', 'AmbientSleepingPill': 'US',
    'BBC-Radio-Stations': 'GB', 'BBC-WorldService': 'GB', 'BadRadio': 'US',
    'Bluemars-Cryosleep': 'CH', 'Bluemars-VoicesFromWithin': 'CH',
    'Bluemars': 'CH', 'CashmereRadio': 'DE', 'DandelionRadio': 'GB',
    'DarkAmbientRadio': 'US', 'DialRadio': 'DE', 'DoYouRadio': 'IT',
    'Dogglounge': 'US', 'Doubleclap': 'DE', 'Dublab': 'US',
    'FIP-Stations': 'FR', 'Frisky-Chill': 'US', 'Frisky-Deep': 'US',
    'Frisky': 'US', 'Hirschmilch-Stations': 'DE',
    'IntergalacticFM-Stations': 'NL', 'KAFM-WesternCO-Public': 'US',
    'KALX-Berkeley': 'US', 'KCHUNG': 'US', 'KEXP-Seattle': 'US',
    'KPISS': 'US', 'KSPC-Claremont': 'US', 'KXLU-SoCalLoyolaMarymount': 'US',
    'KioskRadio': 'BE', 'LeMellotron': 'FR', 'NASA-ThirdRockRadio': 'US',
    'NTS1': 'GB', 'NTS2': 'GB', 'Nectarine': 'FR', 'NewtownRadio': 'US',
    'Noods-Radio': 'GB', 'RadioCaroline': 'GB', 'RadioParadise-Global': 'US',
    'RadioParadise-MainMix': 'US', 'RadioRivendell': 'SE', 'Radiomeuh': 'FR',
    'RinseFM': 'GB', 'SanctuaryRadio': 'GB', 'ShonenBeachFM': 'JP',
    'Slay-Radio': 'SE', 'SleepbotEnvironmental': 'US', 'SohoRadio': 'GB',
    'SomaFM-DeepSpaceOne': 'US', 'SomaFM-DroneZone': 'US',
    'SomaFM-GrooveSalad': 'US', 'SomaFM-Lush': 'US', 'SomaFM-SF10-33': 'US',
    'SomaFM-SpaceStation': 'US', 'Subcity': 'GB',
    'SyntheticFM-NewItaloDisco': 'DE', 'SyntheticFM-Synth': 'DE',
    'TheLotRadio': 'US', 'WFMU-Jersey-City': 'US', 'WorldwideFM': 'GB',
  };

  final http.Client _client = http.Client();

  Future<List<Station>> loadBundled() async {
    final raw = await rootBundle.loadString('assets/curated_stations.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return (data['stations'] as List)
        .whereType<Map<String, dynamic>>()
        .map(Station.fromJson)
        .where((s) => s.url.isNotEmpty)
        .toList();
  }

  Future<String?> _text(String url) async {
    try {
      final r = await _client.get(Uri.parse(url), headers: {
        'User-Agent': kUserAgent
      }).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      return utf8.decode(r.bodyBytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  /// Fetches all curated lists live. Falls back to the bundled snapshot
  /// for every list that cannot be downloaded.
  Future<List<Station>> fetchLive() async {
    final out = <Station>[];
    var anyFailed = false;

    // deroverda
    const dBase =
        'https://raw.githubusercontent.com/deroverda/recommended-radio-streams/main/playlists/';
    final dTexts =
        await Future.wait(_deroverdaFiles.map((f) => _text('$dBase$f.m3u')));
    for (final t in dTexts) {
      if (t == null) {
        anyFailed = true;
        continue;
      }
      for (final e in parseM3u(t)) {
        out.add(_make(e, kIntlCode, 'International', e.group));
      }
    }

    // mikepierce – file list via GitHub API
    final listing = await _text(
        'https://api.github.com/repos/mikepierce/internet-radio-streams/contents/');
    if (listing == null) {
      anyFailed = true;
    } else {
      try {
        final files = (jsonDecode(listing) as List)
            .whereType<Map<String, dynamic>>()
            .where((f) => (f['name'] as String).endsWith('.m3u'))
            .toList();
        final texts = await Future.wait(
            files.map((f) => _text(f['download_url'] as String)));
        for (var i = 0; i < files.length; i++) {
          final t = texts[i];
          if (t == null) continue;
          final base = (files[i]['name'] as String).replaceAll('.m3u', '');
          final cc = _mikePierceCountry[base] ?? kIntlCode;
          for (final e in parseM3u(t)) {
            final name = e.name.isEmpty ? base.replaceAll('-', ' ') : e.name;
            out.add(_make(e.copyWith(name: name), cc, '', e.genre));
          }
        }
      } catch (_) {
        anyFailed = true;
      }
    }

    // M3UPT (Portugal) – only entries flagged radio="true"
    final pt = await _text(
        'https://raw.githubusercontent.com/LITUATUI/M3UPT/main/M3U/M3UPT.m3u');
    if (pt == null) {
      anyFailed = true;
    } else {
      for (final e in parseM3u(pt).where((e) => e.radio)) {
        out.add(_make(e, 'PT', 'Portugal', ''));
      }
    }

    if (anyFailed || out.isEmpty) {
      // merge with bundled snapshot so nothing gets lost
      final ids = out.map((s) => s.id).toSet();
      for (final s in await loadBundled()) {
        if (!ids.contains(s.id)) out.add(s);
      }
    }
    return out;
  }

  Station _make(M3uEntry e, String cc, String country, String tags) {
    return Station(
      id: curatedId(e.urls.first),
      name: e.name,
      url: e.urls.first,
      altUrls: e.urls.skip(1).toList(),
      homepage: e.homepage,
      logo: e.logo,
      countryCode: cc,
      country: country,
      tags: Station.normTags(tags.replaceAll('&', ',')),
      source: 'cur',
      userAgent: e.userAgent,
    );
  }
}

class M3uEntry {
  final String name;
  final List<String> urls;
  final String homepage;
  final String logo;
  final String group;
  final String genre;
  final bool radio;
  final String userAgent;

  M3uEntry({
    required this.name,
    required this.urls,
    this.homepage = '',
    this.logo = '',
    this.group = '',
    this.genre = '',
    this.radio = false,
    this.userAgent = '',
  });

  M3uEntry copyWith({String? name}) => M3uEntry(
        name: name ?? this.name,
        urls: urls,
        homepage: homepage,
        logo: logo,
        group: group,
        genre: genre,
        radio: radio,
        userAgent: userAgent,
      );
}

final _attrRe = RegExp(r'([\w-]+)="([^"]*)"');

/// Small M3U/EXTM3U parser. Several URL lines after one #EXTINF are
/// treated as alternative streams of the same station.
List<M3uEntry> parseM3u(String text) {
  final out = <_Builder>[];
  _Builder? cur;
  String? home;
  String? group;
  for (var line in const LineSplitter().convert(text)) {
    line = line.replaceAll('﻿', '').trim();
    if (line.isEmpty) continue;
    if (line.startsWith('# Group:')) {
      group = line.substring(8).trim();
    } else if (line.startsWith('# Homepage:')) {
      home = line.substring(11).trim();
    } else if (line.startsWith('#EXTINF')) {
      final attrs = <String, String>{
        for (final m in _attrRe.allMatches(line)) m.group(1)!: m.group(2)!
      };
      final comma = line.lastIndexOf(',');
      final name = comma >= 0 ? line.substring(comma + 1).trim() : '';
      cur = _Builder()
        ..name = name
        ..homepage = home ?? ''
        ..logo = attrs['tvg-logo'] ?? ''
        ..group = attrs['group-title'] ?? group ?? ''
        ..radio = attrs['radio'] == 'true';
      out.add(cur);
      home = null;
    } else if (line.startsWith('#EXTGENRE:')) {
      cur?.genre = line.substring(10).trim();
    } else if (line.startsWith('#EXTVLCOPT:http-user-agent=')) {
      cur?.userAgent = line.split('=').skip(1).join('=').replaceAll('"', '');
    } else if (line.startsWith('#')) {
      continue;
    } else if (line.startsWith('http://') || line.startsWith('https://')) {
      cur?.urls.add(line);
    }
  }
  return out
      .where((b) => b.urls.isNotEmpty)
      .map((b) => M3uEntry(
            name: b.name,
            urls: b.urls,
            homepage: b.homepage,
            logo: b.logo,
            group: b.group,
            genre: b.genre,
            radio: b.radio,
            userAgent: b.userAgent,
          ))
      .toList();
}

class _Builder {
  String name = '';
  final List<String> urls = [];
  String homepage = '';
  String logo = '';
  String group = '';
  String genre = '';
  bool radio = false;
  String userAgent = '';
}
