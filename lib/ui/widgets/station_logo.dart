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
      child = Container(
        color: Colors.white,
        child: Image.network(
          logo,
          width: size,
          height: size,
          fit: BoxFit.contain,
          cacheWidth: (size * dpr).round().clamp(32, 512),
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          headers: const {'User-Agent': 'SlaxxFM/1.0'},
          errorBuilder: (_, __, ___) => fallback,
          frameBuilder: (context, child, frame, sync) =>
              frame == null && !sync ? fallback : child,
        ),
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

  static const _palettes = [
    [Color(0xFFB0228C), Color(0xFF5B2EFF)],
    [Color(0xFFFF6B35), Color(0xFFE91E63)],
    [Color(0xFF00B4DB), Color(0xFF0083B0)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFFC466B), Color(0xFF3F5EFB)],
    [Color(0xFFF7971E), Color(0xFFFFD200)],
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
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
