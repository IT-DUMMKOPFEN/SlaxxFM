import 'package:flutter_test/flutter_test.dart';
import 'package:slaxxfm/models/station.dart';
import 'package:slaxxfm/services/curated_sources.dart';
import 'package:slaxxfm/services/station_repository.dart';

void main() {
  test('M3U parser reads names, alternative urls and attributes', () {
    const text = '''#EXTM3U
# Homepage: https://example.org
#EXTINF:-1 radio="true" group-title="Rádios" tvg-logo="https://x/logo.png",Test FM
http://a.example/stream
http://b.example/stream
#EXTINF:-1,Second
https://c.example/live
''';
    final e = parseM3u(text);
    expect(e.length, 2);
    expect(e.first.name, 'Test FM');
    expect(e.first.urls.length, 2);
    expect(e.first.radio, isTrue);
    expect(e.first.logo, 'https://x/logo.png');
    expect(e.first.homepage, 'https://example.org');
  });

  test('station json round trip', () {
    final s = Station(
        id: 'x', name: 'A', url: 'http://a', tags: 'pop,rock', bitrate: 128);
    final j = Station.fromJson(s.toJson());
    expect(j.name, 'A');
    expect(j.bitrate, 128);
    expect(j.tagList, ['pop', 'rock']);
  });

  test('news-only stations are not music', () {
    expect(
        StationRepository.isNonMusic(
            Station(id: '1', name: 'N', url: 'http://n', tags: 'news,talk')),
        isTrue);
    expect(
        StationRepository.isNonMusic(
            Station(id: '2', name: 'M', url: 'http://m', tags: 'news,pop')),
        isFalse);
  });
}
