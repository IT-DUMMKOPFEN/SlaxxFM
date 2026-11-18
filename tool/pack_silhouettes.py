"""Packs the exact outlines of the chosen green-screen dancers into
assets/dance/silhouettes.bin (zlib). No smoothing, no resampling: the
outline of every video frame (30 fps) is kept, stored at half resolution
(points closer than 0.5 px merged) - far more detail than the app shows.

Format (little endian, zlib-compressed):
  'SLXR' u16 version=3 u16 clips
  per clip: u16 frames, f32 fps, f32 bpm, f32 cx, f32 ground, f32 height
    per frame: u8 polygons
      per polygon: u16 points, i16 x0, i16 y0, then (points-1) x (i8 dx, i8 dy)
Coordinates are pixels of the half-size quadrant; the app normalises with
(x - cx) / height and (y - ground) / height.
usage: pack_silhouettes.py mapping_raw.json raw_dir out.bin
"""
import sys, json, pickle, struct, zlib, numpy as np, cv2

def tempo(sig, fps):
    sig = np.asarray(sig, float); sig = sig - np.convolve(sig, np.ones(9) / 9, 'same')
    sig = np.maximum(np.diff(sig), 0)
    ac = np.correlate(sig - sig.mean(), sig - sig.mean(), 'full')[len(sig) - 1:]
    lo, hi = int(fps * 60 / 170), int(fps * 60 / 75) + 1
    k = lo + int(np.argmax(ac[lo:hi])); a, b, c = ac[k - 1], ac[k], ac[k + 1]; d = a - 2 * b + c
    kk = k + (0.5 * (a - c) / d if abs(d) > 1e-9 else 0)
    bpm = 60 * fps / kk if kk > 0 else 110.0
    if not np.isfinite(bpm): return 110.0
    while bpm < 85: bpm *= 2
    while bpm > 165: bpm /= 2
    return float(bpm)

mapping, raw_dir, out = sys.argv[1], sys.argv[2], sys.argv[3]
m = {int(k): v for k, v in json.load(open(mapping)).items()}
buf = bytearray(b'SLXR' + struct.pack('<HH', 3, len(m)))
total = 0
for nr in sorted(m):
    d = pickle.load(open(f'{raw_dir}/{m[nr]}.pkl', 'rb'))
    frames = []
    cys, cxs = [], []
    for polys in d['frames']:
        fp = []
        for p in polys:
            q = cv2.approxPolyDP((p.astype(np.float32) / 2).round().astype(np.int32).reshape(-1, 1, 2), .5, True)[:, 0, :]
            if len(q) < 3: continue
            area = (q[:, 0] * np.roll(q[:, 1], -1) - np.roll(q[:, 0], -1) * q[:, 1]).sum()
            if area < 0: q = q[::-1]
            # split steps that do not fit into int8
            pts = [q[0]]
            for a in q[1:]:
                while np.abs(a - pts[-1]).max() > 127:
                    pts.append(pts[-1] + np.clip(a - pts[-1], -127, 127))
                pts.append(a)
            fp.append(np.array(pts, np.int32))
        allp = np.vstack(fp); cys.append((allp[:, 1].min() + allp[:, 1].max()) / 2); cxs.append(allp[:, 0].mean())
        frames.append(fp)
    fps = d['fps']
    buf += struct.pack('<Hfffff', len(frames), fps, tempo(cys, fps), float(np.median(cxs)),
                       d['ground'] / 2, d['height'] / 2)
    for fp in frames:
        buf += struct.pack('<B', len(fp))
        for p in fp:
            buf += struct.pack('<Hhh', len(p), int(p[0, 0]), int(p[0, 1]))
            buf += np.diff(p, axis=0).astype(np.int8).tobytes()
            total += len(p)
    print(nr, m[nr], len(frames), 'frames')
z = zlib.compress(bytes(buf), 9)
open(out, 'wb').write(z)
print('points', total, 'raw', len(buf), 'compressed', len(z))
