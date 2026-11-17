import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/audio_analyzer.dart';

// =====================================================================
//  Dance floor: a crowd of black silhouettes in three staggered rows.
//
//  Every dancer is a small skeleton that is "dressed" with filled
//  shapes (tapered limbs, torso, head, hair, dress / tutu / bell-bottoms,
//  shoes). ALL dancers of a frame go into ONE path (consistent winding +
//  non-zero fill = union) that is filled pure black. A coloured club
//  light behind the crowd makes the silhouettes stand out.
//
//  Motion: key poses per beat with smooth transitions over the whole
//  beat (never frozen), individual groove on top (arm swing, lean, head,
//  hips, knee bounce), slow wandering, spins / pirouettes (the body is
//  scaled horizontally by cos(angle), hair and skirts fly out), jumps,
//  ballet and couples (swing-out, twirl under the arm, closed hold).
// =====================================================================

class _Pose {
  final double lArm, lElbow, rArm, rElbow;
  final double lLeg, lKnee, rLeg, rKnee;
  final double lean, head, jump, sway, spin;

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
    this.spin = 0,
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
      spin: -spin);

  _Pose spinning([double turns = 1]) => _Pose(
      lArm: lArm,
      lElbow: lElbow,
      rArm: rArm,
      rElbow: rElbow,
      lLeg: lLeg,
      lKnee: lKnee,
      rLeg: rLeg,
      rKnee: rKnee,
      lean: lean,
      head: head,
      jump: jump,
      sway: sway,
      spin: turns);

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
        jump: b.jump,
        sway: _l(a.sway, b.sway, t),
        spin: b.spin,
      );
}

// ------------------------------------------------------------ key poses
// arms/legs: 0 = down, pi/2 = sideways out, pi = up, < 0 across the body
const _groove = _Pose(
    lArm: .45, lElbow: -1.1, rArm: .45, rElbow: -1.1, lKnee: .25, rKnee: .1);
const _pointUp = _Pose(
    rArm: 2.65, rElbow: .05, lArm: .75, lElbow: -2.1,
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
const _shimmy = _Pose(
    lArm: .75, lElbow: 2.0, rArm: .75, rElbow: 2.0,
    lKnee: .35, rKnee: .2, sway: .6, lean: -.1, head: .15);
const _twist = _Pose(
    lArm: .85, lElbow: 1.5, rArm: .8, rElbow: 1.6,
    lLeg: .28, lKnee: .7, rLeg: .28, rKnee: .55, sway: 1.0, lean: -.18);
const _hairWhip = _Pose(
    rArm: 2.45, rElbow: 1.4, lArm: .6, lElbow: -.5,
    lean: .28, head: .75, lKnee: .3, sway: .4);
const _runningMan = _Pose(
    lLeg: 1.05, lKnee: 1.7, rLeg: .1, rKnee: .35,
    lArm: .95, lElbow: 1.5, rArm: -.3, rElbow: 1.1, lean: .08);
const _crouch = _Pose(
    lLeg: .45, lKnee: 1.05, rLeg: .45, rKnee: 1.0,
    lArm: .9, lElbow: 1.6, rArm: 1.25, rElbow: -1.4, lean: .15, head: .1);
const _sideBend = _Pose(
    lean: .48, rArm: 2.85, rElbow: .6, lArm: .5, lElbow: -1.2,
    head: .3, lLeg: .2, rKnee: .2);
const _starJump = _Pose(
    jump: 1.4, lLeg: .75, rLeg: .75, lKnee: .1, rKnee: .1,
    lArm: 2.4, rArm: 2.4, lElbow: .05, rElbow: .05, head: -.2);
const _tuckJump = _Pose(
    jump: 1.5, lLeg: .5, lKnee: 2.1, rLeg: .5, rKnee: 2.1,
    lArm: 2.55, rArm: 2.55, lElbow: .2, rElbow: .2);
const _splitLeap = _Pose(
    jump: 1.6, lLeg: 1.45, lKnee: .05, rLeg: 1.45, rKnee: .12,
    lArm: 2.05, lElbow: .1, rArm: 1.55, rElbow: .1, head: -.15, lean: -.05);
// ballet
const _fifth = _Pose(
    lArm: 2.6, lElbow: .75, rArm: 2.6, rElbow: .75,
    lLeg: .03, rLeg: .03, lKnee: 0, rKnee: 0, head: -.1);
const _arabesque = _Pose(
    rLeg: 1.55, rKnee: 0, lLeg: 0, lKnee: 0,
    rArm: 2.0, rElbow: .1, lArm: 1.45, lElbow: .15, lean: -.35, head: -.2);
const _passe = _Pose(
    rLeg: .95, rKnee: 2.05, lLeg: 0, lKnee: 0,
    lArm: 2.65, lElbow: .7, rArm: 2.65, rElbow: .7);
const _attitude = _Pose(
    lLeg: 1.25, lKnee: 1.0, rLeg: 0, rKnee: 0,
    rArm: 2.7, rElbow: .5, lArm: 1.5, lElbow: .2, lean: .2);
const _bow = _Pose(
    lArm: 1.2, lElbow: .3, rArm: 1.2, rElbow: .3, lKnee: .55, rKnee: .1,
    rLeg: .25, lean: .1, head: .3);

final _partyMoves = <List<_Pose>>[
  [_pointUp, _pointDown],
  [_armsV, _handsHead],
  [_armsWide, _fistPump],
  [_kneeLift, _groove],
  [_dab, _groove, _dab.mirror(), _groove],
  [_wave, _wave.mirror()],
  [_elbowsUp, _armsV],
  [_jumpBack, _groove],
  [_strut, _strut.mirror()],
  [_shimmy, _shimmy.mirror()],
  [_twist, _twist.mirror()],
  [_hairWhip, _groove, _hairWhip.mirror(), _groove],
  [_runningMan, _runningMan.mirror()],
  [_crouch, _crouch.mirror()],
  [_sideBend, _groove, _sideBend.mirror(), _groove],
  [_armsWide, _armsWide.spinning(), _groove, _armsV.spinning()],
  [_starJump, _groove],
  [_tuckJump, _crouch],
  [_splitLeap, _groove],
  [_handsHead.spinning(), _groove],
];

final _balletMoves = <List<_Pose>>[
  [_fifth, _arabesque],
  [_passe.spinning(), _fifth],
  [_attitude, _fifth],
  [_splitLeap, _fifth],
  [_sideBend, _arabesque.mirror()],
  [_passe.spinning(2), _arabesque],
  [_bow, _fifth],
];

// ------------------------------------------------------------ outfits
enum _Hair { short, long, ponytail, curly, cap, afro, bun }

enum _Dress { none, dress, tutu, long }

class _Look {
  final bool male;
  final _Dress dress;
  final bool flare;
  final bool heels;
  final bool pointe;
  final _Hair hair;
  const _Look(
      {this.male = false,
      this.dress = _Dress.none,
      this.flare = false,
      this.heels = false,
      this.pointe = false,
      this.hair = _Hair.long});
  bool get ballet => pointe;
}

const _looks = [
  _Look(dress: _Dress.dress, heels: true, hair: _Hair.long),
  _Look(male: true, hair: _Hair.short),
  _Look(flare: true, hair: _Hair.curly),
  _Look(dress: _Dress.dress, heels: true, hair: _Hair.ponytail),
  _Look(male: true, flare: true, hair: _Hair.curly),
  _Look(dress: _Dress.tutu, pointe: true, hair: _Hair.bun),
  _Look(male: true, hair: _Hair.cap),
  _Look(flare: true, heels: true, hair: _Hair.long),
  _Look(hair: _Hair.ponytail),
  _Look(dress: _Dress.dress, hair: _Hair.afro),
  _Look(male: true, hair: _Hair.short, flare: true),
  _Look(dress: _Dress.long, pointe: true, hair: _Hair.bun),
  _Look(hair: _Hair.long),
];
const _manLook = _Look(male: true, hair: _Hair.short);
const _manCap = _Look(male: true, hair: _Hair.cap);
const _womanSwing = _Look(dress: _Dress.dress, heels: true, hair: _Hair.long);
const _womanCurl = _Look(dress: _Dress.dress, heels: true, hair: _Hair.curly);

// ------------------------------------------------------------ geometry
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

  void ellipse(Offset c, double rx, double ry, [int n = 14]) {
    poly([
      for (var i = 0; i < n; i++)
        c +
            Offset(math.cos(i / n * math.pi * 2) * rx,
                math.sin(i / n * math.pi * 2) * ry)
    ]);
  }

  void circle(Offset c, double r) => ellipse(c, r, r, 10);

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

double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * x * (x * (x * 6 - 15) + 10);
}

/// Two-bone IK: (elbow, hand) for a hand that reaches towards [target].
(Offset, Offset) _ik(
    Offset s, Offset target, double a, double b, double bend) {
  final d = target - s;
  final dist0 = d.distance;
  if (dist0 < .001) return (s + Offset(0, a), s);
  final dist = dist0.clamp(.001, a + b - .001);
  final dir = d / dist0;
  final x = (a * a - b * b + dist * dist) / (2 * dist);
  final y = math.sqrt(math.max(0.0, a * a - x * x));
  final perp = Offset(-dir.dy, dir.dx) * bend;
  return (s + dir * x + perp * y, s + dir * dist);
}

// ------------------------------------------------------------ crowd
class _Slot {
  final int row; // 0 back, 1 middle, 2 front
  final double x; // 0..1
  final int look;
  final double seed;
  final bool couple;
  _Slot(this.row, this.x, this.look, this.seed, this.couple);
}

class Dancers {
  List<_Slot> _slots = [];
  double _forWidth = -1, _forHeight = -1;

  static const _rowScale = [.7, .84, 1.0];
  static const _rowSpacing = [.5, .6, .74];

  void _layout(Size size, double hFront) {
    if (_forWidth == size.width && _forHeight == size.height) return;
    _forWidth = size.width;
    _forHeight = size.height;
    final r = math.Random(42);
    final slots = <_Slot>[];
    for (var row = 0; row < 3; row++) {
      final h = hFront * _rowScale[row];
      final spacing = h * _rowSpacing[row];
      final n = math.max(3, (size.width / spacing).round());
      final step = size.width / n;
      final offset = row.isOdd ? step * .5 : step * .15;
      var i = 0;
      while (i < n) {
        final couple = row > 0 && i < n - 1 && r.nextDouble() < .2;
        final x = (offset +
                i * step +
                (r.nextDouble() - .5) * step * .3 +
                (couple ? step * .5 : 0)) /
            size.width;
        slots.add(
            _Slot(row, x, r.nextInt(_looks.length), r.nextDouble(), couple));
        i += couple ? 2 : 1;
      }
    }
    _slots = slots;
  }

  void paint(Canvas c, Size size, AudioAnalyzer a) {
    final alpha = (a.music.clamp(0.0, 1.0) * math.min(1.0, a.level * 25))
        .clamp(0.0, 1.0);
    if (alpha < .02) return;
    final hFront = math.min(size.height * .5, 170.0);
    _layout(size, hFront);

    // club light behind the crowd (no outline around the people)
    final hue = 205 + 55 * math.sin(a.time * .12);
    final light = Rect.fromCenter(
        center: Offset(size.width / 2, size.height - hFront * .45),
        width: size.width * 1.3,
        height: hFront * 2.4);
    c.drawOval(
        light,
        Paint()
          ..shader = RadialGradient(colors: [
            HSVColor.fromAHSV(((.55 + .25 * a.beat) * alpha).clamp(0.0, 1.0),
                    hue % 360, .45, 1)
                .toColor(),
            HSVColor.fromAHSV(.22 * alpha, (hue + 40) % 360, .7, .9).toColor(),
            Colors.transparent,
          ], stops: const [
            0,
            .5,
            1
          ]).createShader(light));

    final rowGround = [
      size.height - 6 - hFront * .27,
      size.height - 6 - hFront * .14,
      size.height - 3,
    ];
    final sil = _Sil();
    final step = a.bpm > 135 ? 2.0 : 1.0;
    for (final slot in _slots) {
      final h = hFront * _rowScale[slot.row];
      final ground = rowGround[slot.row];
      final beatF = (a.beatCount + a.phase) / step + slot.seed * .3;
      // slow wandering over the floor
      final x = slot.x * size.width +
          math.sin(beatF * math.pi / 8 + slot.seed * 9) * h * .12;
      if (slot.couple) {
        _couple(sil, x, ground, h, slot, beatF);
      } else {
        final look = _looks[slot.look];
        final res = _solo(look, slot, beatF);
        _build(sil, Offset(x, ground), h, look, res.$1, beatF + slot.seed,
            spin: res.$2);
      }
    }
    c.drawPath(
        sil.path, Paint()..color = Colors.black.withValues(alpha: alpha));
  }

  // ---------------------------------------------------------- solo motion
  (_Pose, double) _solo(_Look look, _Slot slot, double beatF) {
    final beat = beatF.floor();
    final phase = beatF - beat;
    final seedI = (slot.seed * 1000).floor();
    final moves = look.ballet ? _balletMoves : _partyMoves;
    final block = (beat + seedI) ~/ 8;
    final move = moves[(seedI * 7 + block * 3) % moves.length];
    final mirrored = (block + seedI).isOdd;
    _Pose pick(int b) {
      final p = move[b % move.length];
      return mirrored ? p.mirror() : p;
    }

    final from = pick(beat - 1 + seedI);
    final to = pick(beat + seedI);
    // smooth movement over most of the beat -> never frozen
    final t = _smooth(phase / .8);
    final base = _Pose.lerp(from, to, t);
    final spin = to.spin * 2 * math.pi * _smooth(phase / .9);
    final p = _groove2(base, beatF, slot.seed, look.ballet ? .45 : 1.0);
    return (
      _Pose(
        lArm: p.lArm,
        lElbow: p.lElbow,
        rArm: p.rArm,
        rElbow: p.rElbow,
        lLeg: p.lLeg,
        lKnee: p.lKnee,
        rLeg: p.rLeg,
        rKnee: p.rKnee,
        lean: p.lean,
        head: p.head,
        jump: to.jump * math.sin(math.pi * phase),
        sway: p.sway,
      ),
      spin
    );
  }

  /// Individual groove on top of the key poses.
  _Pose _groove2(_Pose b, double beatF, double seed, double amount) {
    const w = 2 * math.pi;
    final energy = (.7 + seed * .6) * amount;
    final phase = beatF - beatF.floor();
    final dip = math.pow(1 - phase, 2).toDouble() * .3 * energy;
    final alt = beatF.floor().isEven ? 1.0 : .45;
    return _Pose(
      lArm: b.lArm + .16 * energy * math.sin(w * (beatF * .5 + seed)),
      lElbow: b.lElbow + .28 * energy * math.sin(w * (beatF + seed * 1.7)),
      rArm: b.rArm + .16 * energy * math.sin(w * (beatF * .5 + seed + .5)),
      rElbow:
          b.rElbow + .28 * energy * math.sin(w * (beatF + seed * 1.7 + .5)),
      lLeg: b.lLeg,
      lKnee: b.lKnee + dip * alt,
      rLeg: b.rLeg,
      rKnee: b.rKnee + dip * (1.45 - alt),
      lean: b.lean + .1 * energy * math.sin(w * (beatF * .25 + seed * 2.3)),
      head: b.head + .12 * energy * math.sin(w * (beatF + seed * 3.1)),
      jump: b.jump,
      sway: b.sway + .55 * energy * math.sin(math.pi * beatF + seed * 5),
      spin: b.spin,
    );
  }

  // ---------------------------------------------------------- couples
  void _couple(_Sil s, double cx, double ground, double h, _Slot slot,
      double beatF) {
    final beat = beatF.floor();
    final seedI = (slot.seed * 1000).floor();
    final mode = ((beat + seedI) ~/ 8) % 3;
    final man = seedI.isEven ? _manLook : _manCap;
    final woman = seedI % 3 == 0 ? _womanCurl : _womanSwing;
    final hm = h * 1.04, hw = h * .96;
    final groove = math.sin(math.pi * beatF);

    if (mode == 0) {
      // swing-out: pull in / push out, holding hands
      final open = .5 + .5 * math.sin(math.pi * beatF / 2);
      final dist = h * (.42 + .38 * open);
      final mx = cx - dist / 2, wx = cx + dist / 2;
      final hands = Offset(cx, ground - h * (.6 + .05 * open));
      final pm = _groove2(
          _Pose(
              lArm: 1.3 + .3 * open,
              lElbow: .4,
              lean: -.22 * open,
              lLeg: .25,
              rLeg: .3,
              rKnee: .4,
              sway: -.3 * open),
          beatF,
          slot.seed,
          .6);
      final pw = _groove2(
          _Pose(
              rArm: 2.0 + .4 * open,
              rElbow: .5,
              lean: .25 * open,
              lLeg: .3,
              lKnee: .45,
              rLeg: .2,
              sway: .4 * open),
          beatF + .25,
          slot.seed + .3,
          .7);
      _build(s, Offset(mx, ground), hm, man, pm, beatF, handR: hands);
      _build(s, Offset(wx, ground), hw, woman, pw, beatF + .3, handL: hands);
    } else if (mode == 1) {
      // twirl: she spins under his raised arm
      final dist = h * .48;
      final mx = cx - dist / 2, wx = cx + dist / 2;
      final hands = Offset(cx - h * .02, ground - h * 1.1);
      final turn = 2 * math.pi * _smooth(((beatF / 2) % 1) / .85);
      final pm = _groove2(
          const _Pose(lArm: .9, lElbow: -1.0, lLeg: .2, rKnee: .3),
          beatF,
          slot.seed,
          .5);
      final pw = _Pose(
          rArm: 1.6 + .5 * groove.abs(),
          rElbow: .3,
          lLeg: .08,
          rLeg: .12,
          lKnee: .15,
          rKnee: .25);
      _build(s, Offset(mx, ground), hm, man, pm, beatF, handR: hands);
      _build(s, Offset(wx, ground), hw, woman, pw, beatF + .3,
          spin: turn, handL: hands);
    } else {
      // closed hold, stepping side to side together
      final dist = h * .34;
      final shift = math.sin(math.pi * beatF) * h * .1;
      final mx = cx - dist / 2 + shift, wx = cx + dist / 2 + shift;
      final pm = _groove2(
          _Pose(
              lArm: 1.9,
              lElbow: .9,
              lLeg: .2 + .15 * groove,
              lKnee: .3,
              rLeg: .2 - .15 * groove,
              lean: .06),
          beatF,
          slot.seed,
          .4);
      final pw = _groove2(
          _Pose(
              rArm: 1.9,
              rElbow: .9,
              lLeg: .2 - .15 * groove,
              rLeg: .2 + .15 * groove,
              rKnee: .3,
              lean: -.06,
              head: -.2),
          beatF,
          slot.seed + .5,
          .4);
      // his right hand on her back, her left hand on his shoulder
      _build(s, Offset(mx, ground), hm, man, pm, beatF,
          handR: Offset(wx - h * .02, ground - h * .58));
      _build(s, Offset(wx, ground), hw, woman, pw, beatF + .3,
          handL: Offset(mx + h * .08, ground - h * .8));
    }
  }

  // ---------------------------------------------------------- figure
  void _build(
      _Sil s, Offset foot, double h, _Look look, _Pose p, double swingT,
      {double spin = 0, Offset? handL, Offset? handR}) {
    final m = look.male;
    final shoulderHalf = h * (m ? .108 : .084);
    final waistHalf = h * (m ? .078 : .048);
    final hipHalf = h * (m ? .08 : .094);
    final torso = h * .28;
    final upperArm = h * .15, foreArm = h * .135;
    final thigh = h * .255, shin = h * .245;
    final armW = h * (m ? .036 : .029);
    final legW = h * (m ? .054 : .056);

    // spinning: the body is squeezed horizontally (min 25 %)
    var sx = math.cos(spin);
    if (sx.abs() < .25) sx = sx < 0 ? -.25 : .25;
    final spinFly = spin == 0 ? 0.0 : math.sin(spin).abs();

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

    final knL = legL + _dir(p.lLeg, -1) * thigh;
    final anL = knL + _dir(p.lLeg - p.lKnee, -1) * shin;
    final knR = legR + _dir(p.rLeg, 1) * thigh;
    final anR = knR + _dir(p.rLeg - p.rKnee, 1) * shin;

    final footH = h * (look.pointe ? .06 : look.heels ? .045 : .028);
    final lowest = math.max(anL.dy, anR.dy) + footH;
    final o = Offset(foot.dx, foot.dy - lowest - p.jump * h * .14);
    Offset t(Offset q) => Offset(o.dx + q.dx * sx, o.dy + q.dy);

    // ---- legs + feet
    for (final side in [-1.0, 1.0]) {
      final root = t(side < 0 ? legL : legR);
      final knee = t(side < 0 ? knL : knR);
      final ankle = t(side < 0 ? anL : anR);
      final fs = side * sx.sign;
      s.limb(root, knee, legW, legW * .66);
      if (look.flare) {
        s.limb(knee, ankle, legW * .66, legW * 1.05);
      } else {
        final mid = Offset.lerp(knee, ankle, .35)!;
        s.limb(knee, mid, legW * .66, legW * .62);
        s.limb(mid, ankle, legW * .62, legW * .36);
      }
      if (look.pointe) {
        s.limb(ankle, ankle + Offset(fs * h * .006, h * .058), legW * .34,
            h * .011);
      } else if (look.heels) {
        final toe = ankle + Offset(fs * h * .045, h * .042);
        s.limb(ankle, toe, legW * .4, h * .012);
        s.limb(ankle + Offset(-fs * h * .005, 0),
            ankle + Offset(-fs * h * .008, h * .045), h * .008, h * .006);
      } else {
        final toe = ankle + Offset(fs * h * .06, h * .02);
        s.limb(ankle + Offset(0, h * .008), toe, h * .022, h * .016);
      }
    }

    // ---- skirts
    if (look.dress != _Dress.none) {
      final swing = math.sin(2 * math.pi * swingT) * h * .025 +
          p.sway * h * .02 +
          math.sin(spin) * h * .05;
      final spread =
          math.max((knL.dx - legL.dx).abs(), (knR.dx - legR.dx).abs());
      double len, width, lift;
      if (look.dress == _Dress.tutu) {
        len = h * .085;
        width = hipHalf + h * .17 + spinFly * h * .05;
        lift = h * .03 * spinFly;
      } else if (look.dress == _Dress.long) {
        len = h * .42;
        width = hipHalf + h * .07 + spread * .8 + spinFly * h * .12;
        lift = h * .12 * spinFly;
      } else {
        len = h * .19;
        width = hipHalf + h * .05 + spread * .7 + spinFly * h * .1;
        lift = h * .06 * spinFly;
      }
      final hemY = hipC.dy + len - lift;
      final pts = <Offset>[t(waL), t(hpL)];
      const n = 8;
      for (var i = 0; i <= n; i++) {
        final f = i / n;
        final x = -width + 2 * width * f + swing;
        final y = hemY +
            math.sin(f * math.pi) * h * .012 +
            math.sin(f * math.pi * 3 + swingT * 6) * h * .006;
        pts.add(t(Offset(hipC.dx + x, y)));
      }
      pts
        ..add(t(hpR))
        ..add(t(waR));
      s.poly(pts);
      if (look.dress == _Dress.tutu) {
        s.ellipse(t(Offset(hipC.dx + swing * .5, hipC.dy + h * .035)),
            (width * .92 * sx).abs(), h * .04);
      }
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
      s.ellipse(t(Offset.lerp(shoulderC, waistC, .35)!),
          (shoulderHalf * .85 * sx).abs(), h * .05);
    }
    s.circle(t(shL), armW * 1.25);
    s.circle(t(shR), armW * 1.25);

    // ---- arms (angles, or IK towards a hand target for couples)
    for (final side in [-1.0, 1.0]) {
      final sh = t(side < 0 ? shL : shR);
      final target = side < 0 ? handL : handR;
      Offset el, ha;
      if (target != null) {
        final r = _ik(sh, target, upperArm, foreArm, -side);
        el = r.$1;
        ha = r.$2;
      } else {
        final a1 = side < 0 ? p.lArm : p.rArm;
        final a2 = side < 0 ? p.lElbow : p.rElbow;
        final shLocal = side < 0 ? shL : shR;
        final elLocal = shLocal + _dir(a1, side) * upperArm;
        final haLocal = elLocal + _dir(a1 + a2, side) * foreArm;
        el = t(elLocal);
        ha = t(haLocal);
      }
      s.limb(sh, el, armW * 1.15, armW * .85);
      s.limb(el, ha, armW * .85, armW * .6);
      final d = ha - el;
      final len = d.distance;
      final handC = len > 0 ? ha + d / len * (h * .022) : ha;
      s.ellipse(handC, h * .02, h * .022, 8);
    }

    // ---- neck + head
    s.limb(t(shoulderC), t(neck), h * .03, h * .026);
    s.ellipse(t(headC), (h * .052 * sx).abs().clamp(h * .03, h), h * .064);

    // ---- hair (swings, flies out when spinning)
    final swingX = math.sin(2 * math.pi * swingT) * h * .035 -
        p.lean * h * .12 -
        p.head * h * .06 +
        math.sin(spin) * h * .09;
    final hc = t(headC);
    final top = t(headC + headUp * (h * .03));
    final narrow = sx.abs().clamp(.6, 1.0);
    Offset hp(double dx, double dy) => hc + Offset(dx, dy);
    switch (look.hair) {
      case _Hair.short:
        s.ellipse(top, h * .056 * narrow, h * .042);
      case _Hair.cap:
        s.ellipse(top, h * .058 * narrow, h * .04);
        s.limb(top + Offset(h * .02 * sx, h * .015),
            top + Offset(h * .095 * sx, h * .023), h * .012, h * .01);
      case _Hair.long:
        s.ellipse(top, h * .062 * narrow, h * .05);
        s.poly([
          hp(-h * .062, -h * .035),
          hp(-h * .074 + swingX * .5, h * .05),
          hp(-h * .07 + swingX, h * .14),
          hp(-h * .045 + swingX * 1.25, h * .2),
          hp(-h * .005 + swingX * 1.3, h * .175),
          hp(h * .035 + swingX * 1.15, h * .2),
          hp(h * .062 + swingX, h * .12),
          hp(h * .066 + swingX * .4, h * .03),
          hp(h * .055, -h * .04),
        ]);
      case _Hair.ponytail:
        s.ellipse(top, h * .058 * narrow, h * .045);
        final root = top + Offset(h * .04 * sx, -h * .01);
        s.limb(root, root + Offset(h * .05 * sx + swingX * 1.6, h * .13),
            h * .03, h * .01);
      case _Hair.curly:
        for (var k = 0; k < 9; k++) {
          final ang = -math.pi + k * math.pi / 8;
          s.circle(
              hc +
                  Offset(math.cos(ang) * h * .06 * narrow + swingX * .3,
                      math.sin(ang) * h * .065 + h * .01),
              h * (.034 + (k.isEven ? .006 : 0)));
        }
        s.circle(hp(-h * .07 * narrow + swingX * .5, h * .06), h * .03);
        s.circle(hp(h * .07 * narrow + swingX * .5, h * .06), h * .03);
      case _Hair.afro:
        s.circle(top + Offset(swingX * .2, -h * .005), h * .1);
      case _Hair.bun:
        s.ellipse(top, h * .055 * narrow, h * .04);
        s.circle(top + Offset(0, -h * .045), h * .028);
    }
  }
}
