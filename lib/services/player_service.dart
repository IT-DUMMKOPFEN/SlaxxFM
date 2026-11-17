import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../models/station.dart';
import 'station_repository.dart';
import 'settings.dart';
import 'stream_tester.dart' show kStreamUserAgent;

/// Thin wrapper around media_kit (libmpv) for radio playback.
class PlayerService extends ChangeNotifier {
  late final Player _player;
  final List<StreamSubscription> _subs = [];
  Timer? _metaTimer;

  Station? current;
  bool playing = false;
  bool buffering = false;
  double volume = 70;
  String? error;

  /// "Artist - Title" from the ICY metadata, if the station sends it.
  String nowPlaying = '';

  /// Additional stream information (icy-name, icy-genre, codec, …).
  final Map<String, String> streamInfo = {};
  int? audioBitrate;
  int? sampleRate;
  int? channels;

  void init() {
    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'SlaxxFM',
        bufferSize: 8 * 1024 * 1024,
      ),
    );
    volume = settings.volume;
    _player.setVolume(volume);
    _subs.addAll([
      _player.stream.playing.listen((v) {
        playing = v;
        notifyListeners();
      }),
      _player.stream.buffering.listen((v) {
        buffering = v;
        notifyListeners();
      }),
      _player.stream.volume.listen((v) {
        volume = v;
        notifyListeners();
      }),
      _player.stream.error.listen(_onError),
      _player.stream.audioBitrate.listen((v) {
        audioBitrate = (v == null || v <= 0) ? null : v.round();
        notifyListeners();
      }),
      _player.stream.audioParams.listen((p) {
        sampleRate = p.sampleRate;
        channels = p.channelCount;
        notifyListeners();
      }),
    ]);
  }

  void _onError(String e) {
    if (current == null) return;
    error = e;
    final lower = e.toLowerCase();
    if (lower.contains('403') ||
        lower.contains('451') ||
        lower.contains('forbidden')) {
      repo.setStatus(current!, StreamStatus.vpn);
    }
    notifyListeners();
  }

  Future<void> play(Station s) async {
    current = s;
    error = null;
    nowPlaying = '';
    streamInfo.clear();
    audioBitrate = null;
    sampleRate = null;
    channels = null;
    notifyListeners();
    final headers = <String, String>{
      'User-Agent': s.userAgent.isNotEmpty ? s.userAgent : kStreamUserAgent,
    };
    await _player.open(Media(s.url, httpHeaders: headers), play: true);
    repo.api.countClick(s.id);
    _metaTimer?.cancel();
    _metaTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _pollMetadata());
    Future.delayed(const Duration(milliseconds: 1500), _pollMetadata);
  }

  Future<void> togglePlay() async {
    if (current == null) return;
    if (playing) {
      await _player.pause();
    } else {
      // for live radio "resume" means: reconnect to the live stream
      await play(current!);
    }
  }

  Future<void> stop() async {
    _metaTimer?.cancel();
    await _player.stop();
    playing = false;
    nowPlaying = '';
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    v = v.clamp(0, 100).toDouble();
    volume = v;
    settings.saveVolume(v);
    await _player.setVolume(v);
    notifyListeners();
  }

  Future<void> louder() => setVolume(volume + 5);
  Future<void> quieter() => setVolume(volume - 5);

  /// Reads ICY / stream metadata from mpv (title, station name, genre …).
  Future<void> _pollMetadata() async {
    if (current == null) return;
    try {
      final dynamic native = _player.platform;
      final String raw = await native.getProperty('metadata') as String;
      final info = <String, String>{};
      if (raw.trim().startsWith('{')) {
        final m = jsonDecode(raw);
        if (m is Map) {
          m.forEach((k, v) {
            final key = k.toString().toLowerCase();
            final val = v.toString().trim();
            if (val.isNotEmpty) info[key] = val;
          });
        }
      }
      String title = info['icy-title'] ?? info['title'] ?? '';
      if (title.isEmpty) {
        final String mt = await native.getProperty('media-title') as String;
        // mpv falls back to the file name/URL – ignore that
        if (!mt.contains('://') && mt != current!.url.split('/').last) {
          title = mt;
        }
      }
      try {
        final String codec =
            await native.getProperty('audio-codec-name') as String;
        if (codec.isNotEmpty) info['codec'] = codec;
      } catch (_) {}
      final changed = title != nowPlaying || !mapEquals(info, streamInfo);
      nowPlaying = title;
      streamInfo
        ..clear()
        ..addAll(info);
      if (changed) notifyListeners();
      if (error == null && playing) {
        repo.setStatus(current!, StreamStatus.ok);
      }
    } catch (_) {
      // metadata is optional
    }
  }

  @override
  void dispose() {
    _metaTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}

final player = PlayerService();
