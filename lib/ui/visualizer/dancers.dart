import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/audio_analyzer.dart';
import '../brand.dart';

// =====================================================================
//  Black dancing silhouettes.
//
//  Every dancer is a small skeleton (shoulders, elbows, hands, hips,
//  knees, feet) that is "dressed" with filled shapes: tapered limbs, a
//  shaped torso, head, hair, dress / flared trousers and shoes. All
//  shapes go into ONE path per dancer (consistent winding, non-zero
//  fill = union), which is filled pure black. A soft back light around
//  the outline keeps the silhouettes visible on the dark background.
//
//  On every beat the dancer moves to the next key pose of its current
//  dance move (smooth ease-out), with continuous groove on top (knee
//  bounce, hip sway, head bob, swinging hair and dress).
// =====================================================================

/// Joint angles. Arms/legs: 0 = hanging down, pi/2 = sideways out,
/// pi = straight up; negative = across the body. Elbow/knee are relative.
class _Pose {
  final double lArm, lElbow, rArm, rElbow;
  final double lLeg, lKnee, rLeg, rKnee;
  final double lean, head, jump, sway;

  const _Pose({
    this.lArm = .35,
    this.lElbow = -.7,
    this.rArm = .35,
    this.rElbow = -.7,
    this.lLeg = .1,
    this.lKnee = .1,
    this.rLeg = .1,
    this.rKnee = .1,
    this.lean = 0,
    this.head = 0,
    this.jump = 0,
    this.sway = 0,
  });

  _Pose mirror() => _Pose(
        lArm: rArm,
        lElbow: rElbow,
        rArm: lArm,
        rElbow: lElbow,
        lLeg: rLeg,
        lKnee: rKnee,
        rLeg: lLeg,
        rKnee: lKnee,
        lean: -lean,
        head: -head,
        jump: jump,
        sway: -sway,
      );

  static double _l(double a, double b, double t) => a + (b - a) * t;

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
        lArm: _l(a.lArm, b.lArm, t),
        lElbow: _l(a.lElbow, b.lElbow, t),
        rArm: _l(a.rArm, b.rArm, t),
        rElbow: _l(a.rElbow, b.rElbow, t),
        lLeg: _l(a.lLeg, b.lLeg, t),
        lKnee: _l(a.lKnee, b.lKnee, t),
        rLeg: _l(a.rLeg, b.rLeg, t),
        rKnee: _l(a.rKnee, b.rKnee, t),
        lean: _l(a.lean, b.lean, t),
        head: _l(a.head, b.head, t),
        jump: _l(a.jump, b.jump, t),
        sway: _l(a.sway, b.sway, t),
      );
}

// ------------------------------------------------------------ key poses
const _groove = _Pose(
    lArm: .45, lElbow: -1.1, rArm: .45, rElbow: -1.1, lKnee: .25, rKnee: .1);
const _pointUp = _Pose(
    rArm: 2.65, rElbow: .05, lArm: .75, lElbow: -2.1, // hand on hip
    rLeg: .2, rKnee: .3, lean: -.1, head: -.15, sway: .5);
const _pointDown = _Pose(
    rArm: -.95, rElbow: .05, lArm: .75, lElbow: -2.1,
    lLeg: .2, lKnee: .35, lean: .12, head: .2, sway: -.4);
const _armsV = _Pose(
    lArm: 2.7, lElbow: .1, rArm: 2.7, rElbow: .1, lLeg: .14, rLeg: .14,
    head: -.1);
const _handsHead = _Pose(
    lArm: 2.45, lElbow: 2.25, rArm: 2.45, rElbow: 2.25,
    lKnee: .45, rLeg: .16, sway: .7, lean: .06);
const _armsWide = _Pose(
    lArm: 1.65, lElbow: .2, rArm: 1.75, rElbow: -.15,
    lLeg: .28, rLeg: .28, lKnee: .25, rKnee: .25);
const _fistPump = _Pose(
    lArm: 1.15, lElbow: 1.9, rArm: .55, rElbow: 1.7,
    lLeg: .32, lKnee: .7, rLeg: .32, rKnee: .7, lean: .1);
const _kneeLift = _Pose(
    rLeg: 1.65, rKnee: 1.85, lArm: 1.45, lElbow: .5, rArm: 1.6, rElbow: -.5,
    lean: -.12, head: -.2);
const _dab = _Pose(
    lArm: 2.25, lElbow: .05, rArm: 1.95, rElbow: 2.7,
    lean: .18, head: .55, rLeg: .25, rKnee: .2);
const _wave = _Pose(
    rArm: 2.35, rElbow: 1.0, lArm: .4, lElbow: -1.0,
    lKnee: .35, sway: .8, head: .15);
const _elbowsUp = _Pose(
    lArm: 2.15, lElbow: 1.25, rArm: 2.15, rElbow: 1.25,
    lKnee: .3, rKnee: .3, lLeg: .2, rLeg: .2);
const _jumpBack = _Pose(
    lArm: 2.6, lElbow: .2, rArm: 2.2, rElbow: .4,
    lLeg: .15, lKnee: 1.7, rLeg: .25, rKnee: .4, jump: 1, head: -.25);
const _strut = _Pose(
    lArm: -.35, lElbow: -.4, rArm: .9, rElbow: 1.2,
    lLeg: .35, lKnee: .15, rLeg: .05, rKnee: .45, lean: -.08, sway: -.6);

/// Dance moves: key poses that alternate on the beat.
final List<List<_Pose>> _moves = [
  [_pointUp, _pointDown], // classic disco
  [_armsV, _handsHead],
  [_armsWide, _fistPump],
  [_kneeLift, _groove],
  [_dab, _groove, _dab.mirror(), _groove],
  [_wave, _wave.mirror()],
  [_elbowsUp, _armsV],
  [_jumpBack, _groove],
  [_strut, _strut.mirror()],
  [_handsHead, _handsHead.mirror()],
  [_fistPump, _fistPump.mirror()],
];

// ------------------------------------------------------------ outfits
enum _Hair { short, long, ponytail, curly, cap, afro }

class _Look {
  final bool male;
  final bool dress;
  final bool flare; // 70s bell-bottoms
  final bool heels;
  final _Hair hair;
  final double scale;
  const _Look(
      {this.male = false,
      this.dress = false,
      this.flare = false,
      this.heels = false,
      this.hair = _Hair.long,
      this.scale = 1});
}

const _looks = [
  _Look(dress: true, heels: true, hair: _Hair.long),
  _Look(male: true, hair: _Hair.short, scale: 1.06),
  _Look(flare: true, hair: _Hair.curly),
  _Look(dress: true, heels: true, hair: _Hair.ponytail, scale: .96),
  _Look(male: true, flare: true, hair: _Hair.curly, scale: 1.04),
  _Look(dress: true, hair: _Hair.afro),
  _Look(male: true, hair: _Hair.cap, scale: 1.02),
  _Look(flare: true, heels: true, hair: _Hair.long, scale: .98),
];

// ------------------------------------------------------------ geometry
/// Collects polygons with the same winding so that a non-zero fill gives
/// the union of all parts (no holes where parts overlap).
class _Sil {
  final Path path = Path();

  void poly(List<Offset> pts) {
    var area = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      area += a.dx * b.dy - b.dx * a.dy;
    }
    path.addPolygon(area < 0 ? pts.reversed.toList() : pts, true);
  }

  void ellipse(Offset c, double rx, double ry, [int n = 18]) {
    poly([
      for (var i = 0; i < n; i++)
        c +
            Offset(math.cos(i / n * math.pi * 2) * rx,
                math.sin(i / n * math.pi * 2) * ry)
    ]);
  }

  void circle(Offset c, double r) => ellipse(c, r, r, 14);

  /// Tapered limb from [a] (radius ra) to [b] (radius rb).
  void limb(Offset a, Offset b, double ra, double rb) {
    final d = b - a;
    final len = d.distance;
    if (len < .01) {
      circle(a, math.max(ra, rb));
      return;
    }
    final n = Offset(-d.dy / len, d.dx / len);
    circle(a, ra);
    circle(b, rb);
    poly([a + n * ra, b + n * rb, b - n * rb, a - n * ra]);
  }
}

Offset _dir(double angle, double side) =>
    Offset(math.sin(angle) * side, math.cos(angle));

double _easeOut(double t) =>
    1 - math.pow(1 - t.clamp(0.0, 1.0), 3).toDouble();

// ------------------------------------------------------------ dancers
class Dancers {
  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final alpha = (a.music.clamp(0.0, 1.0) * math.min(1.0, a.level * 25))
        .clamp(0.0, 1.0);
    if (alpha < .02) return;
    final count = (size.width / 125).clamp(3, 8).floor();
    final h = math.min(size.height * .58, 175.0);
    final ground = size.height - 6;

    // stage light behind the dancers
    final stage = Rect.fromCenter(
        center: Offset(size.width / 2, ground),
        width: size.width * 1.1,
        height: h * 1.6);
    c.drawOval(
        stage,
        Paint()
          ..shader = RadialGradient(colors: [
            kBrandSky.withValues(alpha: (.22 + .18 * a.beat) * alpha),
            kBrandBlue.withValues(alpha: .08 * alpha),
            Colors.transparent,
          ], stops: const [
            0,
            .55,
            1
          ]).createShader(stage));

    final rim = Paint()
      ..color = Color.lerp(kBrandSky, Colors.white, .4)!
          .withValues(alpha: (.55 + .3 * a.beat) * alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * .03);
    final black = Paint()..color = Colors.black.withValues(alpha: alpha);

    // fast songs: change pose every second beat
    final step = a.bpm > 135 ? 2 : 1;
    for (var i = 0; i < count; i++) {
      final look = _looks[(i * 3 + 1) % _looks.length];
      final x = size.width * (i + .5) / count;
      final pose = _currentPose(a, i, step);
      final sil = _Sil();
      _build(sil, Offset(x, ground), h * look.scale, look, pose, a, i);
      c.drawPath(sil.path, rim);
      c.drawPath(sil.path, black);
    }
  }

  _Pose _currentPose(AudioAnalyzer a, int dancer, int step) {
    final beat = a.beatCount ~/ step;
    final phase = ((a.beatCount % step) + a.phase) / step;
    // a new move every 8 steps, different for every dancer
    final block = beat ~/ 8;
    final move = _moves[(dancer * 5 + block * 3) % _moves.length];
    final mirrored = (block + dancer).isOdd;
    _Pose pick(int b) {
      final p = move[b % move.length];
      return mirrored ? p.mirror() : p;
    }

    final from = pick(beat - 1 + dancer);
    final to = pick(beat + dancer);
    final t = _easeOut(phase / .45);
    final base = _Pose.lerp(from, to, t);

    // groove: knees dip on the beat, hips sway, head bobs
    final dip = math.pow(1 - phase, 2).toDouble() * .35;
    final sway = math.sin(math.pi * (beat + phase)) * .35;
    return _Pose(
      lArm: base.lArm,
      lElbow: base.lElbow,
      rArm: base.rArm,
      rElbow: base.rElbow,
      lLeg: base.lLeg,
      lKnee: base.lKnee + dip,
      rLeg: base.rLeg,
      rKnee: base.rKnee + dip,
      lean: base.lean,
      head: base.head + math.sin(2 * math.pi * phase) * .08,
      jump: base.jump * math.sin(math.pi * phase.clamp(0.0, 1.0)),
      sway: base.sway + sway,
    );
  }

  void _build(_Sil s, Offset foot, double h, _Look look, _Pose p,
      AudioAnalyzer a, int idx) {
    final m = look.male;
    final shoulderHalf = h * (m ? .108 : .084);
    final waistHalf = h * (m ? .078 : .048);
    final hipHalf = h * (m ? .08 : .094);
    final torso = h * .28;
    final upperArm = h * .15, foreArm = h * .135;
    final thigh = h * .255, shin = h * .245;
    final armW = h * (m ? .036 : .029);
    final legW = h * (m ? .054 : .056);

    // skeleton relative to the hip centre (0,0)
    final up = Offset(math.sin(p.lean), -math.cos(p.lean));
    final right = Offset(math.cos(p.lean), math.sin(p.lean));
    final hipC = Offset(p.sway * h * .05, 0);
    final shoulderC = hipC + up * torso;
    final neck = shoulderC + up * (h * .04);
    final headUp =
        Offset(math.sin(p.lean + p.head), -math.cos(p.lean + p.head));
    final headC = neck + headUp * (h * .075);

    final shL = shoulderC - right * shoulderHalf;
    final shR = shoulderC + right * shoulderHalf;
    final waistC = Offset.lerp(shoulderC, hipC, .62)!;
    final waL = waistC - right * waistHalf;
    final waR = waistC + right * waistHalf;
    final hpL = hipC - Offset(hipHalf, 0);
    final hpR = hipC + Offset(hipHalf, 0);
    final legL = hipC + Offset(-hipHalf * .55, h * .02);
    final legR = hipC + Offset(hipHalf * .55, h * .02);

    final elL = shL + _dir(p.lArm, -1) * upperArm;
    final haL = elL + _dir(p.lArm + p.lElbow, -1) * foreArm;
    final elR = shR + _dir(p.rArm, 1) * upperArm;
    final haR = elR + _dir(p.rArm + p.rElbow, 1) * foreArm;
    final knL = legL + _dir(p.lLeg, -1) * thigh;
    final anL = knL + _dir(p.lLeg - p.lKnee, -1) * shin;
    final knR = legR + _dir(p.rLeg, 1) * thigh;
    final anR = knR + _dir(p.rLeg - p.rKnee, 1) * shin;

    // put the lower foot on the ground (+ jump)
    final footH = h * (look.heels ? .045 : .028);
    final lowest = math.max(anL.dy, anR.dy) + footH;
    final o = Offset(foot.dx, foot.dy - lowest - p.jump * h * .13);
    Offset t(Offset q) => q + o;

    // ---- legs + shoes
    for (final side in [-1.0, 1.0]) {
      final root = t(side < 0 ? legL : legR);
      final knee = t(side < 0 ? knL : knR);
      final ankle = t(side < 0 ? anL : anR);
      s.limb(root, knee, legW, legW * .66);
      if (look.flare) {
        s.limb(knee, ankle, legW * .66, legW * 1.05); // bell-bottoms
      } else {
        // calf
        s.limb(knee, Offset.lerp(knee, ankle, .35)!, legW * .66, legW * .62);
        s.limb(Offset.lerp(knee, ankle, .35)!, ankle, legW * .62, legW * .36);
      }
      if (look.heels) {
        final toe = ankle + Offset(side * h * .045, h * .042);
        s.limb(ankle, toe, legW * .4, h * .012);
        s.limb(ankle + Offset(-side * h * .005, 0),
            ankle + Offset(-side * h * .008, h * .045), h * .008, h * .006);
      } else {
        final toe = ankle + Offset(side * h * .06, h * .02);
        s.limb(ankle + Offset(0, h * .008), toe, h * .022, h * .016);
      }
    }

    // ---- dress (swings with the hips)
    if (look.dress) {
      final swing = math.sin(2 * math.pi * (a.phase + idx * .13)) * h * .025 +
          p.sway * h * .02;
      final spread =
          math.max((knL.dx - legL.dx).abs(), (knR.dx - legR.dx).abs());
      final flareW = hipHalf + h * .05 + spread * .7;
      final hemY = hipC.dy + h * .19;
      final pts = <Offset>[t(waL), t(hpL)];
      const n = 8;
      for (var i = 0; i <= n; i++) {
        final f = i / n;
        final x = -flareW + 2 * flareW * f + swing;
        final y = hemY + math.sin(f * math.pi) * h * .012;
        pts.add(t(Offset(hipC.dx + x, y)));
      }
      pts
        ..add(t(hpR))
        ..add(t(waR));
      s.poly(pts);
    }

    // ---- torso
    s.poly([
      t(shL),
      t(Offset.lerp(shL, waL, .5)! - right * (h * .005)),
      t(waL),
      t(hpL),
      t(hpR),
      t(waR),
      t(Offset.lerp(shR, waR, .5)! + right * (h * .005)),
      t(shR),
    ]);
    if (!m) {
      // soft upper body line
      s.ellipse(t(Offset.lerp(shoulderC, waistC, .35)!), shoulderHalf * .85,
          h * .05);
    }
    s.circle(t(shL), armW * 1.25);
    s.circle(t(shR), armW * 1.25);

    // ---- arms + hands
    s.limb(t(shL), t(elL), armW * 1.15, armW * .85);
    s.limb(t(elL), t(haL), armW * .85, armW * .6);
    s.limb(t(shR), t(elR), armW * 1.15, armW * .85);
    s.limb(t(elR), t(haR), armW * .85, armW * .6);
    s.ellipse(t(haL + _dir(p.lArm + p.lElbow, -1) * (h * .022)), h * .02,
        h * .022);
    s.ellipse(t(haR + _dir(p.rArm + p.rElbow, 1) * (h * .022)), h * .02,
        h * .022);

    // ---- neck + head
    s.limb(t(shoulderC), t(neck), h * .03, h * .026);
    s.ellipse(t(headC), h * .052, h * .064);

    // ---- hair
    final swingX = math.sin(2 * math.pi * (a.phase + idx * .21)) * h * .035 -
        p.lean * h * .12 -
        p.head * h * .06;
    final top = headC + headUp * (h * .03);
    switch (look.hair) {
      case _Hair.short:
        s.ellipse(t(top), h * .056, h * .042);
      case _Hair.cap:
        s.ellipse(t(top), h * .058, h * .04);
        final brim = top + Offset(math.cos(p.head) * h * .02, h * .015);
        s.limb(t(brim), t(brim + Offset(h * .075, h * .008)), h * .012,
            h * .01);
      case _Hair.long:
        s.ellipse(t(top), h * .062, h * .05);
        // flowing hair mass down to the shoulders
        s.poly([
          t(headC + Offset(-h * .062, -h * .035)),
          t(headC + Offset(-h * .074 + swingX * .5, h * .05)),
          t(headC + Offset(-h * .07 + swingX, h * .14)),
          t(headC + Offset(-h * .045 + swingX * 1.25, h * .2)),
          t(headC + Offset(-h * .005 + swingX * 1.3, h * .175)),
          t(headC + Offset(h * .035 + swingX * 1.15, h * .2)),
          t(headC + Offset(h * .062 + swingX, h * .12)),
          t(headC + Offset(h * .066 + swingX * .4, h * .03)),
          t(headC + Offset(h * .055, -h * .04)),
        ]);
      case _Hair.ponytail:
        s.ellipse(t(top), h * .058, h * .045);
        final root = top + Offset(h * .04, -h * .01);
        s.limb(t(root), t(root + Offset(h * .05 + swingX * 1.6, h * .13)),
            h * .03, h * .01);
      case _Hair.curly:
        for (var k = 0; k < 9; k++) {
          final ang = -math.pi + k * math.pi / 8;
          final pos = headC +
              Offset(math.cos(ang) * h * .06, math.sin(ang) * h * .065) +
              Offset(swingX * .3, h * .01);
          s.circle(t(pos), h * (.034 + (k.isEven ? .006 : 0)));
        }
        s.circle(t(headC + Offset(-h * .07 + swingX * .5, h * .06)), h * .03);
        s.circle(t(headC + Offset(h * .07 + swingX * .5, h * .06)), h * .03);
      case _Hair.afro:
        s.circle(t(top + Offset(swingX * .2, -h * .005)), h * .1);
    }
  }
}
