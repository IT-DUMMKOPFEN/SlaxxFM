import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:media_kit/media_kit.dart';

import '../models/station.dart';
import 'station_repository.dart';
import 'settings.dart';
import 'stream_tester.dart' show kStreamUserAgent;

/// Thin wrapper around media_kit (libmpv) for live radio playback.
///
/// Live streams can drop at any time (mobile network change, Wi-Fi sleep,
/// server hiccup). The service therefore
///  * lets ffmpeg reconnect transparently (`stream-lavf-o reconnect=…`),
///  * reopens the stream itself when it ends, errors or stalls,
///  * keeps a CPU wake lock + Wi-Fi lock on Android while playing,
///  * handles audio focus (calls, navigation prompts, Android Auto).
class PlayerService extends ChangeNotifier {
  late final Player _player;
  final List<StreamSubscription> _subs = [];
  Timer? _metaTimer;
  Timer? _reconnectTimer;
  Timer? _stallTimer;

  static const _locks = MethodChannel('slaxxfm/locks');
  AudioSession? _session;

  Station? current;
  bool playing = false;
  bool buffering = false;
  double volume = 70;
  String? error;

  /// The user wants sound (true while reconnecting as well).
  bool _wantPlaying = false;
  bool get active => _wantPlaying;

  /// Station list the current station was started from (for next/previous).
  List<Station> _queue = const [];

  DateTime _openedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _attempts = 0;
  bool _stationEverPlayed = false;
  bool _pausedByInterruption = false;
  bool _ducked = false;

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
    _applyVolume();
    _configureMpv();
    settings.addListener(_applyBuffer);
    _subs.addAll([
      _player.stream.playing.listen((v) {
        playing = v;
        notifyListeners();
      }),
      _player.stream.buffering.listen(_onBuffering),
      _player.stream.volume.listen((_) => notifyListeners()),
      _player.stream.error.listen(_onError),
      _player.stream.completed.listen((done) {
        if (done) _onStreamEnded();
      }),
      _player.stream.audioBitrate.listen((v) {
        audioBitrate = (v == null || v <= 0) ? null : v.round();
        notifyListeners();
      }),
      _player.stream.audioParams.listen((p) {
        sampleRate = p.sampleRate;
        channels = p.channelCount;
        if (p.sampleRate != null && _wantPlaying) _audioIsFlowing();
        notifyListeners();
      }),
    ]);
    if (Platform.isAndroid) _initAudioSession();
    if (Platform.isMacOS) {
      // native side reports when the Mac wakes up from sleep
      _locks.setMethodCallHandler((call) async {
        if (call.method == 'wake') _onWake();
        return null;
      });
    }
  }

  /// After the Mac woke up the old connection is dead: reconnect at once
  /// instead of waiting for the watchdog.
  void _onWake() {
    final s = current;
    if (!_wantPlaying || s == null || _shutDown) return;
    _attempts = 0;
    Future.delayed(const Duration(seconds: 2), () {
      if (_wantPlaying && current?.id == s.id && !_shutDown) _open(s);
    });
  }

  bool _shutDown = false;

  /// Stops mpv cleanly before the app quits. Without this, mpv's core
  /// thread may still call back into the already destroyed Flutter engine
  /// (crash on quit, seen on macOS).
  Future<void> shutdown() async {
    if (_shutDown) return;
    _shutDown = true;
    _wantPlaying = false;
    _metaTimer?.cancel();
    _reconnectTimer?.cancel();
    _stallTimer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _setLocks(false);
    try {
      await _player.stop().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await _player.dispose().timeout(const Duration(seconds: 3));
    } catch (_) {}
    // give mpv's core thread time to finish after mpv_terminate_destroy
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _configureMpv() async {
    try {
      final dynamic native = _player.platform;
      await native.setProperty('network-timeout', '20');
      await native.setProperty('stream-lavf-o',
          'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=30');
      // radio only: never decode video tracks / cover art
      await native.setProperty('vid', 'no');
      await native.setProperty('audio-display', 'no');
      if (Platform.isAndroid) {
        // bigger audio output buffer: survives CPU hiccups when the app
        // runs in the background with the screen off
        await native.setProperty('audio-buffer', '0.8');
      }
      await native.setProperty('cache', 'yes');
      await native.setProperty('cache-secs', '60');
      await _applyBuffer();
      if (Platform.isLinux) {
        // system libmpv on Linux ships all ffmpeg filters: measure the
        // loudness for the visualizer (astats passes the audio unchanged)
        await native.setProperty(
            'af', '@slxstats:lavfi=[astats=metadata=1:reset=1]');
      }
    } catch (_) {
      // optional tuning only
    }
  }

  int _appliedBuffer = -1;

  /// Buffer: playback starts only when [settings.bufferSecs] seconds are
  /// in the cache and runs that far behind the live edge, so short
  /// dropouts of the stream are bridged without the user noticing.
  Future<void> _applyBuffer() async {
    final secs = settings.bufferSecs;
    if (secs == _appliedBuffer) return;
    _appliedBuffer = secs;
    try {
      final dynamic native = _player.platform;
      if (secs > 0) {
        await native.setProperty('cache-pause-initial', 'yes');
        await native.setProperty('cache-pause-wait', '$secs');
        await native.setProperty('demuxer-readahead-secs', '${secs + 30}');
      } else {
        await native.setProperty('cache-pause-initial', 'no');
        await native.setProperty('cache-pause-wait', '1');
      }
    } catch (_) {}
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _session = session;
      session.interruptionEventStream.listen((e) {
        if (e.begin) {
          if (e.type == AudioInterruptionType.duck) {
            _duck(true);
          } else if (_wantPlaying) {
            _pausedByInterruption = true;
            pause();
          }
        } else {
          if (e.type == AudioInterruptionType.duck) {
            _duck(false);
          } else if (e.type == AudioInterruptionType.pause &&
              _pausedByInterruption) {
            resume();
          }
          _pausedByInterruption = false;
        }
      });
      // headphones unplugged / Bluetooth disconnected
      session.becomingNoisyEventStream.listen((_) => pause());
    } catch (_) {}
  }

  void _duck(bool on) {
    _ducked = on;
    _applyVolume();
  }

  bool get muted => settings.muted;

  bool get recentIsEmpty => settings.recent.isEmpty;

  void _applyVolume() {
    final v = settings.muted
        ? 0.0
        : _ducked
            ? volume * 0.3
            : volume;
    _player.setVolume(v);
  }

  void toggleMute() {
    settings.setMuted(!settings.muted);
    _applyVolume();
    notifyListeners();
  }

  /// Raw mpv property (used by the audio analyzer), null if unavailable.
  Future<String?> mpvProperty(String name) async {
    try {
      final dynamic native = _player.platform;
      return await native.getProperty(name) as String;
    } catch (_) {
      return null;
    }
  }

  /// Android: is SlaxxFM still restricted by the battery optimisation?
  Future<bool> batteryOptimized() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _locks.invokeMethod<bool>('batteryOptimized') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system dialog that exempts SlaxxFM from battery
  /// optimisation (otherwise some phones throttle the stream in the
  /// background).
  Future<void> requestBatteryExemption() async {
    if (!Platform.isAndroid) return;
    try {
      await _locks.invokeMethod('requestBatteryExemption');
    } catch (_) {}
  }

  Future<void> _askBatteryExemptionOnce() async {
    if (!Platform.isAndroid || settings.askedBattery) return;
    if (!await batteryOptimized()) return;
    settings.setAskedBattery();
    await requestBatteryExemption();
  }

  /// Android: wake/wifi lock. macOS: no App Nap and no idle system sleep
  /// while playing.
  Future<void> _setLocks(bool on) async {
    if (!Platform.isAndroid && !Platform.isMacOS) return;
    try {
      await _locks.invokeMethod(on ? 'acquire' : 'release');
    } catch (_) {}
  }

  // ------------------------------------------------------------ playback

  /// Starts [s]. [queue] is the list it was chosen from (next / previous).
  Future<void> play(Station s, {List<Station>? queue}) async {
    if (queue != null && queue.isNotEmpty) _queue = List.of(queue);
    if (!_queue.any((e) => e.id == s.id)) _queue = [s];
    _attempts = 0;
    _stationEverPlayed = false;
    _wantPlaying = true;
    unawaited(_askBatteryExemptionOnce());
    settings.addRecent(s.id);
    repo.api.countClick(s.id);
    await _open(s);
  }

  Future<void> _open(Station s) async {
    _pausedAt = null;
    _reconnectTimer?.cancel();
    _stallTimer?.cancel();
    final changed = current?.id != s.id;
    current = s;
    error = null;
    if (changed) {
      nowPlaying = '';
      streamInfo.clear();
    }
    audioBitrate = null;
    sampleRate = null;
    channels = null;
    notifyListeners();
    try {
      await _session?.setActive(true);
    } catch (_) {}
    unawaited(_setLocks(true));
    _openedAt = DateTime.now();
    final headers = <String, String>{
      'User-Agent': s.userAgent.isNotEmpty ? s.userAgent : kStreamUserAgent,
    };
    await _player.open(Media(s.url, httpHeaders: headers), play: true);
    _metaTimer?.cancel();
    _metaTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _pollMetadata());
    Future.delayed(const Duration(milliseconds: 1500), _pollMetadata);
  }

  DateTime? _pausedAt;

  /// Resume after a short pause (call, notification sound, headphones):
  /// continue from the buffer. After a longer pause reconnect to the
  /// live stream.
  Future<void> resume() async {
    final s = current;
    final pausedAt = _pausedAt;
    if (s != null &&
        pausedAt != null &&
        DateTime.now().difference(pausedAt).inSeconds < 45 &&
        error == null) {
      _pausedAt = null;
      _wantPlaying = true;
      try {
        await _session?.setActive(true);
      } catch (_) {}
      unawaited(_setLocks(true));
      await _player.play();
      notifyListeners();
      return;
    }
    if (s == null) {
      // nothing chosen yet: start the most recent station
      for (final id in settings.recent) {
        final r = repo.byId(id);
        if (r != null) return play(r);
      }
      return;
    }
    return play(s);
  }

  Future<void> pause() async {
    _pausedAt = DateTime.now();
    _wantPlaying = false;
    _reconnectTimer?.cancel();
    _stallTimer?.cancel();
    await _player.pause();
    unawaited(_setLocks(false));
    notifyListeners();
  }

  Future<void> togglePlay() => _wantPlaying ? pause() : resume();

  Future<void> stop() async {
    _wantPlaying = false;
    _reconnectTimer?.cancel();
    _stallTimer?.cancel();
    _metaTimer?.cancel();
    await _player.stop();
    playing = false;
    nowPlaying = '';
    unawaited(_setLocks(false));
    try {
      await _session?.setActive(false);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> next() => _step(1);
  Future<void> previous() => _step(-1);

  Future<void> _step(int dir) async {
    if (_queue.isEmpty) return;
    final i = _queue.indexWhere((e) => e.id == current?.id);
    final n = (i < 0 ? 0 : i + dir) % _queue.length;
    await play(_queue[n < 0 ? n + _queue.length : n]);
  }

  Future<void> setVolume(double v) async {
    v = v.clamp(0, 100).toDouble();
    volume = v;
    settings.saveVolume(v);
    if (settings.muted && v > 0) settings.setMuted(false);
    _applyVolume();
    notifyListeners();
  }

  Future<void> louder() => setVolume(volume + 5);
  Future<void> quieter() => setVolume(volume - 5);

  // ------------------------------------------------------------ recovery

  void _audioIsFlowing() {
    _stationEverPlayed = true;
    _attempts = 0;
    if (error != null) {
      error = null;
      notifyListeners();
    }
  }

  void _onBuffering(bool v) {
    buffering = v;
    _stallTimer?.cancel();
    if (v && _wantPlaying) {
      // stuck in buffering for too long -> reconnect
      _stallTimer = Timer(const Duration(seconds: 25), () {
        if (buffering && _wantPlaying) _scheduleReconnect('stalled');
      });
    }
    notifyListeners();
  }

  void _onStreamEnded() {
    if (!_wantPlaying) return;
    // a live stream never "ends" – the connection dropped
    if (DateTime.now().difference(_openedAt).inMilliseconds < 1500) return;
    _scheduleReconnect('ended');
  }

  void _onError(String e) {
    if (current == null) return;
    final lower = e.toLowerCase();
    if (lower.contains('403') ||
        lower.contains('451') ||
        lower.contains('forbidden')) {
      repo.setStatus(current!, StreamStatus.vpn);
    }
    // mpv also reports harmless errors while audio keeps flowing
    final healthy = playing && !buffering && sampleRate != null;
    if (healthy) return;
    error = e;
    notifyListeners();
    if (_wantPlaying) _scheduleReconnect('error');
  }

  void _scheduleReconnect(String reason) {
    final s = current;
    if (s == null || !_wantPlaying) return;
    if (_reconnectTimer?.isActive ?? false) return;
    _attempts++;
    // a station that never played: give up after a few tries
    if (!_stationEverPlayed && _attempts > 4) {
      _wantPlaying = false;
      unawaited(_setLocks(false));
      notifyListeners();
      return;
    }
    final secs = math.min(30, 1 << math.min(_attempts, 5)); // 2,4,8,16,30
    _reconnectTimer = Timer(Duration(seconds: secs), () {
      if (!_wantPlaying || current?.id != s.id) return;
      final healthy = playing && !buffering && sampleRate != null;
      if (reason == 'ended' || !healthy) _open(s);
    });
    notifyListeners();
  }

  // ------------------------------------------------------------ metadata

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
      if (playing && !buffering) {
        _audioIsFlowing();
        repo.setStatus(current!, StreamStatus.ok);
      }
    } catch (_) {
      // metadata is optional
    }
  }

  @override
  void dispose() {
    if (_shutDown) {
      super.dispose();
      return;
    }
    _metaTimer?.cancel();
    _reconnectTimer?.cancel();
    _stallTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}

final player = PlayerService();
