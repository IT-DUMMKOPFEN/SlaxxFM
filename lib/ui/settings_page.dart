import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/favorites_io.dart';
import '../services/player_service.dart';
import '../services/settings.dart';
import '../services/station_repository.dart';
import 'help_page.dart';
import 'visualizer/visualizer.dart' show effectName;

const String kAppVersion = '1.3.1';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Future<void> _run(BuildContext context, Future<String?> job) async {
    final msg = await job;
    if (msg != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([settings, repo]),
      builder: (context, _) {
        final theme = Theme.of(context);
        Widget header(String t) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: Text(t,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary)),
            );
        final upd = repo.updatedAt;
        return Scaffold(
          appBar: AppBar(title: Text(tr('settings'))),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                children: [
                  header(tr('theme')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                            value: ThemeMode.system,
                            icon: const Icon(Icons.brightness_auto),
                            label: Text(tr('themeSystem'))),
                        ButtonSegment(
                            value: ThemeMode.light,
                            icon: const Icon(Icons.light_mode),
                            label: Text(tr('themeLight'))),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            icon: const Icon(Icons.dark_mode),
                            label: Text(tr('themeDark'))),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (v) => settings.setThemeMode(v.first),
                    ),
                  ),
                  header(tr('language')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                            value: 'system', label: Text(tr('themeSystem'))),
                        const ButtonSegment(value: 'de', label: Text('Deutsch')),
                        const ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {settings.language},
                      onSelectionChanged: (v) => settings.setLanguage(v.first),
                    ),
                  ),
                  header(tr('stations')),
                  SwitchListTile(
                    title: Text(tr('musicOnly')),
                    subtitle: Text(tr('musicOnlySub')),
                    value: settings.musicOnly,
                    onChanged: settings.setMusicOnly,
                  ),
                  SwitchListTile(
                    title: Text(tr('hideVpn')),
                    value: settings.hideVpn,
                    onChanged: settings.setHideVpn,
                  ),
                  ListTile(
                    title: Text(tr('sort')),
                    trailing: DropdownButton<SortMode>(
                      value: settings.sort,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                            value: SortMode.popular,
                            child: Text(tr('sortPopular'))),
                        DropdownMenuItem(
                            value: SortMode.name, child: Text(tr('sortName'))),
                        DropdownMenuItem(
                            value: SortMode.bitrate,
                            child: Text(tr('sortBitrate'))),
                      ],
                      onChanged: (v) {
                        if (v != null) settings.setSort(v);
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(tr('parallel')),
                    subtitle: Slider(
                      value: settings.parallelChecks.toDouble().clamp(4.0, 48.0),
                      min: 4,
                      max: 48,
                      divisions: 11,
                      label: '${settings.parallelChecks}',
                      onChanged: (v) => settings.setParallelChecks(v.round()),
                    ),
                    trailing: Text('${settings.parallelChecks}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: Text(tr('restore')),
                    subtitle:
                        Text(tr('restoreSub', {'n': repo.removedCount})),
                    enabled: repo.removedCount > 0,
                    onTap: () async {
                      await repo.restoreRemoved();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('restored'))));
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.update),
                    title: Text(tr('lastUpdate', {
                      'd': upd == null
                          ? tr('never')
                          : '${upd.day}.${upd.month}.${upd.year} '
                              '${upd.hour.toString().padLeft(2, '0')}:'
                              '${upd.minute.toString().padLeft(2, '0')}'
                    })),
                    subtitle: Text(
                        '${repo.visibleCount} / ${repo.totalCount} ${tr('stations')}'),
                  ),
                  header(tr('playback')),
                  ListTile(
                    leading: const Icon(Icons.hourglass_bottom_rounded),
                    title: Text(tr('buffer')),
                    subtitle: Text(tr('bufferSub')),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 0, label: Text(tr('bufferOff'))),
                        const ButtonSegment(value: 3, label: Text('3 s')),
                        const ButtonSegment(value: 5, label: Text('5 s')),
                      ],
                      selected: {settings.bufferSecs},
                      onSelectionChanged: (v) =>
                          settings.setBufferSecs(v.first),
                    ),
                  ),
                  if (Platform.isAndroid)
                    ListTile(
                      leading: const Icon(Icons.battery_saver_rounded),
                      title: Text(tr('battery')),
                      subtitle: Text(tr('batterySub')),
                      onTap: player.requestBatteryExemption,
                    ),
                  header(tr('visualizer')),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Text(tr('visualizerSub'),
                        style: theme.textTheme.bodySmall),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.auto_awesome_rounded),
                    title: Text(tr('visualizerOn')),
                    subtitle: Text(tr('visualizerOnSub')),
                    value: settings.visualizerOn,
                    onChanged: settings.setVisualizerOn,
                  ),
                  for (final id in kAllEffects)
                    CheckboxListTile(
                      dense: true,
                      enabled: settings.visualizerOn,
                      title: Text(effectName(id)),
                      value: settings.effects.contains(id),
                      onChanged: (v) =>
                          settings.setEffectEnabled(id, v ?? false),
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.accessibility_new_rounded),
                    title: Text(tr('dancers')),
                    subtitle: Text(tr('dancersSub')),
                    value: settings.visualizerOn && settings.dancers,
                    onChanged:
                        settings.visualizerOn ? settings.setDancers : null,
                  ),
                  if (Platform.isAndroid)
                    SwitchListTile(
                      secondary: const Icon(Icons.graphic_eq_rounded),
                      title: Text(tr('realAnalysis')),
                      subtitle: Text(tr('realAnalysisSub')),
                      value: settings.realAnalysis,
                      onChanged: settings.setRealAnalysis,
                    ),
                  header(tr('favorites')),
                  ListTile(
                    leading: const Icon(Icons.upload_file_rounded),
                    title: Text(tr('exportFav')),
                    onTap: () => _run(context, FavoritesIO.export(m3u: false)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: Text(tr('exportFavM3u')),
                    onTap: () => _run(context, FavoritesIO.export(m3u: true)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_rounded),
                    title: Text(tr('importFav')),
                    subtitle: Text(tr('importFavSub')),
                    onTap: () => _run(context, FavoritesIO.import()),
                  ),
                  header(tr('help')),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: Text(tr('helpOpen')),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpPage())),
                  ),
                  header(tr('about')),
                  ListTile(
                    leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset('assets/logo.png', width: 48)),
                    title: const Text('SlaxxFM'),
                    subtitle: Text(tr('aboutText', {'v': kAppVersion})),
                    isThreeLine: true,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
