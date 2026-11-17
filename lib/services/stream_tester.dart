import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/station.dart';

/// Browser-like UA: old SHOUTcast servers answer "ICY 200 OK" otherwise.
const String kStreamUserAgent = 'Mozilla/5.0 (compatible; SlaxxFM/1.0)';

class StreamCheckResult {
  final StreamStatus status;

  /// The URL that worked (may be an alternative URL of the station).
  final String? workingUrl;
  final String detail;
  StreamCheckResult(this.status, {this.workingUrl, this.detail = ''});
}

/// Checks whether a stream URL really delivers audio.
///
/// * 2xx with audio / playlist data      -> ok
/// * 401 / 403 / 451 (geo blocking)      -> vpn  (probably needs a VPN)
/// * everything else / timeout           -> dead
class StreamTester {
  final Duration timeout;
  StreamTester({this.timeout = const Duration(seconds: 10)});

  HttpClient _newClient() {
    final c = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = const Duration(seconds: 2)
      ..userAgent = kStreamUserAgent
      // The player (mpv) does not verify certificates either, so a
      // station with an expired certificate still plays.
      ..badCertificateCallback = (cert, host, port) => true;
    return c;
  }

  Future<StreamCheckResult> check(Station s) async {
    final urls = <String>[s.url, ...s.altUrls];
    StreamCheckResult? best;
    for (final u in urls) {
      final r = await _checkUrl(u, s.userAgent, 0);
      if (r.status == StreamStatus.ok) {
        return StreamCheckResult(StreamStatus.ok, workingUrl: u);
      }
      if (best == null ||
          (r.status == StreamStatus.vpn && best.status == StreamStatus.dead)) {
        best = r;
      }
    }
    return best ?? StreamCheckResult(StreamStatus.dead, detail: 'no url');
  }

  Future<StreamCheckResult> _checkUrl(String url, String ua, int depth) async {
    final client = _newClient();
    try {
      return await _run(client, url, ua, depth).timeout(timeout * 2,
          onTimeout: () =>
              StreamCheckResult(StreamStatus.dead, detail: 'timeout'));
    } on HttpException catch (e) {
      // SHOUTcast v1 answers "ICY 200 OK", which is not valid HTTP but a
      // working stream.
      final m = e.message.toLowerCase();
      if (m.contains('http version') || m.contains('response line')) {
        return StreamCheckResult(StreamStatus.ok, detail: 'icy');
      }
      return StreamCheckResult(StreamStatus.dead, detail: e.message);
    } catch (e) {
      return StreamCheckResult(StreamStatus.dead, detail: e.toString());
    } finally {
      client.close(force: true);
    }
  }

  Future<StreamCheckResult> _run(
      HttpClient client, String url, String ua, int depth) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return StreamCheckResult(StreamStatus.dead, detail: 'bad url');
    }
    final req = await client.getUrl(uri).timeout(timeout);
    if (ua.isNotEmpty) req.headers.set(HttpHeaders.userAgentHeader, ua);
    req.headers.set('Icy-MetaData', '0');
    req.followRedirects = true;
    req.maxRedirects = 8;
    final resp = await req.close().timeout(timeout);
    final code = resp.statusCode;
    if (code == 401 || code == 403 || code == 451) {
      return StreamCheckResult(StreamStatus.vpn, detail: 'HTTP $code');
    }
    if (code < 200 || code >= 300) {
      return StreamCheckResult(StreamStatus.dead, detail: 'HTTP $code');
    }
    final type = resp.headers.contentType?.mimeType.toLowerCase() ?? '';

    // read the first bytes of the stream
    final bytes = <int>[];
    final completer = Completer<void>();
    late StreamSubscription<List<int>> sub;
    sub = resp.listen((chunk) {
      bytes.addAll(chunk);
      if (bytes.length >= 4096 && !completer.isCompleted) completer.complete();
    }, onDone: () {
      if (!completer.isCompleted) completer.complete();
    }, onError: (_) {
      if (!completer.isCompleted) completer.complete();
    }, cancelOnError: true);
    await completer.future.timeout(timeout, onTimeout: () {});
    await sub.cancel();

    if (bytes.isEmpty) {
      return StreamCheckResult(StreamStatus.dead, detail: 'no data');
    }
    final head = latin1.decode(bytes.take(2048).toList()).trimLeft();
    final lower = head.toLowerCase();

    // HLS playlist
    if (lower.startsWith('#extm3u') && head.contains('#EXT-X-')) {
      return StreamCheckResult(StreamStatus.ok);
    }
    // plain playlists (m3u / pls) -> follow the first entry once
    final isPlaylist = lower.startsWith('#extm3u') ||
        lower.startsWith('[playlist]') ||
        type.contains('mpegurl') ||
        type.contains('scpls') ||
        (type.startsWith('text/') && lower.startsWith('http'));
    if (isPlaylist) {
      if (depth >= 2) return StreamCheckResult(StreamStatus.dead);
      final next = _firstUrl(head);
      if (next == null) {
        return StreamCheckResult(StreamStatus.dead, detail: 'empty playlist');
      }
      return _run(client, next, ua, depth + 1);
    }
    // HTML page instead of a stream
    if (type.contains('html') ||
        lower.startsWith('<!doctype') ||
        lower.startsWith('<html')) {
      return StreamCheckResult(StreamStatus.dead, detail: 'html page');
    }
    return StreamCheckResult(StreamStatus.ok);
  }

  String? _firstUrl(String text) {
    for (var line in const LineSplitter().convert(text)) {
      line = line.trim();
      final eq = line.indexOf('=');
      if (line.toLowerCase().startsWith('file') && eq > 0) {
        line = line.substring(eq + 1).trim();
      }
      if (line.startsWith('http://') || line.startsWith('https://')) {
        return line;
      }
    }
    return null;
  }
}

/// Runs [tester] over [stations] with limited parallelism.
Future<void> checkMany(
  List<Station> stations, {
  required StreamTester tester,
  int parallel = 16,
  required bool Function() cancelled,
  required void Function(Station s, StreamCheckResult r) onResult,
}) async {
  var index = 0;
  Future<void> worker() async {
    while (!cancelled()) {
      if (index >= stations.length) return;
      final s = stations[index++];
      final r = await tester.check(s);
      if (cancelled()) return;
      onResult(s, r);
    }
  }

  await Future.wait(List.generate(parallel, (_) => worker()));
}
