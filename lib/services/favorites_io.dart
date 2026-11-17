import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../l10n.dart';
import '../models/station.dart';
import '../ui/settings_page.dart' show kAppVersion;
import '../ui/widgets/country_list.dart' show countryLabelForCode;
import 'curated_sources.dart';
import 'station_repository.dart';

/// Export / import of the favourites as SlaxxFM JSON or M3U playlist.
class FavoritesIO {
  /// Returns a message for the user (null = cancelled).
  static Future<String?> export({required bool m3u}) async {
    final favs = repo.stationsOf(kFavCode);
    if (favs.isEmpty) return tr('noFavorites');
    final String text;
    if (m3u) {
      final b = StringBuffer('#EXTM3U\n');
      for (final s in favs) {
        final logo = s.logo.isEmpty ? '' : ' tvg-logo="${s.logo}"';
        final group = countryLabelForCode(s.countryCode).replaceAll('"', "'");
        b
          ..writeln('#EXTINF:-1$logo group-title="$group",${s.name}')
          ..writeln(s.url);
      }
      text = b.toString();
    } else {
      text = const JsonEncoder.withIndent('  ').convert({
        'app': 'SlaxxFM',
        'version': kAppVersion,
        'exported': DateTime.now().toIso8601String(),
        'favorites': favs.map((s) => s.toJson()).toList(),
      });
    }
    final bytes = Uint8List.fromList(utf8.encode(text));
    final name = m3u ? 'SlaxxFM-Favoriten.m3u' : 'SlaxxFM-Favoriten.json';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: tr(m3u ? 'exportFavM3u' : 'exportFav'),
        fileName: name,
        type: FileType.custom,
        allowedExtensions: [m3u ? 'm3u' : 'json'],
        bytes: bytes,
      );
      if (path == null) return null;
      // desktop: the picker only returns the path
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      return tr('exported', {'n': favs.length});
    } catch (e) {
      return '${tr('exportFailed')}: $e';
    }
  }

  static Future<String?> import() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        dialogTitle: tr('importFav'),
        type: Platform.isAndroid ? FileType.any : FileType.custom,
        allowedExtensions:
            Platform.isAndroid ? null : ['json', 'm3u', 'm3u8', 'txt'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return null;
      final f = res.files.first;
      var bytes = f.bytes;
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null) return tr('importFailed');
      final text = utf8.decode(bytes, allowMalformed: true);
      final stations = parse(text);
      if (stations.isEmpty) return tr('importNothing');
      final n = await repo.importFavorites(stations);
      return tr('imported', {'n': n});
    } catch (e) {
      return '${tr('importFailed')}: $e';
    }
  }

  /// SlaxxFM JSON, a plain JSON list of stations, or an M3U playlist.
  static List<Station> parse(String text) {
    final t = text.trimLeft();
    if (t.startsWith('{') || t.startsWith('[')) {
      final data = jsonDecode(t);
      final list = data is Map ? data['favorites'] : data;
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((m) => Station.fromJson(Map<String, dynamic>.from(m)))
          .where((s) => s.url.startsWith('http'))
          .map((s) => s.id.isEmpty ? _withId(s) : s)
          .toList();
    }
    return parseM3u(text).map((e) {
      final cc = _countryCode(e.group);
      return Station(
        id: curatedId(e.urls.first),
        name: e.name.isEmpty ? e.urls.first : e.name,
        url: e.urls.first,
        altUrls: e.urls.skip(1).toList(),
        logo: e.logo,
        countryCode: cc,
        source: 'cur',
        userAgent: e.userAgent,
      );
    }).toList();
  }

  static Station _withId(Station s) => Station.fromJson(
      {...s.toJson(), 'id': curatedId(s.url), 'src': 'cur'});

  /// group-title may hold a country name ("Germany") or code ("DE").
  static String _countryCode(String group) {
    final g = group.trim();
    if (g.isEmpty) return kIntlCode;
    for (final c in repo.countries) {
      if (c.code.toLowerCase() == g.toLowerCase() ||
          c.name.toLowerCase() == g.toLowerCase() ||
          countryLabelForCode(c.code).toLowerCase() == g.toLowerCase()) {
        return c.code == kFavCode ? kIntlCode : c.code;
      }
    }
    return kIntlCode;
  }
}
