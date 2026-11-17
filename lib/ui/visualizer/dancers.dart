import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/audio_analyzer.dart';
import 'effects.dart' show hsv;

class _Pose {
  double bounce = 0; // px up
  double hipShift = 0; // px sideways
  double lean = 0; // rad
  double headTilt = 0;
  // arms: angle from hanging down (0) to straight up (pi), + elbow bend
  double lArm = .2, lElbow = .2, rArm = .2, rElbow = .2;
  // legs: outward angle and knee bend
  double lLeg = .1, lKnee = 0, rLeg = .1, rKnee = 0;
}

/// Neon dancers that move to the beat (only while music is detected).
class Dancers {
  static const _hues = [195.0, 320.0, 48.0, 140.0, 265.0, 20.0, 170.0];

  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final alpha = a.music.clamp(0.0, 1.0) * (a.level > .02 ? 1 : a.level * 50);
    if (alpha < .02) return;
    final count = (size.width / 130).clamp(3, 7).floor();
    final h = math.min(size.height * .42, 140.0);
    final ground = size.height - 8;
    for (var i = 0; i < count; i++) {
      final x = size.width * (i + .5) / count;
      final pose = _poseFor(i % 5, a, h, i);
      _drawFigure(c, Offset(x, ground), h, pose,
          _hues[i % _hues.length], alpha, a.beat);
    }
  }

  _Pose _poseFor(int style, AudioAnalyzer a, double h, int index) {
    final p = (a.phase + index * .07) % 1; // small offsets look natural
    final bc = a.beatCount;
    final alt = bc.isEven ? 1.0 : -1.0;
    final s = math.sin(2 * math.pi * p);
    final hop = math.sin(math.pi * p);
    final pose = _Pose();
    switch (style) {
      case 0: // disco pointer
        pose.bounce = hop.abs() * h * .04;
        pose.hipShift = alt * hop * h * .04;
        pose.rArm = alt > 0 ? 2.6 : .5;
        pose.rElbow = .1;
        pose.lArm = .9;
        pose.lElbow = 1.7;
        pose.lLeg = .12 + (alt > 0 ? .15 * hop : 0.0);
        pose.rLeg = .12 + (alt < 0 ? .15 * hop : 0.0);
        pose.lKnee = .2 * hop;
        pose.headTilt = alt * .15;
      case 1: // waving arms
        pose.bounce = hop * h * .05;
        pose.lArm = 1.6 + .9 * math.sin(2 * math.pi * p + math.pi / 2);
        pose.rArm = 1.6 + .9 * math.sin(2 * math.pi * p - math.pi / 2);
        pose.lElbow = .6 * s;
        pose.rElbow = -.6 * s;
        pose.lLeg = .12 + .25 * math.max(0, s);
        pose.rLeg = .12 + .25 * math.max(0, -s);
        pose.lKnee = .4 * math.max(0, s);
        pose.rKnee = .4 * math.max(0, -s);
        pose.lean = .08 * s;
      case 2: // jumping, hands up
        pose.bounce = hop * hop * h * .1;
        pose.lArm = 2.7 + .2 * s;
        pose.rArm = 2.7 - .2 * s;
        pose.lElbow = .15;
        pose.rElbow = .15;
        pose.lLeg = .18 + .1 * (1 - hop);
        pose.rLeg = .18 + .1 * (1 - hop);
        pose.lKnee = .7 * (1 - hop);
        pose.rKnee = .7 * (1 - hop);
      case 3: // side step
        final sw = math.sin(math.pi * (bc + p));
        pose.hipShift = sw * h * .1;
        pose.bounce = hop * h * .03;
        pose.lean = -sw * .12;
        pose.lArm = .6 - .5 * sw;
        pose.rArm = .6 + .5 * sw;
        pose.lElbow = 1.2;
        pose.rElbow = 1.2;
        pose.lLeg = .1 + .3 * math.max(0, -sw);
        pose.rLeg = .1 + .3 * math.max(0, sw);
        pose.headTilt = sw * .2;
      default: // robot
        pose.bounce = (1 - p) * h * .02;
        pose.rArm = alt > 0 ? 1.57 : .35;
        pose.rElbow = alt > 0 ? 1.57 : 0.0;
        pose.lArm = alt < 0 ? 1.57 : .35;
        pose.lElbow = alt < 0 ? 1.57 : 0.0;
        pose.headTilt = alt * .25;
        pose.lLeg = .12;
        pose.rLeg = .12;
        pose.lKnee = alt > 0 ? .3 : 0.0;
        pose.rKnee = alt < 0 ? .3 : 0.0;
    }
    return pose;
  }

  /// Direction for an angle measured from "down", mirrored for the side.
  Offset _dir(double angle, double side) =>
      Offset(math.sin(angle) * side, math.cos(angle));

  void _drawFigure(Canvas c, Offset foot, double h, _Pose pose, double hue,
      double alpha, double beat) {
    final hip = foot + Offset(pose.hipShift, -h * .5 - pose.bounce);
    final up = Offset(math.sin(pose.lean), -math.cos(pose.lean));
    final neck = hip + up * (h * .3);
    final head = neck + Offset(math.sin(pose.lean + pose.headTilt), -1) * (h * .1);

    final upper = h * .16, lower = h * .15, thigh = h * .25, shin = h * .25;
    final lines = <List<Offset>>[];
    // body
    lines.add([hip, neck]);
    // arms
    for (final side in [-1.0, 1.0]) {
      final a1 = side < 0 ? pose.lArm : pose.rArm;
      final a2 = side < 0 ? pose.lElbow : pose.rElbow;
      final elbow = neck + _dir(a1, side) * upper;
      final hand = elbow + _dir(a1 + a2, side) * lower;
      lines.add([neck, elbow, hand]);
    }
    // legs
    for (final side in [-1.0, 1.0]) {
      final l1 = side < 0 ? pose.lLeg : pose.rLeg;
      final k = side < 0 ? pose.lKnee : pose.rKnee;
      final knee = hip + _dir(l1 + k * .5, side) * thigh;
      final ankle = knee + _dir(l1 - k * .6, side) * shin;
      lines.add([hip, knee, ankle]);
    }

    final color = hsv(hue, .75, 1, alpha);
    final glow = Paint()
      ..color = hsv(hue, .9, 1, alpha * (.35 + .4 * beat))
      ..strokeWidth = h * .11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * .05);
    final line = Paint()
      ..color = color
      ..strokeWidth = h * .055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // floor shadow
    c.drawOval(
        Rect.fromCenter(
            center: foot + const Offset(0, 4), width: h * .45, height: h * .07),
        Paint()..color = hsv(hue, .8, 1, alpha * .25));

    for (final pts in lines) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final q in pts.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      c.drawPath(path, glow);
      c.drawPath(path, line);
    }
    c.drawCircle(head, h * .075, glow..style = PaintingStyle.fill);
    c.drawCircle(head, h * .068, Paint()..color = color);
  }
}
