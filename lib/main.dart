import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'services/audio_analyzer.dart';
import 'services/audio_handler.dart';
import 'services/player_service.dart';
import 'services/settings.dart';
import 'services/station_repository.dart';
import 'ui/brand.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await settings.load();
  player.init();
  // Android: background playback, media notification, Android Auto
  await initAudioService();
  analyzer.start();
  runApp(const SlaxxFmApp());
  // loads the cached list (or downloads it on the first start)
  repo.init();
}

class SlaxxFmApp extends StatefulWidget {
  const SlaxxFmApp({super.key});

  @override
  State<SlaxxFmApp> createState() => _SlaxxFmAppState();
}

class _SlaxxFmAppState extends State<SlaxxFmApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    analyzer.appVisible = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'SlaxxFM',
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomePage(),
      ),
    );
  }
}
