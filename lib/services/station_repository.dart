import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/station.dart';
import 'curated_sources.dart';
import 'radio_browser.dart';
import 'settings.dart';
import 'stream_tester.dart';

class CountryInfo {
  final String code;
  final String name;
  final int count;
  CountryInfo(this.code, this.name, this.count);
}

/// A long running job (update / check / clean) shown in the UI.
class BusyTask {
  final String label;
  int done = 0;
  int total = 0;
  bool cancellable;
  bool cancelled = false;
  BusyTask(this.label, {this.cancellable = false});
  double? get fraction => total > 0 ? (done / total).clamp(0.0, 1.0) : null;
}

class CleanupReport {
  int duplicates = 0;
  int checked = 0;
  int working = 0;
  int vpn = 0;
  int dead = 0;
  bool cancelled = false;
}

class StationRepository extends ChangeNotifier {
  final RadioBrowserApi api = RadioBrowserApi();
  final CuratedSources curated = CuratedSources();

  List<Station> _all = [];
  final Map<String, StreamStatus> _status = {};
  final Set<String> _removed = {};
  final Set<String> _favorites = {};
  DateTime? updatedAt;

  BusyTask? busy;
  String? lastError;

  // derived data
  List<Station> _visible = [];
  Map<String, List<Station>> _byCountry = {};
  List<CountryInfo> countries = [];

  Directory? _dir;

  final Completer<void> _ready = Completer<void>();

  /// Completes as soon as the cached (or bundled) station list is loaded.
  Future<void> get ready => _ready.future;

  int get totalCount => _all.length;
  int get visibleCount => _visible.length;
  int get removedCount => _removed.length;
  bool get isEmpty => _all.isEmpty;

  StreamStatus statusOf(Station s) => _status[s.id] ?? StreamStatus.unknown;
  bool isFavorite(Station s) => _favorites.contains(s.id);

  StationRepository() {
    settings.addListener(_rebuild);
  }

  // ---------------------------------------------------------------- storage

  Future<File> _file(String name) async {
    _dir ??= await getApplicationSupportDirectory();
    await _dir!.create(recursive: true);
    return File('${_dir!.path}${Platform.pathSeparator}$name');
  }

  Future<void> init() async {
    try {
      final f = await _file('stations.json');
      if (await f.exists()) {
        final text = await f.readAsString();
        final res = await _decodeInIsolate(text);
        _all = res.stations;
        updatedAt = res.updated;
      }
      final st = await _file('state.json');
      if (await st.exists()) {
        final j = jsonDecode(await st.readAsString()) as Map<String, dynamic>;
        final status = (j['status'] as Map?) ?? {};
        status.forEach((k, v) {
          final i = v is int ? v : 0;
          if (i > 0 && i < StreamStatus.values.length) {
            _status[k.toString()] = StreamStatus.values[i];
          }
        });
        _removed.addAll(((j['removed'] as List?) ?? []).map((e) => '$e'));
        _favorites.addAll(((j['fav'] as List?) ?? []).map((e) => '$e'));
      }
    } catch (e) {
      lastError = '$e';
    }
    if (_all.isEmpty) {
      // first start: show the curated list immediately, then update
      try {
        _all = await curated.loadBundled();
      } catch (_) {}
      _rebuild();
      if (!_ready.isCompleted) _ready.complete();
      await update();
    } else {
      _rebuild();
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _saveStations() async {
    final list = _all;
    final updated = updatedAt?.toIso8601String();
    final text = await _encodeInIsolate(list, updated);
    final f = await _file('stations.json');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }

  Future<void> _saveState() async {
    final f = await _file('state.json');
    await f.writeAsString(jsonEncode({
      'status': _status.map((k, v) => MapEntry(k, v.index)),
      'removed': _removed.toList(),
      'fav': _favorites.toList(),
    }));
  }

  // ---------------------------------------------------------------- derived

  static const _nonMusic = {
    'news', 'talk', 'sports', 'sport', 'politics', 'podcast', 'podcasts',
    'religion', 'religious', 'sermon', 'sermons', 'bible', 'quran', 'koran',
    'islam', 'islamic', 'preaching', 'spoken word', 'spoken', 'audiobook',
    'audiobooks', 'comedy', 'police', 'scanner', 'weather', 'traffic',
    'information', 'educational', 'education', 'government', 'talk radio',
    'news talk', 'news radio', 'nachrichten', 'noticias', 'notícias',
    'information radio', 'business news', 'public safety', 'aviation',
  };
  static const _musicHints = [
    'music', 'musik', 'pop', 'rock', 'jazz', 'dance', 'classic', 'hits',
    'electr', 'house', 'techno', 'hip', 'rap', 'country', 'oldies', '80',
    '90', '70', '60', '00s', 'top', 'blues', 'soul', 'funk', 'reggae',
    'metal', 'alternative', 'indie', 'chill', 'lounge', 'ambient', 'r&b',
    'rnb', 'latin', 'schlager', 'folk', 'disco', 'trance', 'edm', 'gospel',
    'worship', 'salsa', 'punk', 'soundtrack', 'charts', 'urban', 'kpop',
    'j-pop', 'opera', 'piano', 'lofi', 'lo-fi', 'world', 'volksmusik',
  ];

  static bool isNonMusic(Station s) {
    final tags = s.tagList;
    if (tags.isEmpty) return false;
    if (!tags.any(_nonMusic.contains)) return false;
    final hasMusic = tags.any((t) => _musicHints.any(t.contains));
    return !hasMusic;
  }

  bool _isVisible(Station s) {
    if (_removed.contains(s.id) && !_favorites.contains(s.id)) return false;
    if (settings.musicOnly && isNonMusic(s)) return false;
    if (settings.hideVpn && _status[s.id] == StreamStatus.vpn) return false;
    return true;
  }

  void _rebuild() {
    _visible = _all.where(_isVisible).toList();
    final by = <String, List<Station>>{};
    final names = <String, Map<String, int>>{};
    for (final s in _visible) {
      by.putIfAbsent(s.countryCode, () => []).add(s);
      if (s.country.isNotEmpty) {
        final m = names.putIfAbsent(s.countryCode, () => {});
        m[s.country] = (m[s.country] ?? 0) + 1;
      }
    }
    for (final l in by.values) {
      _sort(l);
    }
    _byCountry = by;
    final list = <CountryInfo>[];
    by.forEach((code, l) {
      if (code == kIntlCode) return;
      final m = names[code];
      var name = code;
      if (m != null && m.isNotEmpty) {
        name = m.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      }
      list.add(CountryInfo(code, name, l.length));
    });
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final intl = by[kIntlCode];
    if (intl != null) list.insert(0, CountryInfo(kIntlCode, '', intl.length));
    final favCount = _all.where((s) => _favorites.contains(s.id)).length;
    list.insert(0, CountryInfo(kFavCode, '', favCount));
    countries = list;
    notifyListeners();
  }

  /// Sorts by the chosen mode; ties are always broken by name (A–Z) so
  /// every list is in a stable, predictable order.
  void _sort(List<Station> l) {
    int byName(Station a, Station b) =>
        _nameKey(a.name).compareTo(_nameKey(b.name));
    switch (settings.sort) {
      case SortMode.popular:
        l.sort((a, b) {
          final c = (b.votes + b.clicks).compareTo(a.votes + a.clicks);
          return c != 0 ? c : byName(a, b);
        });
      case SortMode.name:
        l.sort(byName);
      case SortMode.bitrate:
        l.sort((a, b) {
          final c = b.bitrate.compareTo(a.bitrate);
          return c != 0 ? c : byName(a, b);
        });
    }
  }

  /// Name key for sorting: case-insensitive, umlauts folded, leading
  /// punctuation/spaces ignored.
  static final Map<String, String> _keyCache = {};
  static String _nameKey(String n) =>
      _keyCache[n] ??= _makeNameKey(n);
  static String _makeNameKey(String n) {
    var s = n.toLowerCase().trim();
    const m = {'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss', 'é': 'e', 'è': 'e',
      'á': 'a', 'à': 'a', 'ó': 'o', 'ò': 'o', 'í': 'i', 'ú': 'u', 'ñ': 'n', 'ç': 'c'};
    s = s.split('').map((c) => m[c] ?? c).join();
    return s.replaceFirst(RegExp(r'^[^a-z0-9]+'), '');
  }

  List<Station> stationsOf(String code) {
    if (code == kFavCode) {
      final l = _all.where((s) => _favorites.contains(s.id)).toList();
      _sort(l);
      return l;
    }
    return _byCountry[code] ?? const [];
  }

  List<Station> search(String query, {String? countryCode}) {
    final q = query.trim().toLowerCase();
    final base = countryCode == null ? _visible : stationsOf(countryCode);
    if (q.isEmpty) return base;
    final res = base
        .where((s) =>
            s.name.toLowerCase().contains(q) || s.tags.contains(q))
        .toList();
    if (countryCode == null) _sort(res);
    return res.length > 1000 ? res.sublist(0, 1000) : res;
  }

  Station? byId(String id) {
    for (final s in _all) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------- actions

  void _startBusy(BusyTask t) {
    busy = t;
    lastError = null;
    notifyListeners();
  }

  void _endBusy() {
    busy = null;
    notifyListeners();
  }

  void cancelBusy() {
    busy?.cancelled = true;
    notifyListeners();
  }

  /// Downloads the full station list (radio-browser + curated GitHub lists).
  Future<bool> update() async {
    if (busy != null) return false;
    final task = BusyTask('update');
    _startBusy(task);
    try {
      final rb = await api.fetchAllStations(onProgress: (n) {
        task.done = n;
        notifyListeners();
      });
      final cur = await curated.fetchLive();
      final seen = <String>{};
      final merged = <Station>[];
      for (final s in [...rb, ...cur]) {
        if (s.id.isEmpty || !seen.add(s.id)) continue;
        merged.add(s);
      }
      if (merged.length < 100) {
        throw Exception('Received only ${merged.length} stations');
      }
      _all = merged;
      updatedAt = DateTime.now();
      // forget states of stations that no longer exist
      _status.removeWhere((k, _) => !seen.contains(k));
      _removed.removeWhere((k) => !seen.contains(k));
      _rebuild();
      await _saveStations();
      await _saveState();
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    } finally {
      _endBusy();
    }
  }

  static String _normUrl(String u) {
    var x = u.trim().toLowerCase();
    x = x.replaceFirst(RegExp(r'^https?://'), '');
    x = x.replaceFirst(RegExp(r'^www\.'), '');
    x = x.replaceFirst(RegExp(r':(80|443)(?=/|$)'), '');
    x = x.replaceFirst(RegExp(r'[/;?]+$'), '');
    x = x.replaceAll('/;', '');
    return x;
  }

  static final _nonAlnum = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static String _normName(String n) => n.toLowerCase().replaceAll(_nonAlnum, '');

  int _score(Station s) {
    var sc = 0;
    if (_favorites.contains(s.id)) sc += 1000000;
    switch (_status[s.id]) {
      case StreamStatus.ok:
        sc += 10000;
      case StreamStatus.vpn:
        sc += 2000;
      case StreamStatus.dead:
        sc -= 10000;
      default:
        break;
    }
    if (s.countryCode != kIntlCode) sc += 500;
    if (s.logo.isNotEmpty) sc += 300;
    if (s.source == 'rb') sc += 100;
    sc += s.votes.clamp(0, 2000) ~/ 2;
    sc += s.bitrate.clamp(0, 320) ~/ 4;
    return sc;
  }

  /// Removes duplicate stations (same stream URL, or same name in the same
  /// country). The best entry of each group is kept.
  int removeDuplicates({String? countryCode}) {
    final list = countryCode == null || countryCode == kFavCode
        ? _visible
        : stationsOf(countryCode);
    final parent = List<int>.generate(list.length, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    void union(int a, int b) {
      final ra = find(a), rb = find(b);
      if (ra != rb) parent[rb] = ra;
    }

    final byUrl = <String, int>{};
    final byName = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      final u = _normUrl(s.url);
      final prevU = byUrl[u];
      if (prevU != null) {
        union(prevU, i);
      } else {
        byUrl[u] = i;
      }
      final n = _normName(s.name);
      if (n.length >= 3) {
        final key = '${s.countryCode}|$n';
        final prevN = byName[key];
        if (prevN != null) {
          union(prevN, i);
        } else {
          byName[key] = i;
        }
      }
    }
    final groups = <int, List<int>>{};
    for (var i = 0; i < list.length; i++) {
      groups.putIfAbsent(find(i), () => []).add(i);
    }
    var removed = 0;
    for (final g in groups.values) {
      if (g.length < 2) continue;
      g.sort((a, b) => _score(list[b]).compareTo(_score(list[a])));
      for (final i in g.skip(1)) {
        final s = list[i];
        if (_favorites.contains(s.id)) continue;
        if (_removed.add(s.id)) removed++;
      }
    }
    if (removed > 0) {
      _rebuild();
      _saveState();
    }
    return removed;
  }

  /// Tests every stream (of one country or of all) and optionally removes
  /// the ones that do not work. Streams that are geo-blocked get the
  /// VPN label.
  Future<CleanupReport> checkStreams(
      {String? countryCode, bool removeDead = true, BusyTask? task}) async {
    final report = CleanupReport();
    if (busy != null && busy != task) return report..cancelled = true;
    final own = task == null;
    final t = task ?? BusyTask('check', cancellable: true);
    if (own) _startBusy(t);
    final list = List<Station>.of(countryCode == null
        ? _visible
        : stationsOf(countryCode));
    t.total = list.length;
    t.done = 0;
    notifyListeners();
    var lastNotify = DateTime.now();
    var stationsChanged = false;
    try {
      await checkMany(
        list,
        tester: StreamTester(),
        parallel: settings.parallelChecks.clamp(1, 64),
        cancelled: () => t.cancelled,
        onResult: (s, r) {
          report.checked++;
          t.done++;
          _status[s.id] = r.status;
          switch (r.status) {
            case StreamStatus.ok:
              report.working++;
              if (r.workingUrl != null && r.workingUrl != s.url) {
                s.url = r.workingUrl!;
                stationsChanged = true;
              }
            case StreamStatus.vpn:
              report.vpn++;
            case StreamStatus.dead:
              report.dead++;
              if (removeDead && !_favorites.contains(s.id)) _removed.add(s.id);
            case StreamStatus.unknown:
              break;
          }
          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds > 300) {
            lastNotify = now;
            notifyListeners();
          }
        },
      );
      report.cancelled = t.cancelled;
      _rebuild();
      await _saveState();
      if (stationsChanged) await _saveStations();
    } catch (e) {
      lastError = '$e';
    } finally {
      if (own) _endBusy();
    }
    return report;
  }

  /// One-click clean up: remove duplicates, test all streams, remove dead
  /// streams and label geo-blocked ones with "VPN".
  Future<CleanupReport> autoClean({String? countryCode}) async {
    if (busy != null) return CleanupReport()..cancelled = true;
    final t = BusyTask('clean', cancellable: true);
    _startBusy(t);
    try {
      final dups = removeDuplicates(countryCode: countryCode);
      final r = await checkStreams(
          countryCode: countryCode, removeDead: true, task: t);
      r.duplicates = dups;
      // a second pass catches duplicates whose better copy just died
      if (!r.cancelled) r.duplicates += removeDuplicates(countryCode: countryCode);
      return r;
    } finally {
      _endBusy();
    }
  }

  void setStatus(Station s, StreamStatus st) {
    if (_status[s.id] == st) return;
    _status[s.id] = st;
    _saveState();
    notifyListeners();
  }

  void toggleFavorite(Station s) {
    if (!_favorites.remove(s.id)) _favorites.add(s.id);
    _saveState();
    _rebuild();
  }

  /// Adds [list] to the favourites. Stations that are not in the list yet
  /// (e.g. from another device) are added. Returns the number imported.
  Future<int> importFavorites(List<Station> list) async {
    final byId = {for (final s in _all) s.id: s};
    final byUrl = {for (final s in _all) _normUrl(s.url): s};
    var added = false;
    var count = 0;
    for (final s in list) {
      final existing = byId[s.id] ?? byUrl[_normUrl(s.url)];
      final target = existing ?? s;
      if (existing == null) {
        _all.add(s);
        byId[s.id] = s;
        byUrl[_normUrl(s.url)] = s;
        added = true;
      }
      _removed.remove(target.id);
      if (_favorites.add(target.id)) count++;
    }
    _rebuild();
    await _saveState();
    if (added) await _saveStations();
    return count;
  }

  Future<void> restoreRemoved() async {
    _removed.clear();
    _status.removeWhere((_, v) => v == StreamStatus.dead);
    _rebuild();
    await _saveState();
  }
}

// Top-level helpers so the isolate closures never capture `this`.
Future<({DateTime? updated, List<Station> stations})> _decodeInIsolate(
        String text) =>
    Isolate.run(() => _decodeCache(text));

Future<String> _encodeInIsolate(List<Station> list, String? updated) =>
    Isolate.run(() => jsonEncode({
          'updated': updated,
          'stations': list.map((s) => s.toJson()).toList(),
        }));

({DateTime? updated, List<Station> stations}) _decodeCache(String text) {
  final j = jsonDecode(text) as Map<String, dynamic>;
  final list = (j['stations'] as List)
      .whereType<Map<String, dynamic>>()
      .map(Station.fromJson)
      .where((s) => s.id.isNotEmpty && s.url.isNotEmpty)
      .toList();
  final u = j['updated'];
  return (updated: u is String ? DateTime.tryParse(u) : null, stations: list);
}

final repo = StationRepository();
