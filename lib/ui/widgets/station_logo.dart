import 'package:flutter/material.dart';

import '../../models/station.dart';

/// Station picture with a colourful fallback (initials) when the station
/// has no logo or the logo cannot be loaded.
class StationLogo extends StatelessWidget {
  final Station station;
  final double size;
  final double radius;

  const StationLogo(
      {super.key, required this.station, this.size = 64, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final fallback = _Fallback(name: station.name, size: size);
    Widget child = fallback;
    final logo = station.logo;
    if (logo.startsWith('http') && !logo.toLowerCase().endsWith('.svg')) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      // every logo sits in the same white square with the same margin,
      // so all tiles look alike regardless of the image format
      child = Image.network(
        logo,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: (size * dpr).round().clamp(32, 512),
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        headers: const {'User-Agent': 'SlaxxFM/1.0'},
        frameBuilder: (context, img, frame, sync) => frame == null && !sync
            ? fallback
            : Container(
                color: Colors.white,
                padding: EdgeInsets.all(size * .1),
                child: img,
              ),
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String name;
  final double size;
  const _Fallback({required this.name, required this.size});

  // blue tones of the SlaxxFM logo
  static const _palettes = [
    [Color(0xFF0D2547), Color(0xFF2F7FCF)],
    [Color(0xFF123A6B), Color(0xFF4FA3E0)],
    [Color(0xFF1B4A80), Color(0xFF7CC4F2)],
    [Color(0xFF0A1A33), Color(0xFF3B6EA8)],
    [Color(0xFF26446B), Color(0xFF8FA9C8)],
    [Color(0xFF1A2F5A), Color(0xFF5C7FD6)],
    [Color(0xFF0E3550), Color(0xFF3FB3D9)],
  ];

  @override
  Widget build(BuildContext context) {
    final words = name
        .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    var initials = words.take(2).map((w) => w.characters.first).join();
    if (initials.isEmpty) initials = '♪';
    final colors = _palettes[name.hashCode.abs() % _palettes.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
