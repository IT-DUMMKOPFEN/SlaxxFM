import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/audio_analyzer.dart';
import '../brand.dart';
import 'effects.dart';

// ============================================================ oscilloscope
/// Green CRT oscilloscope with grid and phosphor glow.
class ScopeEffect extends VisEffect {
  double _phase = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _phase += a.dt * (3 + a.level * 6);
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF02140A));
    final grid = Paint()
      ..color = const Color(0xFF0E4A2A)
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      final x = size.width * i / 10;
      c.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      c.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    const pts = 240;
    final cy = size.height / 2;
    for (var i = 0; i <= pts; i++) {
      final x = i / pts;
      var y = 0.0;
      for (var k = 0; k < 8; k++) {
        y += a.bands[k * 4] *
            math.sin(x * math.pi * (3 + k * 5) + _phase * (1 + k * .7));
      }
      final py = cy + y / 4 * size.height * .42 * (.3 + a.level);
      if (i == 0) {
        path.moveTo(0, py);
      } else {
        path.lineTo(x * size.width, py);
      }
    }
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = const Color(0xFF39FF88).withValues(alpha: .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF9DFFC2));
  }
}

// ============================================================ circle wave
/// Circular waveform that breathes with the bass.
class CircleWaveEffect extends VisEffect {
  double _rot = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _rot += a.dt * (.3 + a.level);
    final center = size.center(Offset.zero);
    final base = size.shortestSide * (.24 + a.beat * .04);
    for (var ring = 0; ring < 3; ring++) {
      final path = Path();
      const pts = 180;
      for (var i = 0; i <= pts; i++) {
        final f = i / pts;
        final ang = f * 2 * math.pi + _rot * (ring.isEven ? 1 : -1);
        final band = bandAt(a, (f < .5 ? f : 1 - f) * 2);
        final r = base * (1 + ring * .22) +
            band * size.shortestSide * .16 * (1 - ring * .25) *
                math.sin(f * math.pi * 16 + a.time * 3 + ring);
        final p = center + Offset(math.cos(ang), math.sin(ang)) * r;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 - ring * .7
            ..blendMode = BlendMode.plus
            ..color = hsv(190 + ring * 60 + a.time * 25, .7, 1, .85));
    }
  }
}

// ================================================================ confetti
class _Conf {
  Offset pos, vel;
  double rot, spin, hue, life;
  _Conf(this.pos, this.vel, this.rot, this.spin, this.hue) : life = 1;
}

class ConfettiEffect extends VisEffect {
  final List<_Conf> _c = [];
  final math.Random _r = math.Random();
  int _lastBeat = -1;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    if (a.beatCount != _lastBeat && a.level > .05) {
      _lastBeat = a.beatCount;
      final n = 20 + (a.level * 40).round();
      for (var i = 0; i < n && _c.length < 600; i++) {
        final fromLeft = _r.nextBool();
        _c.add(_Conf(
            Offset(fromLeft ? 0 : size.width, size.height * .9),
            Offset((fromLeft ? 1 : -1) * (80 + _r.nextDouble() * 220),
                -(220 + _r.nextDouble() * 260)),
            _r.nextDouble() * 6,
            (_r.nextDouble() - .5) * 12,
            _r.nextDouble() * 360));
      }
    }
    final p = Paint();
    for (final q in _c) {
      q.vel = Offset(q.vel.dx * math.pow(.6, a.dt).toDouble(),
          q.vel.dy + 260 * a.dt);
      q.pos += q.vel * a.dt;
      q.rot += q.spin * a.dt;
      q.life -= a.dt * .35;
      c.save();
      c.translate(q.pos.dx, q.pos.dy);
      c.rotate(q.rot);
      p.color = hsv(q.hue, .8, 1, q.life.clamp(0.0, 1.0));
      c.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: 8, height: 4 + 3 * math.sin(q.rot * 2).abs()),
          p);
      c.restore();
    }
    _c.removeWhere((q) => q.life <= 0 || q.pos.dy > size.height + 20);
  }
}

// ============================================================== lava lamp
class LavaEffect extends VisEffect {
  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    c.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height),
              const [Color(0xFF2A0A3A), Color(0xFF5A1036)]));
    final p = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.shortestSide * .05)
      ..blendMode = BlendMode.plus;
    for (var k = 0; k < 9; k++) {
      final x = size.width *
          (.1 + .8 * (.5 + .5 * math.sin(a.time * (.13 + k * .03) + k * 2.1)));
      final y = size.height *
          (.5 + .45 * math.sin(a.time * (.21 + k * .04) + k * 1.3));
      final r = size.shortestSide *
          (.08 + .05 * math.sin(a.time * .5 + k) + .07 * a.bands[k * 3]);
      p.color = hsv(10 + k * 12 + a.time * 6, .85, 1, .75);
      c.drawCircle(Offset(x, y), r, p);
    }
  }
}

// ================================================================ sunburst
class SunburstEffect extends VisEffect {
  double _rot = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _rot += a.dt * (.2 + a.level * .8);
    final center = Offset(size.width / 2, size.height * .62);
    final len = size.longestSide;
    const rays = 24;
    for (var i = 0; i < rays; i++) {
      final ang = _rot + i * 2 * math.pi / rays;
      final w = .07 + bandAt(a, i / rays) * .06;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(ang - w) * len,
            center.dy + math.sin(ang - w) * len)
        ..lineTo(center.dx + math.cos(ang + w) * len,
            center.dy + math.sin(ang + w) * len)
        ..close();
      c.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.radial(center, len * .7, [
              hsv(35 + (i.isEven ? 0 : 20), .8, 1, .55 + .3 * a.beat),
              Colors.transparent,
            ]));
    }
    c.drawCircle(
        center,
        size.shortestSide * (.12 + .04 * a.level),
        Paint()
          ..shader = ui.Gradient.radial(center, size.shortestSide * .16, [
            Colors.white,
            const Color(0xFFFFC94D),
            Colors.transparent,
          ], const [
            0,
            .55,
            1
          ]));
  }
}

// ================================================================ hex grid
class HexGridEffect extends VisEffect {
  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final r = math.max(14.0, size.shortestSide / 9);
    final w = r * math.sqrt(3);
    final cols = (size.width / w).ceil() + 1;
    final rows = (size.height / (r * 1.5)).ceil() + 1;
    final center = size.center(Offset.zero);
    final p = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = kBrandSky.withValues(alpha: .35);
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final cx = col * w + (row.isOdd ? w / 2 : 0);
        final cy = row * r * 1.5;
        final d = (Offset(cx, cy) - center).distance / size.longestSide;
        final wave = .5 + .5 * math.sin(d * 18 - a.time * 4 - a.beatCount * .8);
        final v = (bandAt(a, d * 1.6) * .7 + wave * .5 * a.level).clamp(0.0, 1.0);
        final path = Path();
        for (var k = 0; k < 6; k++) {
          final ang = math.pi / 6 + k * math.pi / 3;
          final pt = Offset(cx + math.cos(ang) * r * .92, cy + math.sin(ang) * r * .92);
          if (k == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        p.color = hsv(200 + d * 160 + a.time * 15, .7, .25 + v * .75, .35 + v * .6);
        c.drawPath(path, p);
        c.drawPath(path, stroke);
      }
    }
  }
}

// ================================================================== flower
/// Rotating rose curves (r = cos(k*theta)) in many colours.
class FlowerEffect extends VisEffect {
  double _rot = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _rot += a.dt * (.25 + a.level * .7);
    final center = size.center(Offset.zero);
    final m = size.shortestSide * .46;
    for (var layer = 0; layer < 4; layer++) {
      final k = 3 + layer * 2;
      final amp = m * (.45 + .55 * a.bands[layer * 7] + .1 * a.beat);
      final path = Path();
      const pts = 360;
      for (var i = 0; i <= pts; i++) {
        final t = i / pts * 2 * math.pi;
        final r = amp * math.cos(k * t);
        final ang = t + _rot * (layer.isEven ? 1 : -1);
        final p = center + Offset(math.cos(ang), math.sin(ang)) * r;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..blendMode = BlendMode.plus
            ..color = hsv(a.time * 30 + layer * 70, .75, 1, .7));
    }
  }
}

// =================================================================== helix
/// Rotating DNA double helix.
class HelixEffect extends VisEffect {
  double _phase = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _phase += a.dt * (1.2 + a.level * 3);
    final cy = size.height / 2;
    final amp = size.height * (.28 + .1 * a.level);
    const n = 40;
    final rung = Paint()..strokeWidth = 2;
    for (var i = 0; i < n; i++) {
      final x = size.width * (i + .5) / n;
      final ang = i * .45 + _phase;
      final y1 = cy + math.sin(ang) * amp;
      final y2 = cy - math.sin(ang) * amp;
      final depth = math.cos(ang); // -1 back .. 1 front
      final band = a.bands[(i * 31 ~/ n)];
      rung.color = hsv(180 + i * 4, .5, 1, .25 + .5 * band);
      c.drawLine(Offset(x, y1), Offset(x, y2), rung);
      final r1 = 3 + 3 * (1 + depth) + band * 5;
      final r2 = 3 + 3 * (1 - depth) + band * 5;
      c.drawCircle(Offset(x, y1), r1,
          Paint()..color = hsv(200 + i * 3, .75, 1, .55 + .45 * (depth + 1) / 2));
      c.drawCircle(Offset(x, y2), r2,
          Paint()..color = hsv(320 + i * 2, .75, 1, .55 + .45 * (1 - depth) / 2));
    }
  }
}

// ==================================================================== fire
class _Flame {
  double x, y, vx, vy, life, size;
  _Flame(this.x, this.y, this.vx, this.vy, this.size) : life = 1;
}

class FireEffect extends VisEffect {
  final List<_Flame> _f = [];
  final math.Random _r = math.Random();

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final spawn = (40 + a.level * 160 + a.beat * 120) * a.dt;
    var n = spawn.floor() + (_r.nextDouble() < spawn % 1 ? 1 : 0);
    while (n-- > 0 && _f.length < 500) {
      final x = _r.nextDouble();
      final band = bandAt(a, (x - .5).abs() * 2);
      _f.add(_Flame(
          x * size.width,
          size.height + 5,
          (_r.nextDouble() - .5) * 30,
          -(60 + _r.nextDouble() * 90) * (.6 + band),
          size.shortestSide * (.05 + _r.nextDouble() * .06)));
    }
    final p = Paint()
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (final q in _f) {
      q.x += q.vx * a.dt + math.sin(a.time * 3 + q.y * .05) * 12 * a.dt;
      q.y += q.vy * a.dt;
      q.life -= a.dt * .9;
      final l = q.life.clamp(0.0, 1.0);
      // white-yellow -> orange -> red as it cools down
      p.color = hsv(10 + 45 * l, 1 - .6 * l * l, 1, l * .6);
      c.drawCircle(Offset(q.x, q.y), q.size * (.4 + .6 * l), p);
    }
    _f.removeWhere((q) => q.life <= 0);
  }
}

// ================================================================ fountain
class _Drop {
  Offset pos, vel;
  double hue, life;
  _Drop(this.pos, this.vel, this.hue) : life = 1;
}

class FountainEffect extends VisEffect {
  final List<_Drop> _d = [];
  final math.Random _r = math.Random();

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    const jets = 5;
    final spawn = (60 + a.level * 220) * a.dt;
    var n = spawn.floor() + (_r.nextDouble() < spawn % 1 ? 1 : 0);
    while (n-- > 0 && _d.length < 900) {
      final j = _r.nextInt(jets);
      final x = size.width * (j + .5) / jets;
      final power = (.45 + bandAt(a, j / (jets - 1)) * .8 + a.beat * .3) *
          size.height * 1.9;
      final ang = -math.pi / 2 + (_r.nextDouble() - .5) * .35;
      _d.add(_Drop(Offset(x, size.height),
          Offset(math.cos(ang), math.sin(ang)) * power, 190 + j * 30.0));
    }
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2
      ..blendMode = BlendMode.plus;
    final g = size.height * 3.2;
    for (final q in _d) {
      q.vel = q.vel + Offset(0, g * a.dt);
      q.pos += q.vel * a.dt;
      q.life -= a.dt * .5;
      p.color = hsv(q.hue, .6, 1, q.life.clamp(0.0, 1.0));
      c.drawLine(q.pos - q.vel * .02, q.pos, p);
    }
    _d.removeWhere((q) => q.pos.dy > size.height + 10 || q.life <= 0);
  }
}

// ================================================================ 3D bars
/// Isometric 3D equalizer blocks.
class Bars3dEffect extends VisEffect {
  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    const n = 16;
    final w = size.width / (n + 3);
    final depth = w * .55;
    final base = size.height - 12;
    for (var i = 0; i < n; i++) {
      final v = bandAt(a, i / (n - 1));
      final h = math.max(4.0, v * (size.height - depth - 24));
      final x = w * (i + 1);
      final hue = 200 + i * 9.0;
      final front = Rect.fromLTWH(x, base - h, w * .8, h);
      c.drawRect(front, Paint()..color = hsv(hue, .7, .85));
      final top = Path()
        ..moveTo(front.left, front.top)
        ..lineTo(front.left + depth, front.top - depth * .6)
        ..lineTo(front.right + depth, front.top - depth * .6)
        ..lineTo(front.right, front.top)
        ..close();
      c.drawPath(top, Paint()..color = hsv(hue, .45, 1));
      final side = Path()
        ..moveTo(front.right, front.top)
        ..lineTo(front.right + depth, front.top - depth * .6)
        ..lineTo(front.right + depth, front.bottom - depth * .6)
        ..lineTo(front.right, front.bottom)
        ..close();
      c.drawPath(side, Paint()..color = hsv(hue, .8, .55));
    }
  }
}

// ==================================================================== snow
class _Flake {
  double x, y, r, speed, drift;
  _Flake(this.x, this.y, this.r, this.speed, this.drift);
}

/// Calm snowfall that swirls faster with the music.
class SnowEffect extends VisEffect {
  final List<_Flake> _s = [];
  final math.Random _r = math.Random();

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    while (_s.length < 220) {
      _s.add(_Flake(_r.nextDouble() * size.width, _r.nextDouble() * size.height,
          1 + _r.nextDouble() * 3, 15 + _r.nextDouble() * 35, _r.nextDouble() * 6));
    }
    final wind = math.sin(a.time * .3) * 30 + a.beat * 40;
    final p = Paint();
    for (final f in _s) {
      f.y += f.speed * (.6 + a.level * 2) * a.dt;
      f.x += (wind + math.sin(a.time + f.drift) * 15) * a.dt;
      if (f.y > size.height + 5) {
        f.y = -5;
        f.x = _r.nextDouble() * size.width;
      }
      if (f.x < -5) f.x += size.width + 10;
      if (f.x > size.width + 5) f.x -= size.width + 10;
      p.color = Colors.white.withValues(alpha: .5 + .4 * (f.r / 4));
      c.drawCircle(Offset(f.x, f.y), f.r * (1 + a.beat * .3), p);
    }
  }
}
