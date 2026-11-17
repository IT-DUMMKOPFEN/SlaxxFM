/// Health state of a stream, determined by the built-in stream check.
enum StreamStatus { unknown, ok, vpn, dead }

/// Pseudo country codes used inside the app.
const String kIntlCode = 'ZZ';
const String kFavCode = '*FAV';

class Station {
  final String id;
  final String name;
  String url;
  final List<String> altUrls;
  final String homepage;
  final String logo;
  final String countryCode;
  final String country;
  final String language;
  final String tags;
  final String codec;
  final int bitrate;
  final int votes;
  final int clicks;
  final bool hls;

  /// 'rb' = radio-browser.info, 'cur' = curated GitHub lists
  final String source;

  /// Optional HTTP user agent required by some streams.
  final String userAgent;

  Station({
    required this.id,
    required this.name,
    required this.url,
    this.altUrls = const [],
    this.homepage = '',
    this.logo = '',
    this.countryCode = kIntlCode,
    this.country = '',
    this.language = '',
    this.tags = '',
    this.codec = '',
    this.bitrate = 0,
    this.votes = 0,
    this.clicks = 0,
    this.hls = false,
    this.source = 'rb',
    this.userAgent = '',
  });

  List<String> get tagList => tags
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  /// Compact JSON used for the local cache.
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'id': id, 'name': name, 'url': url};
    void put(String k, Object? v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      if (v is int && v == 0) return;
      if (v is bool && !v) return;
      if (v is List && v.isEmpty) return;
      m[k] = v;
    }

    put('alt', altUrls);
    put('home', homepage);
    put('logo', logo);
    put('cc', countryCode);
    put('country', country);
    put('lang', language);
    put('tags', tags);
    put('codec', codec);
    put('br', bitrate);
    put('votes', votes);
    put('clicks', clicks);
    put('hls', hls);
    put('src', source);
    put('ua', userAgent);
    return m;
  }

  static int _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static String _str(Object? v) => v == null ? '' : v.toString().trim();

  factory Station.fromJson(Map<String, dynamic> j) {
    final alt = j['alt'];
    final cc = _str(j['cc']).toUpperCase();
    return Station(
      id: _str(j['id']),
      name: _str(j['name']),
      url: _str(j['url']),
      altUrls: alt is List ? alt.map((e) => e.toString()).toList() : const [],
      homepage: _str(j['home']),
      logo: _str(j['logo']),
      countryCode: cc.isEmpty ? kIntlCode : cc,
      country: _str(j['country']),
      language: _str(j['lang']),
      tags: normTags(_str(j['tags'])),
      codec: _str(j['codec']),
      bitrate: _int(j['br']),
      votes: _int(j['votes']),
      clicks: _int(j['clicks']),
      hls: j['hls'] == true,
      source: _str(j['src']).isEmpty ? 'rb' : _str(j['src']),
      userAgent: _str(j['ua']),
    );
  }

  /// Converts a raw radio-browser.info station object.
  static Station? fromRadioBrowser(Map<String, dynamic> j) {
    final url = _str(j['url_resolved']).isNotEmpty
        ? _str(j['url_resolved'])
        : _str(j['url']);
    final name = _str(j['name']);
    if (url.isEmpty || name.isEmpty) return null;
    if (!url.startsWith('http')) return null;
    final cc = _str(j['countrycode']).toUpperCase();
    final alt = <String>[];
    final orig = _str(j['url']);
    if (orig.isNotEmpty && orig != url && orig.startsWith('http')) alt.add(orig);
    return Station(
      id: _str(j['stationuuid']),
      name: name,
      url: url,
      altUrls: alt,
      homepage: _str(j['homepage']),
      logo: _str(j['favicon']),
      countryCode: cc.length == 2 ? cc : kIntlCode,
      country: _str(j['country']),
      language: _str(j['language']),
      tags: normTags(_str(j['tags'])),
      codec: _str(j['codec']),
      bitrate: _int(j['bitrate']),
      votes: _int(j['votes']),
      clicks: _int(j['clickcount']),
      hls: _int(j['hls']) == 1 || j['hls'] == true,
      source: 'rb',
    );
  }

  static String normTags(String t) => t
      .split(RegExp(r'[,;]'))
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet()
      .join(',');
}
