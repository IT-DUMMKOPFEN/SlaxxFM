import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/audio_analyzer.dart';
import '../brand.dart';
import 'effects.dart';

// ================================================================== lasers
class LasersEffect extends VisEffect {
  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final origins = [
      Offset(0, size.height),
      Offset(size.width, size.height),
      Offset(size.width / 2, size.height + 10),
    ];
    const perOrigin = 7;
    final glow = Paint()
      ..strokeWidth = 7
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final core = Paint()
      ..strokeWidth = 1.6
      ..blendMode = BlendMode.plus;
    final len = size.longestSide * 1.4;
    for (var o = 0; o < origins.length; o++) {
      final org = origins[o];
      final base = o == 0 ? -math.pi / 4 : o == 1 ? -3 * math.pi / 4 : -math.pi / 2;
      for (var k = 0; k < perOrigin; k++) {
        final f = k / (perOrigin - 1) - .5;
        final ang = base +
            f * (.9 + .5 * a.level) +
            math.sin(a.time * (.7 + o * .2) + k * .5) * .35;
        final hue = (o * 120 + a.beatCount * 25 + k * 8).toDouble();
        final alpha = (.35 + .5 * a.level + .4 * a.beat).clamp(0.0, 1.0);
        final end = org + Offset(math.cos(ang), math.sin(ang)) * len;
        glow.color = hsv(hue, .9, 1, alpha * .6);
        core.color = hsv(hue, .4, 1, alpha);
        c.drawLine(org, end, glow);
        c.drawLine(org, end, core);
      }
    }
    // haze
    c.drawRect(
        Offset.zero & size,
        Paint()
          ..color = kBrandSky.withValues(alpha: .04 + .06 * a.beat)
          ..blendMode = BlendMode.plus);
  }
}

// ================================================================== tunnel
class TunnelEffect extends VisEffect {
  double _z = 0;
  double _rot = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final center = size.center(Offset.zero) +
        Offset(math.sin(a.time * .5) * size.width * .06,
            math.cos(a.time * .4) * size.height * .06);
    _z += a.dt * (.4 + a.level * 1.6 + a.beat);
    _rot += a.dt * (.3 + a.level);
    const rings = 18;
    final maxR = size.longestSide * .9;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    for (var i = rings; i >= 0; i--) {
      final depth = (i - (_z % 1)) / rings; // 0 near .. 1 far
      if (depth <= 0) continue;
      final r = maxR * math.pow(1 - depth, 2.2).toDouble() + 4;
      final band = bandAt(a, 1 - depth);
      final sides = 6;
      final path = Path();
      for (var k = 0; k <= sides; k++) {
        final ang = _rot * (i.isEven ? 1 : -1) + k * 2 * math.pi / sides;
        final rr = r * (1 + band * .18);
        final pt = center + Offset(math.cos(ang), math.sin(ang)) * rr;
        if (k == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      p
        ..strokeWidth = 1 + (1 - depth) * 6
        ..color = hsv(190 + i * 12 + a.time * 30, .7, 1, (1 - depth) * .9);
      c.drawPath(path, p);
    }
  }
}

// =============================================================== synthwave
class SynthwaveEffect extends VisEffect {
  double _scroll = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final horizon = size.height * .55;
    _scroll += a.dt * (.5 + a.level * 1.5);
    // sky
    c.drawRect(
        Rect.fromLTWH(0, 0, size.width, horizon),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, horizon), const [
            Color(0xFF0B0425),
            Color(0xFF3B0F5C),
            Color(0xFFB0306E),
          ], const [
            0,
            .6,
            1
          ]));
    // sun with stripes
    final sunR = size.shortestSide * (.28 + a.level * .05 + a.beat * .03);
    final sunC = Offset(size.width / 2, horizon - sunR * .15);
    c.save();
    c.clipRect(Rect.fromLTWH(0, 0, size.width, horizon));
    final cuts = Path();
    for (var k = 0; k < 7; k++) {
      final y = sunC.dy + sunR * (.05 + k * .13);
      final hgt = 2.0 + k * 1.6;
      cuts.addRect(Rect.fromLTWH(sunC.dx - sunR, y, sunR * 2, hgt));
    }
    final stripes = Path.combine(PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: sunC, radius: sunR)), cuts);
    c.drawPath(
        stripes,
        Paint()
          ..shader = ui.Gradient.linear(sunC - Offset(0, sunR),
              sunC + Offset(0, sunR), const [Color(0xFFFFE259), Color(0xFFFF4E8A)]));
    c.restore();
    // mountains from the spectrum
    final mountain = Path()..moveTo(0, horizon);
    const pts = 40;
    for (var i = 0; i <= pts; i++) {
      final x = i / pts;
      final v = bandAt(a, (x - .5).abs() * 2);
      mountain.lineTo(x * size.width,
          horizon - v * size.height * .22 - (i.isEven ? 6 : 0));
    }
    mountain
      ..lineTo(size.width, horizon)
      ..close();
    c.drawPath(mountain, Paint()..color = const Color(0xFF1A0833));
    c.drawPath(
        mountain,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFF4E8A).withValues(alpha: .8));
    // floor grid
    c.drawRect(Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
        Paint()..color = const Color(0xFF0B0425));
    final grid = Paint()
      ..color = const Color(0xFF29E3FF).withValues(alpha: .65 + .3 * a.beat)
      ..strokeWidth = 1.2;
    final vpx = size.width / 2;
    for (var k = -14; k <= 14; k++) {
      c.drawLine(Offset(vpx + k * 6.0, horizon),
          Offset(vpx + k * size.width * .12, size.height), grid);
    }
    for (var k = 0; k < 14; k++) {
      final f = ((k + (_scroll % 1)) / 14);
      final y = horizon + (size.height - horizon) * f * f;
      c.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }
}

// ================================================================ VU meters
class VuMeterEffect extends VisEffect {
  double _l = 0, _r = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    double side(int from, int to) {
      var s = 0.0;
      for (var i = from; i < to; i++) {
        s += a.bands[i];
      }
      return s / (to - from);
    }

    final tl = (a.level * .7 + side(0, 16) * .5).clamp(0.0, 1.0);
    final tr = (a.level * .7 + side(16, 32) * .6).clamp(0.0, 1.0);
    _l += (tl - _l) * math.min(1, a.dt * 8);
    _r += (tr - _r) * math.min(1, a.dt * 8);
    final w = size.width / 2;
    _meter(c, Rect.fromLTWH(10, 10, w - 20, size.height - 20), _l, 'L');
    _meter(c, Rect.fromLTWH(w + 10, 10, w - 20, size.height - 20), _r, 'R');
  }

  void _meter(Canvas c, Rect r, double v, String label) {
    final face = RRect.fromRectAndRadius(r, const Radius.circular(14));
    c.drawRRect(
        face,
        Paint()
          ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter,
              const [Color(0xFFFFF3D6), Color(0xFFE8C98A)]));
    final pivot = Offset(r.center.dx, r.bottom - r.height * .12);
    final radius = math.min(r.width * .45, r.height * .75);
    const start = -math.pi * .82, end = -math.pi * .18;
    final scale = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF3A2A12);
    c.drawArc(Rect.fromCircle(center: pivot, radius: radius), start,
        end - start, false, scale);
    c.drawArc(
        Rect.fromCircle(center: pivot, radius: radius),
        start + (end - start) * .75,
        (end - start) * .25,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0xFFD23B2B));
    for (var k = 0; k <= 10; k++) {
      final ang = start + (end - start) * k / 10;
      final d = Offset(math.cos(ang), math.sin(ang));
      c.drawLine(pivot + d * radius, pivot + d * (radius - (k.isEven ? 12 : 7)),
          scale);
    }
    final ang = start + (end - start) * v.clamp(0.0, 1.0);
    final needle = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1B1B1B);
    c.drawLine(pivot,
        pivot + Offset(math.cos(ang), math.sin(ang)) * (radius * 1.04), needle);
    c.drawCircle(pivot, 6, Paint()..color = const Color(0xFF1B1B1B));
    final tp = TextPainter(
        text: TextSpan(
            text: 'VU  $label',
            style: const TextStyle(
                color: Color(0xFF3A2A12),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, Offset(r.center.dx - tp.width / 2, pivot.dy - radius * .45));
  }
}

// ================================================================= ripples
class _Ripple {
  final Offset pos;
  double r;
  final double hue;
  double life;
  _Ripple(this.pos, this.hue) : r = 0, life = 1;
}

class RipplesEffect extends VisEffect {
  final List<_Ripple> _rs = [];
  final math.Random _rnd = math.Random();
  int _lastBeat = -1;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    if (a.beatCount != _lastBeat && a.level > .05) {
      _lastBeat = a.beatCount;
      for (var k = 0; k < 1 + (a.level * 2).round(); k++) {
        _rs.add(_Ripple(
            Offset(_rnd.nextDouble() * size.width,
                _rnd.nextDouble() * size.height),
            _rnd.nextDouble() * 360));
      }
    }
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.plus;
    for (final r in _rs) {
      r.r += a.dt * (90 + a.level * 160);
      r.life -= a.dt * .45;
      for (var k = 0; k < 3; k++) {
        final rr = r.r - k * 14;
        if (rr <= 0) continue;
        p
          ..strokeWidth = 3 - k * .8
          ..color = hsv(r.hue + k * 20, .7, 1, r.life * (1 - k * .25));
        c.drawCircle(r.pos, rr, p);
      }
    }
    _rs.removeWhere((r) => r.life <= 0);
  }
}

// ================================================================== aurora
class AuroraEffect extends VisEffect {
  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    const curtains = 5;
    for (var k = 0; k < curtains; k++) {
      final path = Path();
      const pts = 60;
      final baseY = size.height * (.25 + k * .1);
      final amp = size.height * (.08 + .12 * bandAt(a, k / curtains));
      final top = <Offset>[];
      for (var i = 0; i <= pts; i++) {
        final x = i / pts;
        final y = baseY +
            math.sin(x * math.pi * 2 * (1 + k * .3) + a.time * (.6 + k * .15)) *
                amp +
            math.sin(x * math.pi * 7 - a.time * 1.3 + k) * amp * .25;
        top.add(Offset(x * size.width, y));
      }
      path.moveTo(top.first.dx, top.first.dy);
      for (final q in top.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      final curtainH = size.height * (.35 + .2 * a.level);
      for (final q in top.reversed) {
        path.lineTo(q.dx, q.dy + curtainH);
      }
      path.close();
      final hue = 140 + k * 35 + math.sin(a.time * .2) * 30;
      c.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.linear(
                Offset(0, baseY - amp), Offset(0, baseY + curtainH), [
              hsv(hue, .8, 1, .0),
              hsv(hue, .75, 1, .35 + .25 * a.level),
              hsv(hue + 40, .7, 1, 0),
            ], const [
              0,
              .25,
              1
            ]));
    }
  }
}

// =============================================================== kaleido
class KaleidoEffect extends VisEffect {
  double _rot = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _rot += a.dt * (.2 + a.level * .8);
    final center = size.center(Offset.zero);
    final r = size.longestSide * .6;
    const segments = 12;
    for (var s = 0; s < segments; s++) {
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(_rot + s * 2 * math.pi / segments);
      if (s.isOdd) c.scale(1, -1);
      for (var k = 0; k < 6; k++) {
        final v = a.bands[(k * 5) % a.bands.length];
        final d = r * (.12 + k * .14);
        final size2 = r * (.04 + v * .12);
        final path = Path()
          ..moveTo(d, 0)
          ..lineTo(d + size2, size2 * .5)
          ..lineTo(d + size2 * 1.6, 0)
          ..lineTo(d + size2, -size2 * .25)
          ..close();
        c.drawPath(
            path,
            Paint()
              ..blendMode = BlendMode.plus
              ..color = hsv(a.time * 40 + k * 50 + s * 4, .75, 1, .55));
      }
      c.restore();
    }
    c.drawCircle(
        center,
        r * .08 * (1 + a.beat * .5),
        Paint()
          ..shader = ui.Gradient.radial(center, r * .1,
              [Colors.white.withValues(alpha: .8), Colors.transparent]));
  }
}

// ================================================================== plasma
class PlasmaEffect extends VisEffect {
  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    const cols = 48;
    final cw = size.width / cols;
    final rows = (size.height / cw).ceil();
    final p = Paint();
    final t = a.time * (.8 + a.level);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final fx = x / cols * 6, fy = y / rows * 4;
        final v = math.sin(fx + t) +
            math.sin(fy * 1.3 - t * 1.2) +
            math.sin((fx + fy) * .7 + t * .7) +
            math.sin(math.sqrt(fx * fx + fy * fy) * 1.5 - t * 1.6);
        final hue = (v + 4) / 8 * 360 + a.time * 20;
        p.color = hsv(hue, .75, .35 + .45 * a.level + .2 * a.beat);
        c.drawRect(Rect.fromLTWH(x * cw, y * cw, cw + .6, cw + .6), p);
      }
    }
  }
}

// =============================================================== mountains
/// Spectrum landscape: a history of spectra as stacked ridge lines.
class MountainsEffect extends VisEffect {
  final List<List<double>> _hist = [];
  double _acc = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _acc += a.dt;
    if (_acc > .07 || _hist.isEmpty) {
      _acc = 0;
      _hist.insert(0, List.of(a.bands));
      if (_hist.length > 28) _hist.removeLast();
    }
    final fill = Paint()..color = const Color(0xFF040A15);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (var k = _hist.length - 1; k >= 0; k--) {
      final f = k / 28; // 0 front .. 1 back
      final baseY = size.height * (.95 - f * .7);
      final w = size.width * (1 - f * .45);
      final x0 = (size.width - w) / 2;
      final amp = size.height * .35 * (1 - f * .5);
      final b = _hist[k];
      final path = Path()..moveTo(x0, baseY);
      const pts = 48;
      for (var i = 0; i <= pts; i++) {
        final x = i / pts;
        final center = 1 - (x - .5).abs() * 2; // peaks in the middle
        final idx = ((x - .5).abs() * 2 * (b.length - 1)).round();
        path.lineTo(x0 + x * w, baseY - b[idx] * amp * (.3 + .7 * center));
      }
      final ridge = Path.from(path);
      path
        ..lineTo(x0 + w, size.height)
        ..lineTo(x0, size.height)
        ..close();
      c.drawPath(path, fill);
      line.color = hsv(200 + f * 120, .6, 1, 1 - f * .8);
      c.drawPath(ridge, line);
    }
  }
}

// ================================================================= bubbles
class _Bubble {
  double x, y, r, speed, hue, wobble;
  _Bubble(this.x, this.y, this.r, this.speed, this.hue, this.wobble);
}

class BubblesEffect extends VisEffect {
  final List<_Bubble> _b = [];
  final math.Random _rnd = math.Random();

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final spawn = a.dt * (4 + a.level * 30 + a.beat * 30);
    var n = spawn.floor() + (_rnd.nextDouble() < spawn % 1 ? 1 : 0);
    while (n-- > 0 && _b.length < 160) {
      _b.add(_Bubble(
          _rnd.nextDouble() * size.width,
          size.height + 20,
          4 + _rnd.nextDouble() * 18 * (.5 + bandAt(a, _rnd.nextDouble())),
          40 + _rnd.nextDouble() * 80,
          180 + _rnd.nextDouble() * 120,
          _rnd.nextDouble() * 6));
    }
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final b in _b) {
      b.y -= b.speed * a.dt * (1 + a.level);
      final x = b.x + math.sin(a.time * 2 + b.wobble) * 8;
      final r = b.r * (1 + a.beat * .15);
      final center = Offset(x, b.y);
      c.drawCircle(
          center,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
                center - Offset(r * .3, r * .3), r * 1.2, [
              Colors.white.withValues(alpha: .35),
              hsv(b.hue, .6, 1, .08),
            ]));
      rim.color = hsv(b.hue, .5, 1, .7);
      c.drawCircle(center, r, rim);
    }
    _b.removeWhere((b) => b.y < -30);
  }
}

// ================================================================== spiral
class SpiralEffect extends VisEffect {
  double _rot = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _rot += a.dt * (.4 + a.level * 2);
    final center = size.center(Offset.zero);
    final maxR = size.longestSide * .55;
    const arms = 4, perArm = 70;
    final p = Paint()..blendMode = BlendMode.plus;
    for (var arm = 0; arm < arms; arm++) {
      for (var i = 0; i < perArm; i++) {
        final f = i / perArm;
        final ang = _rot + arm * 2 * math.pi / arms + f * 5.5;
        final r = maxR * f * (1 + bandAt(a, f) * .25);
        final pos = center + Offset(math.cos(ang), math.sin(ang) * .62) * r;
        p.color = hsv(200 + f * 140 + arm * 20, .7, 1, (1 - f) * .9);
        c.drawCircle(pos, 1.2 + (1 - f) * 3 + a.beat * 2 * (1 - f), p);
      }
    }
    c.drawCircle(
        center,
        maxR * .12,
        Paint()
          ..shader = ui.Gradient.radial(center, maxR * .14, [
            Colors.white.withValues(alpha: .6 + .4 * a.beat),
            kBrandSky.withValues(alpha: .2),
            Colors.transparent,
          ], const [
            0,
            .5,
            1
          ]));
  }
}

// ==================================================================== LEDs
/// Classic hi-fi LED spectrum (green / yellow / red segments).
class LedEffect extends VisEffect {
  final List<double> _peaks = List.filled(40, 0);

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    const cols = 24;
    final rows = math.max(8, (size.height / 12).floor());
    final cw = size.width / cols;
    final ch = size.height / rows;
    final p = Paint();
    for (var i = 0; i < cols; i++) {
      final v = bandAt(a, i / (cols - 1));
      final lit = (v * rows).round();
      _peaks[i] = math.max(_peaks[i] - a.dt * 6, lit.toDouble());
      for (var r = 0; r < rows; r++) {
        final f = r / rows;
        final color = f > .82
            ? const Color(0xFFFF3B30)
            : f > .6
                ? const Color(0xFFFFD60A)
                : const Color(0xFF32D74B);
        final on = r < lit || r == _peaks[i].round() - 1;
        p.color = on ? color : color.withValues(alpha: .08);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(i * cw + 2, size.height - (r + 1) * ch + 1.5,
                    cw - 4, ch - 3),
                const Radius.circular(2)),
            p);
      }
    }
  }
}

// ================================================================== orbits
class OrbitsEffect extends VisEffect {
  double _t = 0;

  @override
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    _t += a.dt * (.5 + a.level * 1.5);
    final center = size.center(Offset.zero);
    final m = size.shortestSide;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = kBrandSilver.withValues(alpha: .18);
    // sun
    c.drawCircle(
        center,
        m * (.07 + .03 * a.beat),
        Paint()
          ..shader = ui.Gradient.radial(center, m * .12, [
            const Color(0xFFFFF2B0),
            const Color(0xFFFF9F1C).withValues(alpha: .6),
            Colors.transparent,
          ], const [
            0,
            .5,
            1
          ]));
    for (var k = 0; k < 8; k++) {
      final rx = size.width * (.12 + k * .055);
      final ry = m * (.1 + k * .045);
      c.drawOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
          ring);
      final ang = _t * (1.6 - k * .15) + k * 1.3;
      final pos = center + Offset(math.cos(ang) * rx, math.sin(ang) * ry);
      final r = 3 + a.bands[k * 4] * m * .05;
      c.drawCircle(
          pos,
          r,
          Paint()
            ..shader = ui.Gradient.radial(pos - Offset(r * .3, r * .3), r * 1.3,
                [hsv(k * 45.0 + 20, .5, 1), hsv(k * 45.0 + 20, .8, .5)]));
    }
  }
}
