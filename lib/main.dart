import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'services/audio_handler.dart';
import 'services/player_service.dart';
import 'services/settings.dart';
import 'services/station_repository.dart';
import 'ui/home_page.dart';

const Color kSeed = Color(0xFFB0228C);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await settings.load();
  player.init();
  // Android: background playback, media notification, Android Auto
  await initAudioService();
  runApp(const SlaxxFmApp());
  // loads the cached list (or downloads it on the first start)
  repo.init();
}

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: kSeed, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        b == Brightness.dark ? const Color(0xFF121016) : scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      backgroundColor:
          b == Brightness.dark ? const Color(0xFF121016) : scheme.surface,
    ),
    sliderTheme: const SliderThemeData(trackHeight: 4),
  );
}

class SlaxxFmApp extends StatelessWidget {
  const SlaxxFmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'SlaxxFM',
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const HomePage(),
      ),
    );
  }
}
