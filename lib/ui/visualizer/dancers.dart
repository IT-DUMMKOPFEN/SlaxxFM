import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../services/audio_analyzer.dart';

// =====================================================================
//  Dance floor with natural moving people.
//
//  The motion comes from real dancers: assets/dance/dancers.bin holds
//  the outlines of 7 people from free green-screen dance videos
//  (tool/extract_dancers.py): 15 outlines per second, 96 points each,
//  aligned frame to frame so that the app can morph smoothly between
//  them. Every dancer on the floor plays one of these clips (mirrored or
//  not, own start point and size), at a speed matched to the BPM.
//
//  All people are filled pure black, in three staggered rows, with a
//  coloured club light behind them.
// =====================================================================

class DanceClip {
  final int frames;
  final int points;
  final double fps;
  final double bpm;

  /// frames * points * 2 (x, y), body height = 1, floor at y = 0.
  final Float32List data;
  DanceClip(this.frames, this.points, this.fps, this.bpm, this.data);
}

class DanceLibrary {
  static List<DanceClip>? clips;
  static bool _loading = false;

  static void ensureLoaded() {
    if (clips != null || _loading) return;
    _loading = true;
    rootBundle.load('assets/dance/dancers.bin').then((bd) {
      clips = _parse(bd);
    }).catchError((_) {
      clips = const [];
    });
  }

  static List<DanceClip> _parse(ByteData bd) {
    const le = Endian.little;
    if (bd.lengthInBytes < 8 ||
        String.fromCharCodes(
                [bd.getUint8(0), bd.getUint8(1), bd.getUint8(2), bd.getUint8(3)]) !=
            'SLXD') {
      return const [];
    }
    final n = bd.getUint16(6, le);
    var o = 8;
    final out = <DanceClip>[];
    for (var s = 0; s < n; s++) {
      final frames = bd.getUint16(o, le);
      final points = bd.getUint16(o + 2, le);
      final fps = bd.getFloat32(o + 4, le);
      final bpm = bd.getFloat32(o + 8, le);
      o += 12;
      final count = frames * points * 2;
      final data = Float32List(count);
      for (var i = 0; i < count; i++) {
        data[i] = bd.getInt16(o, le) / 8000.0;
        o += 2;
      }
      out.add(DanceClip(frames, points, fps, bpm, data));
    }
    return out;
  }
}

class _Slot {
  final int row; // 0 back, 1 middle, 2 front
  final double x; // 0..1
  final int clip;
  final double seed;
  final bool mirror;
  final double width;
  double pos; // current frame position
  _Slot(this.row, this.x, this.clip, this.seed, this.mirror, this.width,
      this.pos);
}

class Dancers {
  List<_Slot> _slots = [];
  double _forWidth = -1, _forHeight = -1;

  static const _rowScale = [.7, .84, 1.0];
  static const _rowSpacing = [.42, .5, .6];

  void _layout(Size size, double hFront, List<DanceClip> clips) {
    if (_forWidth == size.width && _forHeight == size.height) return;
    _forWidth = size.width;
    _forHeight = size.height;
    final r = math.Random(42);
    final slots = <_Slot>[];
    for (var row = 0; row < 3; row++) {
      final h = hFront * _rowScale[row];
      final n = math.max(3, (size.width / (h * _rowSpacing[row])).round());
      final step = size.width / n;
      final offset = row.isOdd ? step * .5 : step * .15;
      for (var i = 0; i < n; i++) {
        final clip = r.nextInt(clips.length);
        final seed = r.nextDouble();
        slots.add(_Slot(
          row,
          (offset + i * step + (r.nextDouble() - .5) * step * .3) / size.width,
          clip,
          seed,
          r.nextBool(),
          .92 + r.nextDouble() * .16,
          seed * clips[clip].frames,
        ));
      }
    }
    _slots = slots;
  }

  void paint(Canvas c, Size size, AudioAnalyzer a) {
    DanceLibrary.ensureLoaded();
    final clips = DanceLibrary.clips;
    if (clips == null || clips.isEmpty) return;
    final alpha = (a.music.clamp(0.0, 1.0) * math.min(1.0, a.level * 25))
        .clamp(0.0, 1.0);
    if (alpha < .02) return;
    final hFront = math.min(size.height * .5, 170.0);
    _layout(size, hFront, clips);

    // club light behind the crowd
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
    final path = Path();
    for (final slot in _slots) {
      final clip = clips[slot.clip];
      // play at a speed that matches the music
      var clipBpm = clip.bpm;
      while (clipBpm > 145) {
        clipBpm /= 2;
      }
      final rate = (a.bpm / clipBpm).clamp(.8, 1.25);
      slot.pos = (slot.pos + a.dt * clip.fps * rate) % clip.frames;

      final h = hFront * _rowScale[slot.row];
      final ground = rowGround[slot.row];
      final x0 = slot.x * size.width +
          math.sin(a.time * .25 + slot.seed * 9) * h * .1;
      final i0 = slot.pos.floor();
      final i1 = i0 + 1;
      // no morph across the loop point
      final f = i1 >= clip.frames ? 0.0 : slot.pos - i0;
      final b0 = i0 * clip.points * 2;
      final b1 = (i1 % clip.frames) * clip.points * 2;
      final sx = (slot.mirror ? -1.0 : 1.0) * h * slot.width;
      final pts = List<Offset>.filled(clip.points, Offset.zero);
      for (var k = 0; k < clip.points; k++) {
        final j0 = b0 + k * 2, j1 = b1 + k * 2;
        final px = clip.data[j0] + (clip.data[j1] - clip.data[j0]) * f;
        final py = clip.data[j0 + 1] + (clip.data[j1 + 1] - clip.data[j0 + 1]) * f;
        pts[k] = Offset(x0 + px * sx, ground + py * h);
      }
      // mirrored outlines run the other way round: keep one winding so
      // that the non-zero fill unites overlapping people without holes
      path.addPolygon(slot.mirror ? pts.reversed.toList() : pts, true);
    }
    c.drawPath(path, Paint()..color = Colors.black.withValues(alpha: alpha));
  }
}
