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

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return Center(child: Text(tr('noStations')));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .78,
      ),
      itemCount: stations.length,
      itemBuilder: (context, i) =>
          StationTile(station: stations[i], queue: stations),
    );
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
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => player.play(station, queue: queue),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) => Center(
                            child: StationLogo(
                                station: station,
                                size: c.biggest.shortestSide),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        station.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: status == StreamStatus.dead
                              ? scheme.outline
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        // keep room for the VPN label
                        padding: EdgeInsets.only(
                            right: status == StreamStatus.vpn ? 34 : 0),
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
                if (status == StreamStatus.vpn)
                  const Positioned(right: 8, bottom: 8, child: VpnBadge()),
                Positioned(
                  right: 2,
                  top: 2,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: fav ? tr('removeFav') : tr('addFav'),
                    icon: Icon(
                      fav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: fav ? Colors.amber : scheme.outline,
                      size: 20,
                    ),
                    onPressed: () => repo.toggleFavorite(station),
                  ),
                ),
                if (isCurrent)
                  Positioned(
                    left: 6,
                    top: 6,
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
