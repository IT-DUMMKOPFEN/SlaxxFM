import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/services.dart' show EventChannel;

import '../models/station.dart';
import 'player_service.dart';
import 'settings.dart';
import 'station_repository.dart';

/// Where the visualizer data comes from.
enum AnalysisSource { estimated, loudness, spectrum }

/// Audio analysis for the visualizer.
///
/// * Android (opt-in): real spectrum via android.media.audiofx.Visualizer.
/// * Linux: real loudness from mpv's `astats` filter.
/// * Everywhere else: a music-like simulation whose tempo is estimated
///   from the station genre (libmpv on Windows/macOS/Android has no
///   measuring filters compiled in).
///
/// From the data it derives the bands (32), level, beats, BPM and a
/// music-vs-speech score.
class AudioAnalyzer {
  static const int bandCount = 32;

  final List<double> bands = List.filled(bandCount, 0);
  final List<double> _target = List.filled(bandCount, 0);
  final List<double> _agcMax = List.filled(bandCount, 1);
  double level = 0;
  double _levelTarget = 0;

  /// 1.0 at a beat, decays quickly.
  double beat = 0;

  /// Position inside the current beat (0..1).
  double phase = 0;
  int beatCount = 0;
  double bpm = 120;

  /// 0..1 – fades towards 1 while music (not speech) is playing.
  double music = 0;
  double _musicTarget = 0;

  /// Seconds since start (animation clock).
  double time = 0;
  double dt = 1 / 60;

  AnalysisSource source = AnalysisSource.estimated;
  bool bpmMeasured = false;

  final Stopwatch _clock = Stopwatch()..start();
  double _lastTick = 0;
  final math.Random _rnd = math.Random();

  // real data
  DateTime _lastReal = DateTime.fromMillisecondsSinceEpoch(0);
  final List<double> _realBands = List.filled(bandCount, 0);
  double _realLevel = 0;
  double _levelAgc = 0.05;

  // history for BPM / music detection (timestamp seconds, onset, level)
  final List<double> _hTime = [];
  final List<double> _hOnset = [];
  final List<double> _hLevel = [];
  double _prevFlux = 0;
  List<double> _prevBands = List.filled(bandCount, 0);
  double _lastBeatAt = 0;
  double _lastBpmCalc = 0;
  double _bpmConfidence = 0;

  Timer? _mpvTimer;
  StreamSubscription? _androidSub;
  Timer? _androidRetry;
  bool _started = false;

  static const _androidChannel = EventChannel('slaxxfm/visualizer');

  void start() {
    if (_started) return;
    _started = true;
    settings.addListener(_updateSources);
    player.addListener(_updateSources);
    _updateSources();
  }

  bool get _playing => player.active && player.playing && !player.buffering;

  void _updateSources() {
    // Linux: poll mpv loudness while playing
    if (Platform.isLinux && player.active) {
      _mpvTimer ??=
          Timer.periodic(const Duration(milliseconds: 40), (_) => _pollMpv());
    } else {
      _mpvTimer?.cancel();
      _mpvTimer = null;
    }
    // Android: Visualizer (opt-in)
    final wantAndroid =
        Platform.isAndroid && settings.realAnalysis && player.active;
    if (wantAndroid && _androidSub == null) {
      _listenAndroid();
    } else if (!wantAndroid && _androidSub != null) {
      _androidSub?.cancel();
      _androidSub = null;
      _androidRetry?.cancel();
    }
  }

  void _listenAndroid() {
    _androidSub = _androidChannel.receiveBroadcastStream().listen(
      (data) {
        if (data is List && data.length >= bandCount + 1) {
          final b = <double>[
            for (var i = 0; i < bandCount; i++) (data[i] as num).toDouble()
          ];
          _feedSpectrum(b, (data[bandCount] as num).toDouble());
        }
      },
      onError: (_) {
        // permission dialog open or Visualizer unavailable -> retry later
        _androidSub?.cancel();
        _androidSub = null;
        _androidRetry?.cancel();
        _androidRetry = Timer(const Duration(seconds: 4), _updateSources);
      },
      cancelOnError: true,
    );
  }

  Future<void> _pollMpv() async {
    final raw = await player.mpvProperty('af-metadata/slxstats');
    if (raw == null || raw.isEmpty) return;
    final m = RegExp(r'Overall\.RMS_level"?\s*[:=]\s*"?(-?[\d.]+|-inf)')
        .firstMatch(raw);
    if (m == null) return;
    final db = m.group(1) == '-inf' ? -90.0 : double.tryParse(m.group(1)!) ?? -90;
    // -50 dB .. -6 dB -> 0..1
    final lin = ((db + 50) / 44).clamp(0.0, 1.0);
    _feedLevel(lin);
  }

  void _feedLevel(double lin) {
    _lastReal = DateTime.now();
    source = AnalysisSource.loudness;
    _realLevel = lin;
    _record(lin, math.max(0.0, lin - _prevFlux));
    _prevFlux = _prevFlux * 0.7 + lin * 0.3;
  }

  void _feedSpectrum(List<double> raw, double rawLevel) {
    // automatic gain per band
    var sum = 0.0;
    for (var i = 0; i < bandCount; i++) {
      _agcMax[i] = math.max(raw[i], _agcMax[i] * 0.995);
      final v = _agcMax[i] <= 0 ? 0.0 : (raw[i] / _agcMax[i]);
      _realBands[i] = v.clamp(0.0, 1.0);
      sum += raw[i];
    }
    if (sum <= 0) return; // silence / not supported
    _lastReal = DateTime.now();
    source = AnalysisSource.spectrum;
    _levelAgc = math.max(rawLevel, _levelAgc * 0.997);
    _realLevel = (rawLevel / _levelAgc).clamp(0.0, 1.0);
    // spectral flux of the low/mid bands = onset strength
    var flux = 0.0;
    for (var i = 0; i < 12; i++) {
      flux += math.max(0.0, _realBands[i] - _prevBands[i]);
    }
    _prevBands = List.of(_realBands);
    _record(_realLevel, flux / 12);
  }

  void _record(double lvl, double onset) {
    final now = _clock.elapsedMilliseconds / 1000.0;
    _hTime.add(now);
    _hOnset.add(onset);
    _hLevel.add(lvl);
    while (_hTime.isNotEmpty && now - _hTime.first > 8) {
      _hTime.removeAt(0);
      _hOnset.removeAt(0);
      _hLevel.removeAt(0);
    }
    // beat: onset clearly above the recent average
    if (_hOnset.length > 20) {
      var mean = 0.0;
      for (final o in _hOnset) {
        mean += o;
      }
      mean /= _hOnset.length;
      var varSum = 0.0;
      for (final o in _hOnset) {
        varSum += (o - mean) * (o - mean);
      }
      final sd = math.sqrt(varSum / _hOnset.length);
      final minGap = 60 / bpm * 0.6;
      if (onset > mean + 1.4 * sd && now - _lastBeatAt > minGap) {
        _lastBeatAt = now;
        _onBeat(sync: true);
      }
    }
    if (now - _lastBpmCalc > 1.5) {
      _lastBpmCalc = now;
      _estimateBpm();
      _estimateMusic();
    }
  }

  /// Autocorrelation of the onset signal (resampled to 50 Hz).
  void _estimateBpm() {
    if (_hTime.length < 60) return;
    const rate = 50.0;
    final t0 = _hTime.first;
    final len = ((_hTime.last - t0) * rate).floor();
    if (len < 200) return;
    final sig = List<double>.filled(len, 0);
    var j = 0;
    for (var i = 0; i < len; i++) {
      final t = t0 + i / rate;
      while (j < _hTime.length - 2 && _hTime[j + 1] < t) {
        j++;
      }
      sig[i] = _hOnset[j];
    }
    final mean = sig.reduce((a, b) => a + b) / len;
    for (var i = 0; i < len; i++) {
      sig[i] -= mean;
    }
    double ac(int lag) {
      var s = 0.0;
      for (var i = 0; i + lag < len; i++) {
        s += sig[i] * sig[i + lag];
      }
      return s / (len - lag);
    }

    final zero = ac(0);
    if (zero <= 0) return;
    final minLag = (rate * 60 / 180).floor(); // 180 BPM
    final maxLag = (rate * 60 / 70).ceil(); // 70 BPM
    var bestLag = 0;
    var best = -1e9;
    final vals = <int, double>{};
    for (var lag = minLag; lag <= maxLag; lag++) {
      final v = ac(lag);
      vals[lag] = v;
      if (v > best) {
        best = v;
        bestLag = lag;
      }
    }
    if (bestLag == 0) return;
    // parabolic interpolation for sub-sample precision
    var lag = bestLag.toDouble();
    final a = vals[bestLag - 1], c = vals[bestLag + 1];
    if (a != null && c != null) {
      final d = a - 2 * best + c;
      if (d.abs() > 1e-12) lag = bestLag + 0.5 * (a - c) / d;
    }
    _bpmConfidence = (best / zero).clamp(0.0, 1.0);
    if (_bpmConfidence > 0.2) {
      var measured = 60 * rate / lag;
      // keep it in a danceable range
      while (measured < 80) {
        measured *= 2;
      }
      while (measured > 170) {
        measured /= 2;
      }
      bpm = bpm * 0.6 + measured * 0.4;
      bpmMeasured = true;
    }
  }

  /// Music vs. speech: speech has many quiet gaps between syllables
  /// ("low energy rate") and no steady beat.
  void _estimateMusic() {
    if (_hLevel.length < 40) return;
    final mean = _hLevel.reduce((a, b) => a + b) / _hLevel.length;
    if (mean < 0.02) {
      _musicTarget = 0;
      return;
    }
    final low = _hLevel.where((l) => l < mean * 0.5).length / _hLevel.length;
    final isMusic = low < 0.28 || _bpmConfidence > 0.35;
    _musicTarget = isMusic ? 1 : 0;
  }

  void _onBeat({bool sync = false}) {
    beat = 1;
    beatCount++;
    if (sync) phase = 0;
  }

  // ---------------------------------------------------------------- tick

  /// Called by the visualizer once per frame.
  void tick() {
    final now = _clock.elapsedMicroseconds / 1e6;
    dt = (now - _lastTick).clamp(0.0, 0.1);
    if (dt < 0.004) return; // already ticked this frame
    _lastTick = now;
    time += dt;

    final st = player.current;
    final playing = _playing;
    final realFresh =
        DateTime.now().difference(_lastReal).inMilliseconds < 600 && playing;
    if (!realFresh) {
      source = AnalysisSource.estimated;
      bpmMeasured = false;
      if (st != null) bpm = bpm * 0.98 + estimateBpm(st) * 0.02;
    }

    // beat clock
    final period = 60 / bpm;
    phase += dt / period;
    if (phase >= 1) {
      phase -= phase.floor();
      if (!realFresh || source == AnalysisSource.loudness) {
        _onBeat();
      } else {
        // spectrum mode syncs on detected onsets; keep counting anyway
        beatCount++;
      }
    }
    beat = math.max(0.0, beat - dt * 4);

    // targets
    if (!playing) {
      for (var i = 0; i < bandCount; i++) {
        _target[i] = 0;
      }
      _levelTarget = 0;
      _musicTarget = 0;
    } else if (source == AnalysisSource.spectrum && realFresh) {
      for (var i = 0; i < bandCount; i++) {
        _target[i] = _realBands[i];
      }
      _levelTarget = _realLevel;
    } else {
      final lvl = realFresh ? _realLevel : _simLevel();
      _levelTarget = lvl;
      _simBands(lvl);
      if (!realFresh) {
        final talk = st != null && StationRepository.isNonMusic(st);
        _musicTarget = talk ? 0 : 1;
      }
    }

    // smoothing (frame-rate independent)
    double k(double perFrame) => 1 - math.pow(1 - perFrame, dt * 60).toDouble();
    final up = k(0.45), down = k(0.12);
    for (var i = 0; i < bandCount; i++) {
      final t = _target[i];
      bands[i] += (t - bands[i]) * (t > bands[i] ? up : down);
    }
    level += (_levelTarget - level) * (_levelTarget > level ? up : down);
    music += (_musicTarget - music) * k(0.02);
  }

  double _simLevel() {
    final env = math.pow(1 - phase, 3).toDouble(); // kick envelope
    return (0.5 +
            0.12 * math.sin(time * 0.37) +
            0.08 * math.sin(time * 1.3 + 1) +
            0.22 * env +
            0.05 * _rnd.nextDouble())
        .clamp(0.0, 1.0);
  }

  void _simBands(double lvl) {
    final kick = math.pow(1 - phase, 4).toDouble();
    final hat = math.pow(1 - ((phase * 2) % 1), 6).toDouble();
    for (var i = 0; i < bandCount; i++) {
      final x = i / (bandCount - 1);
      var v = 0.85 - 0.45 * x; // more energy in the bass
      v *= 0.65 +
          0.2 * math.sin(time * (1.1 + i * 0.17) + i * 1.7) +
          0.15 * math.sin(time * (2.3 + i * 0.05) + i);
      if (x < 0.2) v += 0.45 * kick * (1 - x * 3);
      if (x > 0.6) v += 0.25 * hat * x;
      v += 0.08 * (_rnd.nextDouble() - 0.5);
      _target[i] = (v * lvl * 1.15).clamp(0.0, 1.0);
    }
  }

  /// Typical tempo of the station's genre (used when nothing is measured).
  static double estimateBpm(Station s) {
    const table = <String, double>{
      'drum and bass': 174, 'dnb': 174, 'jungle': 170, 'hardcore': 165,
      'hardstyle': 150, 'psytrance': 142, 'trance': 138, 'techno': 130,
      'metal': 140, 'punk': 160, 'eurodance': 136, 'dance': 126,
      'edm': 126, 'house': 124, 'electro': 126, 'club': 126, 'disco': 118,
      'funk': 110, 'pop': 116, 'hits': 118, 'top 40': 120, 'charts': 120,
      'rock': 120, 'schlager': 112, 'country': 110, 'oldies': 114,
      '80s': 120, '90s': 118, 'latin': 100, 'salsa': 180, 'reggaeton': 95,
      'hip hop': 92, 'hiphop': 92, 'rap': 92, 'r&b': 95, 'rnb': 95,
      'soul': 100, 'jazz': 110, 'blues': 90, 'reggae': 80, 'dub': 75,
      'lounge': 100, 'chill': 90, 'lofi': 80, 'lo-fi': 80, 'ambient': 70,
      'classical': 80, 'klassik': 80, 'folk': 100, 'indie': 120,
    };
    for (final t in s.tagList) {
      for (final e in table.entries) {
        if (t.contains(e.key)) return e.value;
      }
    }
    return 120;
  }
}

final analyzer = AudioAnalyzer();
