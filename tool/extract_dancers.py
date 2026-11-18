"""Extracts dancing silhouettes from green-screen videos (v2).

Per person and output frame (15 fps):
  * soft green key on an up-scaled frame (small videos x2), dark green
    floor shadows count as background
  * mask averaged over 3 neighbouring video frames + blurred -> smooth,
    flicker-free edges on thin legs / ankles / heels
  * foot band (lowest 7 %) closed horizontally -> solid shoe shapes
  * outer contour resampled with fixed anchors: head (top), first foot,
    second foot -> 76 + 40 + 76 = 192 points, so the same point number
    always belongs to the same body part and morphing does not slide
  * normalised to body height 1, floor at y = 0, walking removed
  * light temporal smoothing of the points
Output: 'SLXD' u16 version u16 nSeq, per seq u16 frames, u16 points,
f32 fps, f32 bpm, frames*points*2 int16 (x,y)*8000, little endian.
"""
import cv2, numpy as np, struct, sys

FPS = 15
ARCS = (76, 40, 76)
N = sum(ARCS)
SCALE = 8000
MAXSEC = 30

clips = [
    ('27127173-FREE_HD_Green_Screen_-_DANCING_SILHOUETTE_1.mp4', 3, 4, 66),
    ('3782929d-FREE_HD_Green_Screen_DANCING_GIRLS_Silhouette_01.mp4', 1, 4, 24),
    ('7b7f17d5-FREE_HD_Green_Screen_DANCING_GIRLS_Silhouette_02.mp4', 1, 4, 61),
    ('4a8d879a-Girl_Dancing_in_black_dress_green_screen_green_screen_girl_download_dance_greenscreen_lady_girl.mp4', 1, 0, 30),
]
# per clip key (min saturation, min value), e.g. for hair with green spill
KEY = {}

def soft_fg(frame, up, key=(55, 18)):
    if up != 1:
        frame = cv2.resize(frame, None, fx=up, fy=up, interpolation=cv2.INTER_CUBIC)
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    bg = cv2.inRange(hsv, (33, key[0], key[1]), (92, 255, 255))
    fg = (255 - bg).astype(np.float32) / 255
    green = bg.mean() / 255
    return fg, green

def resample_arc(pts, n):
    seg = np.sqrt(((pts[1:] - pts[:-1]) ** 2).sum(1))
    cum = np.concatenate([[0], np.cumsum(seg)])
    if cum[-1] <= 0: return np.repeat(pts[:1], n, 0)
    t = np.linspace(0, cum[-1], n, endpoint=False)
    return np.stack([np.interp(t, cum, pts[:, 0]), np.interp(t, cum, pts[:, 1])], 1)

def anchored(cnt):
    p = cnt[:, 0, :].astype(np.float64)
    a = (p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1]).sum()
    if a < 0: p = p[::-1].copy()
    ys, xs = p[:, 1], p[:, 0]
    top_y = ys.min(); cx = xs.mean()
    tops = np.where(ys <= top_y + 1)[0]
    top = tops[np.argmin(np.abs(xs[tops] - cx))]
    p = np.roll(p, -top, axis=0); xs, ys = p[:, 0], p[:, 1]
    h = ys.max() - ys.min()
    band = np.where(ys >= ys.max() - .08 * h)[0]
    right = band[xs[band] >= cx]; left = band[xs[band] < cx]
    if len(right) == 0 or len(left) == 0:
        med = np.median(xs[band]); right = band[xs[band] >= med]; left = band[xs[band] < med]
    if len(right) == 0 or len(left) == 0:
        return resample_arc(np.vstack([p, p[:1]]), N)
    fa = right[np.argmax(ys[right])]; fb = left[np.argmax(ys[left])]
    i1, i2 = sorted([fa, fb])
    if i1 == 0 or i1 == i2: return resample_arc(np.vstack([p, p[:1]]), N)
    out = [resample_arc(p[0:i1 + 1], ARCS[0]),
           resample_arc(p[i1:i2 + 1], ARCS[1]),
           resample_arc(np.vstack([p[i2:], p[:1]]), ARCS[2])]
    return np.vstack(out)

def fix_feet(mask, x, y, w, h):
    y0 = int(y + h * .93); y1 = y + h
    k = max(3, int(h * .035)) | 1
    band = mask[y0:y1, x:x + w]
    mask[y0:y1, x:x + w] = cv2.morphologyEx(band, cv2.MORPH_CLOSE, np.ones((3, k), np.uint8))
    return mask

def tempo(sig, fps):
    sig = np.asarray(sig, float); sig = sig - np.convolve(sig, np.ones(9) / 9, 'same')
    sig = np.maximum(np.diff(sig), 0)
    ac = np.correlate(sig - sig.mean(), sig - sig.mean(), 'full')[len(sig) - 1:]
    lo, hi = int(fps * 60 / 170), int(fps * 60 / 75) + 1
    k = lo + int(np.argmax(ac[lo:hi]))
    a, b, c = ac[k - 1], ac[k], ac[k + 1]; d = a - 2 * b + c
    kk = k + (0.5 * (a - c) / d if abs(d) > 1e-9 else 0)
    bpm = 60 * fps / kk
    while bpm < 85: bpm *= 2
    while bpm > 165: bpm /= 2
    return float(bpm)

src, out_path = sys.argv[1], sys.argv[2]
seqs = []
for fname, persons, t0, t1 in clips:
    cap = cv2.VideoCapture(f'{src}/{fname}')
    vfps = cap.get(cv2.CAP_PROP_FPS)
    vh = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
    up = 2 if vh < 600 else 1
    t1 = min(t1, t0 + MAXSEC)
    cap.set(cv2.CAP_PROP_POS_MSEC, max(0, t0 - .2) * 1000)
    buf = []  # (time, fg, green)
    tracks = [[] for _ in range(persons)]
    next_t = t0
    while True:
        ok, fr = cap.read()
        if not ok: break
        t = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000
        fg, green = soft_fg(fr, up, KEY.get(fname[:8], (55, 18)))
        buf.append((t, fg, green)); buf = buf[-3:]
        if len(buf) < 3: continue
        tm, _, gm = buf[1]
        if tm < next_t: continue
        if tm > t1: break
        next_t += 1 / FPS
        if gm < .5: continue
        avg = (buf[0][1] + buf[1][1] * 2 + buf[2][1]) / 4
        avg = cv2.GaussianBlur(avg, (0, 0), 1.2 * up)
        m = (avg > .5).astype(np.uint8) * 255
        m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        H_, W_ = m.shape
        n, lab, stats, cent = cv2.connectedComponentsWithStats(m)
        cands = [i for i in range(1, n) if stats[i, 4] > H_ * W_ * .004
                 and stats[i, 3] > H_ * .25 and stats[i, 2] < W_ * .8]
        cands = sorted(cands, key=lambda i: -stats[i, 4])[:persons]
        if len(cands) < persons: continue
        cands = sorted(cands, key=lambda i: stats[i, 0])
        for k, i in enumerate(cands):
            x, y, w, h = stats[i, :4]
            pm = (lab == i).astype(np.uint8) * 255
            pm = fix_feet(pm, x, y, w, h)
            cnts, _ = cv2.findContours(pm, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
            c = max(cnts, key=cv2.contourArea)
            tracks[k].append(dict(pts=anchored(c) / up, bottom=(y + h) / up, h=h / up,
                                  cx=cent[i][0] / up, cy=cent[i][1] / up))
    for tr in tracks:
        if len(tr) < 60: continue
        ground = np.percentile([f['bottom'] for f in tr], 90)
        H = np.percentile([f['h'] for f in tr], 70)
        cxs = np.array([f['cx'] for f in tr]); kw = 31
        cxs = np.convolve(np.pad(cxs, kw // 2, mode='edge'), np.ones(kw) / kw, 'valid')
        fr = np.array([f['pts'] for f in tr])
        fr[:, :, 0] = (fr[:, :, 0] - cxs[:, None]) / H
        fr[:, :, 1] = (fr[:, :, 1] - ground) / H
        fr[:, :, 0] = np.clip(fr[:, :, 0], -1.2, 1.2)
        # light temporal smoothing (1-2-1)
        sm = fr.copy(); sm[1:-1] = (fr[:-2] + 2 * fr[1:-1] + fr[2:]) / 4
        bpm = tempo([f['cy'] for f in tr], FPS)
        seqs.append(dict(name=fname[:8], frames=sm, bpm=bpm))
        print(fname[:8], len(sm), 'frames', round(bpm, 1), 'bpm', 'H', round(H))

with open(out_path, 'wb') as f:
    f.write(b'SLXD'); f.write(struct.pack('<HH', 2, len(seqs)))
    for s in seqs:
        fr = s['frames']
        f.write(struct.pack('<HHff', fr.shape[0], fr.shape[1], FPS, s['bpm']))
        f.write(np.clip(np.round(fr * SCALE), -32767, 32767).astype('<i2').tobytes())
np.save('/tmp/vid/seqs.npy', np.array([s['frames'] for s in seqs], dtype=object), allow_pickle=True)
print('bytes', sum(s['frames'].size * 2 for s in seqs))
