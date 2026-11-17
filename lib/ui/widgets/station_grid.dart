import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../models/station.dart';
import '../../services/player_service.dart';
import '../../services/station_repository.dart';
import 'station_logo.dart';

class VpnBadge extends StatelessWidget {
  const VpnBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('vpnHint'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFF8F00),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('VPN',
            style: TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .8)),
      ),
    );
  }
}

class StationGrid extends StatelessWidget {
  final List<Station> stations;
  const StationGrid({super.key, required this.stations});

  /// Height of the text block below the logo.
  static const double textBlock = 70;

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return Center(child: Text(tr('noStations')));
    }
    return LayoutBuilder(builder: (context, c) {
      const pad = 16.0, gap = 14.0, target = 178.0;
      final cols = ((c.maxWidth - pad * 2 + gap) / (target + gap))
          .floor()
          .clamp(2, 12);
      final itemW = (c.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
      // square logo area + fixed text block -> every tile identical
      final itemH = (itemW - 24) + textBlock + 24;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(pad, 6, pad, pad),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          mainAxisExtent: itemH,
        ),
        itemCount: stations.length,
        itemBuilder: (context, i) =>
            StationTile(station: stations[i], queue: stations),
      );
    });
  }
}

class StationTile extends StatelessWidget {
  final Station station;
  final List<Station> queue;
  const StationTile(
      {super.key, required this.station, this.queue = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([player, repo]),
      builder: (context, _) {
        final isCurrent = player.current?.id == station.id;
        final status = repo.statusOf(station);
        final fav = repo.isFavorite(station);
        final sub = [
          if (station.tagList.isNotEmpty) station.tagList.take(2).join(', '),
          if (station.bitrate > 0) '${station.bitrate} kbps',
        ].join(' · ');
        return Material(
          color: isCurrent
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => player.play(station, queue: queue),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, c) => StationLogo(
                              station: station,
                              size: c.maxWidth,
                              radius: 14),
                        ),
                      ),
                      SizedBox(
                        height: StationGrid.textBlock,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 38,
                              child: Text(
                                station.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: status == StreamStatus.dead
                                      ? scheme.outline
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              // keep room for the VPN label
                              padding: EdgeInsets.only(
                                  right: status == StreamStatus.vpn ? 36 : 0),
                              child: Text(
                                sub.isEmpty ? ' ' : sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == StreamStatus.vpn)
                  const Positioned(right: 10, bottom: 10, child: VpnBadge()),
                Positioned(
                  right: 14,
                  top: 14,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: .35),
                      minimumSize: const Size(30, 30),
                      padding: EdgeInsets.zero,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: fav ? tr('removeFav') : tr('addFav'),
                    icon: Icon(
                      fav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: fav ? Colors.amber : Colors.white,
                      size: 18,
                    ),
                    onPressed: () => repo.toggleFavorite(station),
                  ),
                ),
                if (isCurrent)
                  Positioned(
                    left: 18,
                    top: 18,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        player.active
                            ? Icons.graphic_eq_rounded
                            : Icons.pause_rounded,
                        size: 14,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
