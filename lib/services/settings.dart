import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SortMode { popular, name, bitrate }

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
