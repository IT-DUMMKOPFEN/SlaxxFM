import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/audio_analyzer.dart';
import '../brand.dart';
import 'effects2.dart';

/// One visualizer effect. Instances keep their own animation state.
abstract class VisEffect {
  void paint(Canvas c, Size size, AudioAnalyzer a);
}

VisEffect createEffect(String id) => switch (id) {
      'rainbow' => RainbowBarsEffect(),
      'radial' => RadialEffect(),
      'stars' => StarfieldEffect(),
      'wave' => WaveEffect(),
      'colorwave' => ColorWaveEffect(),
      'disco' => DiscoLightsEffect(),
      'discoball' => DiscoBallEffect(),
      'fireworks' => FireworksEffect(),
      'lasers' => LasersEffect(),
      'tunnel' => TunnelEffect(),
      'synthwave' => SynthwaveEffect(),
      'vu' => VuMeterEffect(),
      'ripples' => RipplesEffect(),
      'aurora' => AuroraEffect(),
      'kaleido' => KaleidoEffect(),
      'plasma' => PlasmaEffect(),
      'mountains' => MountainsEffect(),
      'bubbles' => BubblesEffect(),
      'spiral' => SpiralEffect(),
      'leds' => LedEffect(),
      'orbits' => OrbitsEffect(),
      _ => BarsEffect(),
    };

Color hsv(double hue, double s, double v, [double a = 1]) =>
    HSVColor.fromAHSV(a.clamp(0.0, 1.0), hue % 360, s.clamp(0.0, 1.0),
            v.clamp(0.0, 1.0))
        .toColor();

/// Band value with linear interpolation (0..1 position).
double bandAt(AudioAnalyzer a, double pos) {
  final n = a.bands.length;
  final x = (pos.clamp(0.0, 1.0)) * (n - 1);
  final i = x.floor();
  final f = x - i;
  final b0 = a.bands[i];
  final b1 = a.bands[math.min(i + 1, n - 1)];
  return b0 + (b1 - b0) * f;
}

// ===================================================================== bars
class BarsEffect extends VisEffect {
  final List<double> _peaks = List.filled(64, 0);

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final n = (size.width / 18).clamp(16, 64).floor();
    final gap = 3.0;
    final w = (size.width - gap * (n + 1)) / n;
    final base = size.height - 8;
    final maxH = size.height * .86;
    final shader = ui.Gradient.linear(
      Offset(0, base),
      Offset(0, base - maxH),
      const [kBrandBlue, Color(0xFF4FD1FF), Colors.white],
      const [0, .6, 1],
    );
    final paint = Paint()..shader = shader;
    final peak = Paint()..color = kBrandSky;
    for (var i = 0; i < n; i++) {
      final v = bandAt(a, i / (n - 1));
      final h = math.max(2.0, v * maxH);
      final x = gap + i * (w + gap);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, base - h, w, h), const Radius.circular(3)),
          paint);
      _peaks[i] = math.max(_peaks[i] - a.dt * .35, v);
      final py = base - _peaks[i] * maxH - 6;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, py, w, 3), const Radius.circular(2)),
          peak);
    }
  }
}

// ============================================================ rainbow bars
class RainbowBarsEffect extends VisEffect {
  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final n = (size.width / 14).clamp(20, 80).floor();
    final gap = 2.0;
    final w = (size.width - gap * (n + 1)) / n;
    final base = size.height * .7;
    final maxH = size.height * .62;
    final p = Paint();
    for (var i = 0; i < n; i++) {
      // mirrored spectrum: bass in the middle
      final pos = (i - (n - 1) / 2).abs() / ((n - 1) / 2);
      final v = bandAt(a, pos);
      final h = math.max(2.0, v * maxH);
      final hue = i / n * 360 + a.time * 50;
      final x = gap + i * (w + gap);
      p.color = hsv(hue, .85, 1);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, base - h, w, h), const Radius.circular(2)),
          p);
      // reflection
      p.color = hsv(hue, .85, 1, .22);
      c.drawRect(Rect.fromLTWH(x, base + 3, w, h * .45), p);
    }
    // beat flash line
    p.color = Colors.white.withValues(alpha: .25 + .5 * a.beat);
    c.drawRect(Rect.fromLTWH(0, base, size.width, 1.5), p);
  }
}

// ================================================================== radial
void drawRadialEq(Canvas c, Offset center, double r0, double maxLen,
    AudioAnalyzer a, double rotation,
    {int spokes = 72, double hueBase = 200, double hueSpread = 160}) {
  final p = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = math.max(2.0, r0 * 2 * math.pi / spokes * .55);
  for (var i = 0; i < spokes; i++) {
    final frac = i / spokes;
    // mirrored around the circle
    final pos = (frac < .5 ? frac : 1 - frac) * 2;
    final v = bandAt(a, pos);
    final ang = rotation + frac * math.pi * 2;
    final dir = Offset(math.cos(ang), math.sin(ang));
    final len = 4 + v * maxLen;
    p.color = hsv(hueBase + pos * hueSpread + a.time * 20, .75, 1, .95);
    c.drawLine(center + dir * r0, center + dir * (r0 + len), p);
  }
}

class RadialEffect extends VisEffect {
  double _rot = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final center = size.center(Offset.zero);
    final m = size.shortestSide;
    _rot += a.dt * (.15 + a.level * .6);
    final r0 = m * .2 * (1 + a.beat * .12);
    // glow
    c.drawCircle(
        center,
        r0 * 1.1,
        Paint()
          ..shader = ui.Gradient.radial(center, r0 * 1.1, [
            kBrandSky.withValues(alpha: .35 + a.beat * .4),
            kBrandBlue.withValues(alpha: .08),
            Colors.transparent,
          ], const [
            0,
            .7,
            1
          ]));
    drawRadialEq(c, center, r0, m * .28, a, _rot);
    c.drawCircle(
        center,
        r0 * .92,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = kBrandSilver.withValues(alpha: .6));
  }
}

// =============================================================== starfield
class _Star {
  double x = 0, y = 0, z = 1;
}

class StarfieldEffect extends VisEffect {
  final List<_Star> _stars = List.generate(260, (_) => _Star());
  final math.Random _r = math.Random();
  double _rot = 0;
  bool _init = false;

  void _spawn(_Star s, {bool anyZ = false}) {
    s.x = (_r.nextDouble() * 2 - 1);
    s.y = (_r.nextDouble() * 2 - 1);
    s.z = anyZ ? _r.nextDouble() : 1;
  }

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    if (!_init) {
      for (final s in _stars) {
        _spawn(s, anyZ: true);
      }
      _init = true;
    }
    final center = size.center(Offset.zero);
    final scale = size.longestSide * .5;
    final speed = .12 + a.level * .9 + a.beat * .7;
    final p = Paint()..strokeCap = StrokeCap.round;
    for (final s in _stars) {
      final prevZ = s.z;
      s.z -= speed * a.dt;
      if (s.z <= .03) {
        _spawn(s);
        continue;
      }
      final p1 = center + Offset(s.x / s.z, s.y / s.z) * scale;
      final p0 = center +
          Offset(s.x / (prevZ + speed * .06), s.y / (prevZ + speed * .06)) *
              scale;
      if (p1.dx < -20 ||
          p1.dy < -20 ||
          p1.dx > size.width + 20 ||
          p1.dy > size.height + 20) {
        _spawn(s);
        continue;
      }
      final b = (1 - s.z).clamp(0.0, 1.0);
      p
        ..color = Color.lerp(kBrandSky, Colors.white, b)!.withValues(alpha: b)
        ..strokeWidth = .6 + b * 2.4;
      c.drawLine(p0, p1, p);
    }
    _rot += a.dt * (.6 + a.level * 1.4);
    final m = size.shortestSide;
    drawRadialEq(c, center, m * .13 * (1 + a.beat * .15), m * .2, a, _rot,
        spokes: 60, hueBase: 190, hueSpread: 120);
    drawRadialEq(c, center, m * .1, m * .08, a, -_rot * 1.5,
        spokes: 40, hueBase: 280, hueSpread: 80);
  }
}

// ==================================================================== wave
class WaveEffect extends VisEffect {
  double _phase = 0;

  Path _path(Size size, AudioAnalyzer a, double amp, double shift) {
    final path = Path();
    const pts = 180;
    final cy = size.height / 2;
    for (var i = 0; i <= pts; i++) {
      final x = i / pts;
      var y = 0.0;
      for (var k = 0; k < 6; k++) {
        final band = a.bands[k * 5];
        y += band *
            math.sin(x * math.pi * (2 + k * 3) + _phase * (1 + k * .4) + shift);
      }
      // taper at the edges
      final env = math.sin(x * math.pi);
      final px = x * size.width;
      final py = cy + y / 3 * amp * env;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    return path;
  }

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _phase += a.dt * (2 + a.level * 4);
    final amp = size.height * .45 * (.3 + a.level);
    final main = _path(size, a, amp, 0);
    c.drawPath(
        main,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..color = kBrandBlue.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    c.drawPath(
        _path(size, a, amp * .7, 1.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = kBrandSilver.withValues(alpha: .45));
    c.drawPath(
        main,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, 0), [
            kBrandBlue,
            kBrandSky,
            Colors.white,
            kBrandSky,
            kBrandBlue
          ], const [
            0,
            .3,
            .5,
            .7,
            1
          ]));
  }
}

// ============================================================ colour waves
class ColorWaveEffect extends VisEffect {
  double _phase = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _phase += a.dt * (1 + a.level * 2.5);
    const layers = 7;
    for (var k = 0; k < layers; k++) {
      final band = a.bands[(k * 4) % a.bands.length];
      final amp = size.height * (.08 + .22 * band + .05 * a.beat);
      final base = size.height * (.35 + k * .085);
      final path = Path()..moveTo(0, size.height);
      const pts = 90;
      for (var i = 0; i <= pts; i++) {
        final x = i / pts;
        final y = base +
            amp *
                math.sin(x * math.pi * (1.5 + k * .45) +
                    _phase * (.8 + k * .23) +
                    k) +
            amp * .35 * math.sin(x * math.pi * 6 - _phase * 1.7 + k * 2);
        path.lineTo(x * size.width, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      final hue = a.time * 25 + k * 48;
      c.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
                Offset(0, base - amp), Offset(0, size.height), [
              hsv(hue, .8, 1, .55),
              hsv(hue + 40, .9, .6, .15),
            ])
            ..blendMode = BlendMode.plus);
    }
  }
}

// ============================================================ disco lights
class DiscoLightsEffect extends VisEffect {
  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    const beams = 6;
    final p = Paint()..blendMode = BlendMode.plus;
    final len = size.height * 1.25;
    for (var k = 0; k < beams; k++) {
      final ox = size.width * (k + .5) / beams;
      final origin = Offset(ox, -6);
      final ang = math.pi / 2 +
          math.sin(a.time * (.6 + k * .17) + k * 1.3) * .75 +
          (k.isEven ? 1 : -1) * a.beat * .08;
      final spread = .11 + .05 * a.level;
      final hue = k * 60 + a.beatCount * 37.0;
      final intensity = (.25 + .55 * a.level + .3 * a.beat).clamp(0.0, 1.0);
      final l = Offset(math.cos(ang - spread), math.sin(ang - spread)) * len;
      final r = Offset(math.cos(ang + spread), math.sin(ang + spread)) * len;
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(origin.dx + l.dx, origin.dy + l.dy)
        ..lineTo(origin.dx + r.dx, origin.dy + r.dy)
        ..close();
      p.shader = ui.Gradient.radial(origin, len, [
        hsv(hue, .8, 1, intensity * .75),
        hsv(hue, .9, 1, intensity * .15),
        Colors.transparent,
      ], const [
        0,
        .7,
        1
      ]);
      c.drawPath(path, p);
      // spot on the floor
      final dir = Offset(math.cos(ang), math.sin(ang));
      if (dir.dy > .2) {
        final t = (size.height - origin.dy) / dir.dy;
        final spot = origin + dir * t;
        p.shader = ui.Gradient.radial(spot, size.width * .12, [
          hsv(hue, .6, 1, intensity * .8),
          Colors.transparent,
        ]);
        c.drawOval(
            Rect.fromCenter(
                center: spot, width: size.width * .24, height: 30),
            p);
      }
    }
    // lamp heads
    final head = Paint()..color = kBrandSilver;
    for (var k = 0; k < beams; k++) {
      final ox = size.width * (k + .5) / beams;
      c.drawCircle(Offset(ox, 0), 7, head);
    }
  }
}

// =============================================================== disco ball
class DiscoBallEffect extends VisEffect {
  double _rot = 0;
  final math.Random _r = math.Random(7);
  late final List<double> _spotAng =
      List.generate(48, (_) => _r.nextDouble() * math.pi * 2);
  late final List<double> _spotRad =
      List.generate(48, (_) => .25 + _r.nextDouble() * .8);
  late final List<double> _spotHue =
      List.generate(48, (_) => _r.nextBool() ? 200.0 : _r.nextDouble() * 360);

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _rot += a.dt * (.4 + a.level * .8);
    final rBall = size.shortestSide * .17;
    final center = Offset(size.width / 2, rBall + 26);

    // reflections flying around the room
    final spot = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < _spotAng.length; i++) {
      final ang = _spotAng[i] + _rot * (i.isEven ? 1 : .7);
      final rx = size.width * .55 * _spotRad[i];
      final ry = size.height * .6 * _spotRad[i];
      final pos = Offset(center.dx + math.cos(ang) * rx,
          center.dy + rBall * .6 + math.sin(ang) * ry);
      final alpha = (.25 + .5 * a.level + .3 * a.beat) *
          (.5 + .5 * math.sin(a.time * 3 + i));
      spot.color = hsv(_spotHue[i], .35, 1, alpha);
      c.drawCircle(pos, 2.5 + 3 * a.level, spot);
    }

    // string
    c.drawLine(Offset(center.dx, 0), Offset(center.dx, center.dy - rBall),
        Paint()
          ..color = kBrandSilver.withValues(alpha: .7)
          ..strokeWidth = 2);

    // ball body
    c.drawCircle(
        center,
        rBall,
        Paint()
          ..shader = ui.Gradient.radial(
              center - Offset(rBall * .35, rBall * .35), rBall * 1.4, [
            const Color(0xFFE8EEF5),
            const Color(0xFF7D8DA3),
            const Color(0xFF2A3446),
          ], const [
            0,
            .5,
            1
          ]));
    // mirror facets
    const rows = 12, cols = 22;
    final facet = Paint();
    for (var r = 0; r < rows; r++) {
      final lat = -math.pi / 2 + (r + .5) * math.pi / rows;
      final cl = math.cos(lat);
      for (var q = 0; q < cols; q++) {
        final lon = q * 2 * math.pi / cols + _rot;
        final front = math.cos(lon);
        if (front <= 0.05) continue;
        final x = center.dx + rBall * cl * math.sin(lon);
        final y = center.dy + rBall * math.sin(lat);
        final w = rBall * 2 * math.pi / cols * cl * front * .42;
        final h = rBall * math.pi / rows * .42;
        final flicker = .5 + .5 * math.sin(a.time * 5 + r * 3.1 + q * 1.7);
        final bright = (.35 + .45 * front * flicker + .4 * a.beat * flicker)
            .clamp(0.0, 1.0);
        facet.color = Color.lerp(
            const Color(0xFF3C4A60), Colors.white, bright)!;
        c.drawRect(Rect.fromCenter(center: Offset(x, y), width: w * 2, height: h * 2),
            facet);
      }
    }
    // sparkle on the beat
    if (a.beat > .3) {
      final sp = Paint()
        ..color = Colors.white.withValues(alpha: a.beat)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final s = center + Offset(-rBall * .35, -rBall * .4);
      final l = rBall * .5 * a.beat;
      c.drawLine(s - Offset(l, 0), s + Offset(l, 0), sp);
      c.drawLine(s - Offset(0, l), s + Offset(0, l), sp);
    }
  }
}

// =============================================================== fireworks
class _Particle {
  Offset pos;
  Offset vel;
  double life;
  final double hue;
  _Particle(this.pos, this.vel, this.life, this.hue);
}

class FireworksEffect extends VisEffect {
  final List<_Particle> _parts = [];
  final math.Random _r = math.Random();
  int _lastBeat = -1;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    if (a.beatCount != _lastBeat && a.level > .05) {
      _lastBeat = a.beatCount;
      final origin = Offset(size.width * (.15 + _r.nextDouble() * .7),
          size.height * (.15 + _r.nextDouble() * .45));
      final hue = _r.nextDouble() * 360;
      final count = 30 + (a.level * 50).round();
      for (var i = 0; i < count; i++) {
        final ang = _r.nextDouble() * math.pi * 2;
        final sp = (60 + _r.nextDouble() * 140) * (.6 + a.level);
        _parts.add(_Particle(origin, Offset(math.cos(ang), math.sin(ang)) * sp,
            1, hue + _r.nextDouble() * 40));
      }
      if (_parts.length > 900) _parts.removeRange(0, _parts.length - 900);
    }
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    for (final q in _parts) {
      q.vel = q.vel * math.pow(.35, a.dt).toDouble() + Offset(0, 70 * a.dt);
      q.pos += q.vel * a.dt;
      q.life -= a.dt * .7;
      if (q.life <= 0) continue;
      p
        ..color = hsv(q.hue, .7, 1, q.life)
        ..strokeWidth = 1 + 2 * q.life;
      c.drawLine(q.pos - q.vel * .06, q.pos, p);
    }
    _parts.removeWhere((q) => q.life <= 0);
  }
}
