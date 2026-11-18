import 'dart:io' show ZLibCodec;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../services/audio_analyzer.dart';

// =====================================================================
//  Dance floor with black silhouettes.
//
//  assets/dance/silhouettes.bin holds 32 dancers cut out of two
//  green-screen silhouette videos (tool/cut_green_raw.py +
//  tool/pack_silhouettes.py): the exact outline of every video frame at
//  30 fps - no smoothing, no morphing. The app simply plays these frames
//  (speed matched to the BPM), mirrored or not, in three staggered rows,
//  all filled pure black in front of a coloured club light.
// =====================================================================

class DanceClip {
  final double fps, bpm, cx, ground, height;

  /// frames -> polygons -> x,y pairs (pixels)
  final List<List<Int16List>> frames;
  DanceClip(this.fps, this.bpm, this.cx, this.ground, this.height, this.frames);
}

class DanceLibrary {
  static List<DanceClip>? clips;
  static bool _loading = false;

  static void ensureLoaded() {
    if (clips != null || _loading) return;
    _loading = true;
    rootBundle.load('assets/dance/silhouettes.bin').then((bd) {
      final raw = ZLibCodec().decode(bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes));
      clips = _parse(ByteData.sublistView(Uint8List.fromList(raw)));
    }).catchError((_) {
      clips = const [];
    });
  }

  static List<DanceClip> _parse(ByteData b) {
    const le = Endian.little;
    if (b.lengthInBytes < 8 ||
        String.fromCharCodes(
                [b.getUint8(0), b.getUint8(1), b.getUint8(2), b.getUint8(3)]) !=
            'SLXR') {
      return const [];
    }
    final n = b.getUint16(6, le);
    var o = 8;
    final out = <DanceClip>[];
    for (var c = 0; c < n; c++) {
      final frameCount = b.getUint16(o, le);
      final fps = b.getFloat32(o + 2, le);
      final bpm = b.getFloat32(o + 6, le);
      final cx = b.getFloat32(o + 10, le);
      final ground = b.getFloat32(o + 14, le);
      final height = b.getFloat32(o + 18, le);
      o += 22;
      final frames = <List<Int16List>>[];
      for (var f = 0; f < frameCount; f++) {
        final polys = b.getUint8(o);
        o += 1;
        final list = <Int16List>[];
        for (var p = 0; p < polys; p++) {
          final pts = b.getUint16(o, le);
          var x = b.getInt16(o + 2, le);
          var y = b.getInt16(o + 4, le);
          o += 6;
          final xy = Int16List(pts * 2);
          xy[0] = x;
          xy[1] = y;
          for (var i = 1; i < pts; i++) {
            x += b.getInt8(o);
            y += b.getInt8(o + 1);
            o += 2;
            xy[i * 2] = x;
            xy[i * 2 + 1] = y;
          }
          list.add(xy);
        }
        frames.add(list);
      }
      out.add(DanceClip(fps, bpm, cx, ground, height, frames));
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
  double pos; // current frame position
  _Slot(this.row, this.x, this.clip, this.seed, this.mirror, this.pos);
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
    // shuffled clip order, so neighbours are different dancers
    final order = List<int>.generate(clips.length, (i) => i)..shuffle(r);
    var next = 0;
    for (var row = 0; row < 3; row++) {
      final h = hFront * _rowScale[row];
      final n = math.max(3, (size.width / (h * _rowSpacing[row])).round());
      final step = size.width / n;
      final offset = row.isOdd ? step * .5 : step * .15;
      for (var i = 0; i < n; i++) {
        final clip = order[next++ % order.length];
        final seed = r.nextDouble();
        slots.add(_Slot(
          row,
          (offset + i * step + (r.nextDouble() - .5) * step * .3) / size.width,
          clip,
          seed,
          r.nextBool(),
          seed * clips[clip].frames.length,
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
      var clipBpm = clip.bpm;
      while (clipBpm > 145) {
        clipBpm /= 2;
      }
      final rate = (a.bpm / clipBpm).clamp(.8, 1.25);
      final count = clip.frames.length;
      slot.pos = (slot.pos + a.dt * clip.fps * rate) % count;

      final h = hFront * _rowScale[slot.row];
      final ground = rowGround[slot.row];
      final x0 = slot.x * size.width;
      final sx = (slot.mirror ? -1.0 : 1.0) * h / clip.height;
      final sy = h / clip.height;
      for (final poly in clip.frames[slot.pos.floor() % count]) {
        final n = poly.length ~/ 2;
        final pts = List<Offset>.generate(
            n,
            (i) => Offset(x0 + (poly[i * 2] - clip.cx) * sx,
                ground + (poly[i * 2 + 1] - clip.ground) * sy));
        // mirrored outlines run the other way round: keep one winding so
        // that overlapping people unite without holes
        path.addPolygon(slot.mirror ? pts.reversed.toList() : pts, true);
      }
    }
    c.drawPath(path, Paint()..color = Colors.black.withValues(alpha: alpha));
  }
}
