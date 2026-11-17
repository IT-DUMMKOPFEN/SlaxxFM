import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n.dart';
import '../../models/station.dart';
import '../../services/player_service.dart';
import '../../services/station_repository.dart';
import '../visualizer/visualizer.dart';
import 'country_list.dart';
import 'station_grid.dart' show VpnBadge;
import 'station_logo.dart';

/// Rebuilds [child] builder whenever the player or the station list changes.
Widget _live(Widget Function(BuildContext) build) => ListenableBuilder(
    listenable: Listenable.merge([player, repo]),
    builder: (context, _) => build(context));

bool get _loading => player.active && (player.buffering || !player.playing);

String _subtitle() {
  if (player.current == null) return '';
  if (player.error != null && !player.playing) return player.error!;
  if (_loading) return tr('buffering');
  return player.nowPlaying;
}

/// Play/pause button (shows a spinner while connecting).
class PlayButton extends StatelessWidget {
  final double size;
  const PlayButton({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => _live(_build);

  Widget _build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      iconSize: size,
      tooltip: player.active ? tr('pause') : tr('play'),
      onPressed: player.current == null && player.recentIsEmpty
          ? null
          : player.togglePlay,
      icon: _loading
          ? SizedBox(
              width: size,
              height: size,
              child: Padding(
                padding: EdgeInsets.all(size * .16),
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: scheme.onPrimary),
              ),
            )
          : Icon(player.active ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }
}

class MuteButton extends StatelessWidget {
  const MuteButton({super.key});

  @override
  Widget build(BuildContext context) => _live(_build);

  Widget _build(BuildContext context) {
    final muted = player.muted;
    return IconButton(
      tooltip: muted ? tr('unmute') : tr('mute'),
      isSelected: muted,
      onPressed: player.toggleMute,
      color: muted ? Theme.of(context).colorScheme.error : null,
      icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
    );
  }
}

/// Volume slider with − / + buttons.
class VolumeSlider extends StatelessWidget {
  final double width;
  final bool compact;
  const VolumeSlider({super.key, this.width = 170, this.compact = false});

  @override
  Widget build(BuildContext context) => _live(_build);

  Widget _build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (!compact)
        IconButton(
            tooltip: tr('quieter'),
            onPressed: player.quieter,
            icon: const Icon(Icons.remove_rounded, size: 18)),
      SizedBox(
        width: width,
        child: Slider(
          value: player.volume.clamp(0, 100).toDouble(),
          min: 0,
          max: 100,
          label: '${player.volume.round()} %',
          divisions: 20,
          onChanged: player.setVolume,
        ),
      ),
      if (!compact)
        IconButton(
            tooltip: tr('louder'),
            onPressed: player.louder,
            icon: const Icon(Icons.add_rounded, size: 18)),
      SizedBox(
        width: 34,
        child: Text('${player.volume.round()}',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium),
      ),
    ]);
  }
}

/// Stop / previous / play / next (+ favourite).
class TransportButtons extends StatelessWidget {
  final double size;
  final bool withFavorite;
  const TransportButtons({super.key, this.size = 40, this.withFavorite = false});

  @override
  Widget build(BuildContext context) => _live(_build);

  Widget _build(BuildContext context) {
    final s = player.current;
    final has = s != null;
    final fav = has && repo.isFavorite(s);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          tooltip: tr('stop'),
          onPressed: has ? player.stop : null,
          icon: const Icon(Icons.stop_rounded)),
      IconButton(
          tooltip: tr('previous'),
          onPressed: has ? player.previous : null,
          icon: const Icon(Icons.skip_previous_rounded)),
      const SizedBox(width: 4),
      PlayButton(size: size),
      const SizedBox(width: 4),
      IconButton(
          tooltip: tr('next'),
          onPressed: has ? player.next : null,
          icon: const Icon(Icons.skip_next_rounded)),
      if (withFavorite)
        IconButton(
          tooltip: fav ? tr('removeFav') : tr('addFav'),
          onPressed: has ? () => repo.toggleFavorite(s) : null,
          color: fav ? Colors.amber : null,
          icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded),
        ),
    ]);
  }
}

/// Full controls for the phone player sheet.
class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([player, repo]),
        builder: (context, _) => Column(children: [
          const TransportButtons(withFavorite: true),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) => Row(children: [
              Expanded(
                child: VolumeSlider(width: (c.maxWidth - 190).clamp(80.0, 400.0)),
              ),
              const MuteButton(),
            ]),
          ),
        ]),
      );
}

/// Bottom player bar (tablet / desktop). Volume + mute bottom right.
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, repo]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final s = player.current;
        final wide = MediaQuery.sizeOf(context).width >= 1000;
        return Material(
          color: theme.colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Container(
              height: 84,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: Row(children: [
                // station
                Expanded(
                  child: Row(children: [
                    if (s != null)
                      StationLogo(station: s, size: 56, radius: 12)
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset('assets/logo.png',
                            width: 56, height: 56),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s?.name ?? tr('nothingPlaying'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          if (s != null)
                            Text(_subtitle(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: player.error != null &&
                                            !player.playing
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.primary)),
                        ],
                      ),
                    ),
                    if (s != null && repo.statusOf(s) == StreamStatus.vpn)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: VpnBadge(),
                      ),
                  ]),
                ),
                const SizedBox(width: 12),
                const TransportButtons(withFavorite: true),
                const SizedBox(width: 16),
                // volume + mute, bottom right
                VolumeSlider(width: wide ? 170 : 90, compact: !wide),
                const MuteButton(),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// Picture, station information and the big visualizer.
class PlayerPanel extends StatelessWidget {
  /// Phone sheet: also show the controls.
  final bool withControls;
  const PlayerPanel({super.key, this.withControls = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, repo]),
      builder: (context, _) {
        final s = player.current;
        final theme = Theme.of(context);
        final status = s == null ? StreamStatus.unknown : repo.statusOf(s);
        final header = Row(children: [
          Stack(children: [
            if (s != null)
              StationLogo(station: s, size: 112, radius: 18)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child:
                    Image.asset('assets/logo.png', width: 112, height: 112),
              ),
            if (status == StreamStatus.vpn)
              const Positioned(right: 6, bottom: 6, child: VpnBadge()),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s?.name ?? tr('nothingPlaying'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                if (s != null) ...[
                  const SizedBox(height: 4),
                  Text(countryLabelForCode(s.countryCode),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(_subtitle(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: player.error != null && !player.playing
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary)),
                ],
                if (status == StreamStatus.vpn) ...[
                  const SizedBox(height: 4),
                  Text(tr('vpnHint'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFFFF8F00))),
                ],
              ],
            ),
          ),
        ]);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (withControls) ...[
                const SizedBox(height: 12),
                const PlayerControls(),
              ],
              if (s != null)
                Flexible(
                  child: SingleChildScrollView(
                    child: _Details(station: s, status: status),
                  ),
                ),
              const SizedBox(height: 12),
              const Expanded(flex: 2, child: Visualizer()),
            ],
          ),
        );
      },
    );
  }
}

class _Details extends StatelessWidget {
  final Station station;
  final StreamStatus status;
  const _Details({required this.station, required this.status});

  static String _statusText(StreamStatus st) => switch (st) {
        StreamStatus.ok => tr('stOk'),
        StreamStatus.vpn => tr('stVpn'),
        StreamStatus.dead => tr('stDead'),
        StreamStatus.unknown => tr('stUnknown'),
      };

  @override
  Widget build(BuildContext context) {
    final s = station;
    final theme = Theme.of(context);
    final codec = (player.streamInfo['codec'] ?? '').isNotEmpty
        ? player.streamInfo['codec']!
        : s.codec;
    final bitrate = player.audioBitrate != null
        ? '${(player.audioBitrate! / 1000).round()} kbps'
        : s.bitrate > 0
            ? '${s.bitrate} kbps'
            : '';
    final rate = player.sampleRate != null
        ? '${player.sampleRate} Hz${player.channels != null ? ' · ${player.channels} ch' : ''}'
        : '';
    final rows = <_InfoRow>[
      _InfoRow(tr('languageInfo'), s.language),
      _InfoRow(tr('genres'), s.tagList.join(', ')),
      _InfoRow(tr('homepage'), s.homepage, link: true),
      _InfoRow(tr('status'), _statusText(status)),
      _InfoRow(tr('codec'), codec),
      _InfoRow(tr('bitrate'), bitrate),
      _InfoRow(tr('samplerate'), rate),
      _InfoRow('ICY name', player.streamInfo['icy-name'] ?? ''),
      _InfoRow('ICY genre', player.streamInfo['icy-genre'] ?? ''),
      _InfoRow(tr('votes'), s.votes > 0 ? '${s.votes}' : ''),
      _InfoRow(tr('source'), s.source == 'rb' ? 'radio-browser.info' : 'GitHub'),
      _InfoRow(tr('stream'), s.url, copy: true),
    ].where((r) => r.value.trim().isNotEmpty).toList();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 12),
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          leading: const Icon(Icons.info_outline_rounded),
          title: Text(tr('details')),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [for (final r in rows) _row(context, r)],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _InfoRow r) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    Widget value;
    if (r.link && r.value.startsWith('http')) {
      value = InkWell(
        onTap: () =>
            launchUrl(Uri.parse(r.value), mode: LaunchMode.externalApplication),
        child: Text(r.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline)),
      );
    } else if (r.copy) {
      value = InkWell(
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
    } else {
      value = SelectableText(r.value, style: style);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 96,
          child: Text(r.label,
              style: style?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(child: value),
      ]),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  final bool link;
  final bool copy;
  _InfoRow(this.label, this.value, {this.link = false, this.copy = false});
}

/// Compact player bar for phones: logo, title, play and mute (right).
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
          color: theme.colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                child: Row(children: [
                  if (s != null)
                    Stack(children: [
                      StationLogo(station: s, size: 48, radius: 10),
                      if (repo.statusOf(s) == StreamStatus.vpn)
                        const Positioned(right: 0, bottom: 0, child: VpnBadge()),
                    ])
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child:
                          Image.asset('assets/logo.png', width: 48, height: 48),
                    ),
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
                          Text(_subtitle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                  const PlayButton(size: 28),
                  const MuteButton(),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
