import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n.dart';
import '../../models/station.dart';
import '../../services/player_service.dart';
import '../../services/station_repository.dart';
import 'country_list.dart';
import 'station_grid.dart' show VpnBadge;
import 'station_logo.dart';

/// Play / pause, stop, quieter / louder + volume slider.
class PlayerControls extends StatelessWidget {
  final bool compact;
  const PlayerControls({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([player, repo]),
      builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final has = player.current != null;
    final playBtn = IconButton.filled(
      iconSize: compact ? 26 : 40,
      onPressed: has ? player.togglePlay : null,
      icon: player.buffering && player.playing
          ? SizedBox(
              width: compact ? 26 : 40,
              height: compact ? 26 : 40,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: scheme.onPrimary),
              ),
            )
          : Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
    if (compact) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            onPressed: player.quieter, icon: const Icon(Icons.volume_down)),
        playBtn,
        IconButton(onPressed: player.louder, icon: const Icon(Icons.volume_up)),
      ]);
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 28,
              onPressed: has ? player.stop : null,
              icon: const Icon(Icons.stop_rounded),
            ),
            const SizedBox(width: 12),
            playBtn,
            const SizedBox(width: 12),
            IconButton(
              iconSize: 28,
              onPressed: player.current == null
                  ? null
                  : () => repo.toggleFavorite(player.current!),
              icon: Icon(player.current != null &&
                      repo.isFavorite(player.current!)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded),
              color: player.current != null && repo.isFavorite(player.current!)
                  ? Colors.amber
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
                onPressed: player.quieter,
                icon: const Icon(Icons.volume_down_rounded)),
            Expanded(
              child: Slider(
                value: player.volume.clamp(0, 100).toDouble(),
                min: 0,
                max: 100,
                onChanged: player.setVolume,
              ),
            ),
            IconButton(
                onPressed: player.louder,
                icon: const Icon(Icons.volume_up_rounded)),
            SizedBox(
              width: 34,
              child: Text('${player.volume.round()}',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium),
            ),
          ],
        ),
      ],
    );
  }
}

/// Large player with picture and station / stream information.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, repo]),
      builder: (context, _) {
        final s = player.current;
        final theme = Theme.of(context);
        if (s == null) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.radio_rounded,
                  size: 72, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(tr('nothingPlaying'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: PlayerControls(),
              ),
            ]),
          );
        }
        final status = repo.statusOf(s);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: .35),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: StationLogo(station: s, size: 200, radius: 24),
                  ),
                  if (status == StreamStatus.vpn)
                    const Positioned(right: 10, bottom: 10, child: VpnBadge()),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(s.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              player.error != null
                  ? player.error!
                  : player.buffering && player.playing
                      ? tr('buffering')
                      : player.nowPlaying,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: player.error != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            if (status == StreamStatus.vpn) ...[
              const SizedBox(height: 8),
              Text(tr('vpnHint'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFFFF8F00))),
            ],
            const SizedBox(height: 16),
            const PlayerControls(),
            const SizedBox(height: 16),
            _InfoCard(title: tr('stationInfo'), rows: [
              _row(tr('country'), countryLabelForCode(s.countryCode)),
              _row(tr('languageInfo'), s.language),
              _row(tr('genres'), s.tagList.join(', ')),
              _row(tr('votes'), s.votes > 0 ? '${s.votes}' : ''),
              _row(tr('homepage'), s.homepage, link: true),
              _row(tr('source'),
                  s.source == 'rb' ? 'radio-browser.info' : 'GitHub'),
            ]),
            const SizedBox(height: 12),
            _InfoCard(title: tr('streamInfo'), rows: [
              _row(tr('status'), _statusText(status)),
              _row(
                  tr('codec'),
                  (player.streamInfo['codec'] ?? '').isNotEmpty
                      ? player.streamInfo['codec']!
                      : s.codec),
              _row(
                  tr('bitrate'),
                  player.audioBitrate != null
                      ? '${(player.audioBitrate! / 1000).round()} kbps'
                      : s.bitrate > 0
                          ? '${s.bitrate} kbps'
                          : ''),
              _row(
                  tr('samplerate'),
                  player.sampleRate != null
                      ? '${player.sampleRate} Hz'
                          '${player.channels != null ? ' · ${player.channels} ch' : ''}'
                      : ''),
              _row('ICY name', player.streamInfo['icy-name'] ?? ''),
              _row('ICY genre', player.streamInfo['icy-genre'] ?? ''),
              _row('ICY info', player.streamInfo['icy-description'] ?? ''),
              _row(tr('stream'), s.url, copy: true),
            ]),
          ],
        );
      },
    );
  }

  static String _statusText(StreamStatus st) => switch (st) {
        StreamStatus.ok => tr('stOk'),
        StreamStatus.vpn => tr('stVpn'),
        StreamStatus.dead => tr('stDead'),
        StreamStatus.unknown => tr('stUnknown'),
      };

  static _InfoRow _row(String k, String v,
          {bool link = false, bool copy = false}) =>
      _InfoRow(k, v.trim(), link: link, copy: copy);
}

class _InfoRow {
  final String label;
  final String value;
  final bool link;
  final bool copy;
  _InfoRow(this.label, this.value, {this.link = false, this.copy = false});
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = rows.where((r) => r.value.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            for (final r in visible)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(r.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    Expanded(child: _value(context, r)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _value(BuildContext context, _InfoRow r) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (r.link && r.value.startsWith('http')) {
      return InkWell(
        onTap: () => launchUrl(Uri.parse(r.value),
            mode: LaunchMode.externalApplication),
        child: Text(r.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline)),
      );
    }
    if (r.copy) {
      return InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: r.value));
          ScaffoldMessenger.maybeOf(context)
              ?.showSnackBar(SnackBar(content: Text(tr('copied'))));
        },
        child: Row(children: [
          Expanded(
              child: Text(r.value,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: style)),
          const Icon(Icons.copy_rounded, size: 14),
        ]),
      );
    }
    return SelectableText(r.value, style: style);
  }
}

/// Compact player bar at the bottom of the screen (phones / small windows).
class MiniPlayerBar extends StatelessWidget {
  final VoidCallback onOpen;
  const MiniPlayerBar({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, repo]),
      builder: (context, _) {
        final s = player.current;
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.surfaceContainerHighest,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: s == null ? null : onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(children: [
                  if (s != null)
                    Stack(children: [
                      StationLogo(station: s, size: 48, radius: 10),
                      if (repo.statusOf(s) == StreamStatus.vpn)
                        const Positioned(right: 0, bottom: 0, child: VpnBadge()),
                    ])
                  else
                    Icon(Icons.radio_rounded,
                        size: 40, color: theme.colorScheme.outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s?.name ?? tr('nothingPlaying'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (s != null)
                          Text(
                            player.error ??
                                (player.buffering && player.playing
                                    ? tr('buffering')
                                    : player.nowPlaying),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: player.error != null
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary),
                          ),
                      ],
                    ),
                  ),
                  const PlayerControls(compact: true),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
