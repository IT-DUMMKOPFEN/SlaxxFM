import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SortMode { popular, name, bitrate }

/// All visualizer effects in display order.
const List<String> kAllEffects = [
  'bars',
  'rainbow',
  'radial',
  'stars',
  'wave',
  'colorwave',
  'disco',
  'discoball',
  'fireworks',
  'lasers',
  'tunnel',
  'synthwave',
  'vu',
  'ripples',
  'aurora',
  'kaleido',
  'plasma',
  'mountains',
  'bubbles',
  'spiral',
  'leds',
  'orbits',
  'scope',
  'circlewave',
  'confetti',
  'lava',
  'sunburst',
  'hexgrid',
  'flower',
  'helix',
  'fire',
  'fountain',
  'bars3d',
  'snow',
];

class AppSettings extends ChangeNotifier {
  late SharedPreferences _p;

  ThemeMode themeMode = ThemeMode.system;

  /// 'system', 'en' or 'de'
  String language = 'system';
  bool musicOnly = true;
  bool hideVpn = false;
  SortMode sort = SortMode.popular;
  double volume = 70;
  String lastCountry = '';
  int parallelChecks = 16;

  /// Recently played station ids (newest first).
  List<String> recent = [];

  bool muted = false;

  /// Android: the battery-optimisation question was shown once.
  bool askedBattery = false;

  /// Seconds of audio that are buffered before playback starts
  /// (0 = off). Covers short dropouts of the stream.
  int bufferSecs = 3;

  /// Visualizer effects that are switched on (ids, see visualizer.dart).
  Set<String> effects = {};
  String currentEffect = '';
  bool dancers = true;

  /// Master switch for the whole visualizer (effects and dancers).
  bool visualizerOn = true;

  /// Android: real spectrum via android.media.audiofx.Visualizer
  /// (needs the microphone permission).
  bool realAnalysis = false;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[
        (_p.getInt('themeMode') ?? 0).clamp(0, ThemeMode.values.length - 1)];
    language = _p.getString('language') ?? 'system';
    musicOnly = _p.getBool('musicOnly') ?? true;
    hideVpn = _p.getBool('hideVpn') ?? false;
    sort = SortMode
        .values[(_p.getInt('sort') ?? 0).clamp(0, SortMode.values.length - 1)];
    volume = _p.getDouble('volume') ?? 70;
    lastCountry = _p.getString('lastCountry') ?? '';
    parallelChecks = _p.getInt('parallelChecks') ?? 16;
    recent = _p.getStringList('recent') ?? [];
    muted = _p.getBool('muted') ?? false;
    askedBattery = _p.getBool('askedBattery') ?? false;
    bufferSecs = _p.getInt('bufferSecs') ?? 3;
    final eff = _p.getStringList('effects');
    effects = eff == null ? kAllEffects.toSet() : eff.toSet();
    // effects added in a newer version start switched on
    final known = _p.getStringList('knownEffects') ??
        (eff == null ? kAllEffects : kAllEffects.take(9).toList());
    for (final e in kAllEffects) {
      if (!known.contains(e)) effects.add(e);
    }
    _p.setStringList('knownEffects', kAllEffects);
    _p.setStringList('effects', effects.toList());
    currentEffect = _p.getString('currentEffect') ?? kAllEffects.first;
    dancers = _p.getBool('dancers') ?? true;
    visualizerOn = _p.getBool('visualizerOn') ?? true;
    realAnalysis = _p.getBool('realAnalysis') ?? false;
  }

  String get effectiveLanguage {
    if (language != 'system') return language;
    final code = PlatformDispatcher.instance.locale.languageCode;
    return code == 'de' ? 'de' : 'en';
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _p.setInt('themeMode', m.index);
    notifyListeners();
  }

  /// Toggles between light and dark (uses the current brightness when
  /// the mode is "system").
  void toggleDark(Brightness current) {
    setThemeMode(
        current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setLanguage(String l) {
    language = l;
    _p.setString('language', l);
    notifyListeners();
  }

  void setMusicOnly(bool v) {
    musicOnly = v;
    _p.setBool('musicOnly', v);
    notifyListeners();
  }

  void setHideVpn(bool v) {
    hideVpn = v;
    _p.setBool('hideVpn', v);
    notifyListeners();
  }

  void setSort(SortMode s) {
    sort = s;
    _p.setInt('sort', s.index);
    notifyListeners();
  }

  void setParallelChecks(int v) {
    parallelChecks = v;
    _p.setInt('parallelChecks', v);
    notifyListeners();
  }

  /// Saved without notifying (called often).
  void saveVolume(double v) {
    volume = v;
    _p.setDouble('volume', v);
  }

  void setBufferSecs(int v) {
    bufferSecs = v;
    _p.setInt('bufferSecs', v);
    notifyListeners();
  }

  void setAskedBattery() {
    askedBattery = true;
    _p.setBool('askedBattery', true);
  }

  void setMuted(bool v) {
    muted = v;
    _p.setBool('muted', v);
    notifyListeners();
  }

  void setEffectEnabled(String id, bool on) {
    if (on) {
      effects.add(id);
    } else {
      effects.remove(id);
    }
    _p.setStringList('effects', effects.toList());
    notifyListeners();
  }

  /// Enabled effects in their fixed order.
  List<String> get enabledEffects =>
      kAllEffects.where(effects.contains).toList();

  void setCurrentEffect(String id) {
    currentEffect = id;
    _p.setString('currentEffect', id);
    notifyListeners();
  }

  /// Switches to the next enabled effect (mouse click on the visualizer).
  void nextEffect() {
    final list = enabledEffects;
    if (list.isEmpty) return;
    final i = list.indexOf(currentEffect);
    setCurrentEffect(list[(i + 1) % list.length]);
  }

  void setVisualizerOn(bool v) {
    visualizerOn = v;
    _p.setBool('visualizerOn', v);
    notifyListeners();
  }

  void setDancers(bool v) {
    dancers = v;
    _p.setBool('dancers', v);
    notifyListeners();
  }

  void setRealAnalysis(bool v) {
    realAnalysis = v;
    _p.setBool('realAnalysis', v);
    notifyListeners();
  }

  void addRecent(String id) {
    recent.remove(id);
    recent.insert(0, id);
    if (recent.length > 30) recent = recent.sublist(0, 30);
    _p.setStringList('recent', recent);
  }

  void saveLastCountry(String cc) {
    lastCountry = cc;
    _p.setString('lastCountry', cc);
  }
}

final settings = AppSettings();
