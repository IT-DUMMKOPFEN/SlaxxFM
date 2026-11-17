import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/settings.dart';
import '../services/station_repository.dart';

const String kAppVersion = '1.0.0';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                  header(tr('about')),
                  ListTile(
                    leading: Image.asset('assets/icon/icon.png', width: 40),
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
