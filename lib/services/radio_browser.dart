import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/station.dart';

const String kUserAgent = 'SlaxxFM/1.0';

/// Client for the free community database https://www.radio-browser.info
class RadioBrowserApi {
  static const List<String> _fallbackServers = [
    'de2.api.radio-browser.info',
    'fi1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
    'at1.api.radio-browser.info',
    'de1.api.radio-browser.info',
  ];

  final http.Client _client = http.Client();
  List<String>? _servers;

  Map<String, String> get _headers => {'User-Agent': kUserAgent};

  Future<List<String>> _discoverServers() async {
    if (_servers != null) return _servers!;
    final found = <String>{};
    try {
      final r = await _client
          .get(Uri.https('all.api.radio-browser.info', '/json/servers'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body);
        if (list is List) {
          for (final s in list) {
            final n = (s is Map ? s['name'] : null)?.toString() ?? '';
            if (n.endsWith('radio-browser.info')) found.add(n);
          }
        }
      }
    } catch (_) {
      // ignore – fall back to the static list
    }
    final servers = found.toList()..shuffle(Random());
    for (final s in _fallbackServers) {
      if (!servers.contains(s)) servers.add(s);
    }
    _servers = servers;
    return servers;
  }

  Future<http.Response> _get(String path, Map<String, String> query) async {
    final servers = await _discoverServers();
    Object? lastError;
    for (final host in servers) {
      try {
        final r = await _client
            .get(Uri.https(host, path, query), headers: _headers)
            .timeout(const Duration(seconds: 90));
        if (r.statusCode == 200) return r;
        lastError = 'HTTP ${r.statusCode} from $host';
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('No radio-browser server reachable ($lastError)');
  }

  /// Downloads all stations that radio-browser currently considers working.
  /// [onProgress] receives the number of stations loaded so far.
  Future<List<Station>> fetchAllStations(
      {void Function(int loaded)? onProgress}) async {
    const pageSize = 10000;
    final result = <Station>[];
    var offset = 0;
    while (true) {
      final r = await _get('/json/stations', {
        'hidebroken': 'true',
        'order': 'url',
        'offset': '$offset',
        'limit': '$pageSize',
      });
      final body = utf8.decode(r.bodyBytes, allowMalformed: true);
      final page = await _parseInIsolate(body);
      result.addAll(page.stations);
      onProgress?.call(result.length);
      if (page.raw < pageSize || offset > 500000) break;
      offset += pageSize;
    }
    return result;
  }

  /// Tells radio-browser that the station was played (popularity counter).
  Future<void> countClick(String stationUuid) async {
    if (stationUuid.isEmpty || stationUuid.startsWith('cur-')) return;
    try {
      await _get('/json/url/$stationUuid', const {});
    } catch (_) {}
  }
}

Future<({int raw, List<Station> stations})> _parseInIsolate(String body) =>
    Isolate.run(() => _parseStations(body));

/// Runs in a background isolate: raw JSON -> Station objects.
({int raw, List<Station> stations}) _parseStations(String body) {
  final data = jsonDecode(body);
  final out = <Station>[];
  if (data is! List) return (raw: 0, stations: out);
  for (final e in data) {
    if (e is Map<String, dynamic>) {
      final s = Station.fromRadioBrowser(e);
      if (s != null) out.add(s);
    }
  }
  return (raw: data.length, stations: out);
}
