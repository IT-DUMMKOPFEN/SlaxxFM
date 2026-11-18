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
  static double textBlock(bool compact) => compact ? 34 : 70;

  /// Inner padding of a tile.
  static double tilePad(bool compact) => compact ? 7 : 12;

  /// Smaller windows (and phones) get tiles half the size.
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 1100;

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return Center(child: Text(tr('noStations')));
    }
    final compact = isCompact(context);
    return LayoutBuilder(builder: (context, c) {
      final pad = compact ? 12.0 : 16.0;
      final gap = compact ? 10.0 : 14.0;
      final target = compact ? 92.0 : 178.0;
      final cols = ((c.maxWidth - pad * 2 + gap) / (target + gap))
          .floor()
          .clamp(2, 24);
      final itemW = (c.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
      final tp = tilePad(compact);
      // square logo area + fixed text block -> every tile identical
      final itemH = (itemW - tp * 2) + textBlock(compact) + tp * 2;
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(pad, 6, pad, pad),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          mainAxisExtent: itemH,
        ),
        itemCount: stations.length,
        itemBuilder: (context, i) =>
            StationTile(
                station: stations[i], queue: stations, compact: compact),
      );
    });
  }
}

class StationTile extends StatelessWidget {
  final Station station;
  final List<Station> queue;
  final bool compact;
  const StationTile(
      {super.key,
      required this.station,
      this.queue = const [],
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tp = StationGrid.tilePad(compact);
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
          borderRadius: BorderRadius.circular(compact ? 12 : 20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => player.play(station, queue: queue),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(tp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, c) => StationLogo(
                              station: station,
                              size: c.maxWidth,
                              radius: compact ? 8 : 14),
                        ),
                      ),
                      SizedBox(
                        height: StationGrid.textBlock(compact),
                        child: compact
                            ? Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  station.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                    height: 1.15,
                                    color: status == StreamStatus.dead
                                        ? scheme.outline
                                        : null,
                                  ),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 38,
                                    child: Text(
                                      station.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
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
                                        right: status == StreamStatus.vpn
                                            ? 36
                                            : 0),
                                    child: Text(
                                      sub.isEmpty ? ' ' : sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                if (status == StreamStatus.vpn)
                  compact
                      ? Positioned(
                          left: tp + 3,
                          bottom: StationGrid.textBlock(true) + tp + 3,
                          child: const VpnBadge())
                      : const Positioned(
                          right: 10, bottom: 10, child: VpnBadge()),
                Positioned(
                  right: compact ? tp + 1 : 14,
                  top: compact ? tp + 1 : 14,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: .35),
                      minimumSize: compact ? const Size(22, 22) : const Size(30, 30),
                      tapTargetSize: compact
                          ? MaterialTapTargetSize.shrinkWrap
                          : MaterialTapTargetSize.padded,
                      padding: EdgeInsets.zero,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: fav ? tr('removeFav') : tr('addFav'),
                    icon: Icon(
                      fav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: fav ? Colors.amber : Colors.white,
                      size: compact ? 13 : 18,
                    ),
                    onPressed: () => repo.toggleFavorite(station),
                  ),
                ),
                if (isCurrent)
                  Positioned(
                    left: compact ? tp + 3 : 18,
                    top: compact ? tp + 3 : 18,
                    child: Container(
                      padding: EdgeInsets.all(compact ? 3 : 4),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        player.active
                            ? Icons.graphic_eq_rounded
                            : Icons.pause_rounded,
                        size: compact ? 10 : 14,
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
