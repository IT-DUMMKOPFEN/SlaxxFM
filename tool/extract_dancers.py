"""Extracts dancing silhouettes from green-screen videos.

For every person: outer contour per frame (15 fps), resampled to N points by
arc length, cyclically aligned to the previous frame (so frames can be
morphed), normalised to body height 1 with the floor at y=0.
Output: binary asset (little endian)
  'SLXD' u16 version u16 nSeq
  per seq: u16 frames, u16 points, f32 fps, f32 bpm, then frames*points*2 int16 (x,y)*8000
"""
import cv2, numpy as np, struct, sys, json

N = 96
FPS = 15
MAXSEC = 30
SCALE = 8000

clips = [
    # file, persons, start sec, end sec
    ('27127173-FREE_HD_Green_Screen_-_DANCING_SILHOUETTE_1.mp4', 3, 4, 66),
    ('3782929d-FREE_HD_Green_Screen_DANCING_GIRLS_Silhouette_01.mp4', 1, 4, 24),
    ('7b7f17d5-FREE_HD_Green_Screen_DANCING_GIRLS_Silhouette_02.mp4', 1, 4, 61),
    ('4a8d879a-Girl_Dancing_in_black_dress_green_screen_green_screen_girl_download_dance_greenscreen_lady_girl.mp4', 1, 0, 30),
    ('abe2ea53-Woman_Dancing_Hip_Hop_Green_Screen_-__Chroma_Key_-_No_Copyright.mp4', 1, 0, 16.5),
]

def person_mask(frame):
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    bg = cv2.inRange(hsv, (35, 70, 50), (90, 255, 255))
    fg = cv2.bitwise_not(bg)
    fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    return fg, bg.mean() / 255

def resample(cnt, n):
    pts = cnt[:, 0, :].astype(np.float64)
    pts = np.vstack([pts, pts[:1]])
    seg = np.sqrt(((pts[1:] - pts[:-1]) ** 2).sum(1))
    cum = np.concatenate([[0], np.cumsum(seg)])
    total = cum[-1]
    t = np.linspace(0, total, n, endpoint=False)
    x = np.interp(t, cum, pts[:, 0]); y = np.interp(t, cum, pts[:, 1])
    out = np.stack([x, y], 1)
    # consistent orientation (positive shoelace area in screen coords)
    a = (out[:, 0] * np.roll(out[:, 1], -1) - np.roll(out[:, 0], -1) * out[:, 1]).sum()
    if a < 0: out = out[::-1].copy()
    # start at the top-most point
    return np.roll(out, -int(np.argmin(out[:, 1])), axis=0)

def align(prev, cur):
    best, bs = None, 0
    for s in range(len(cur)):
        d = ((np.roll(cur, -s, axis=0) - prev) ** 2).sum()
        if best is None or d < best: best, bs = d, s
    return np.roll(cur, -bs, axis=0)

def tempo(sig, fps):
    sig = np.asarray(sig, float); sig = sig - np.convolve(sig, np.ones(9) / 9, 'same')
    sig = np.diff(sig); sig = np.maximum(sig, 0)
    ac = np.correlate(sig - sig.mean(), sig - sig.mean(), 'full')[len(sig) - 1:]
    lo, hi = int(fps * 60 / 170), int(fps * 60 / 75) + 1
    if hi >= len(ac): return 110.0
    k = lo + int(np.argmax(ac[lo:hi]))
    if 0 < k < len(ac) - 1:
        a, b, c = ac[k - 1], ac[k], ac[k + 1]; d = a - 2 * b + c
        kk = k + (0.5 * (a - c) / d if abs(d) > 1e-9 else 0)
    else: kk = k
    bpm = 60 * fps / kk
    while bpm < 85: bpm *= 2
    while bpm > 165: bpm /= 2
    return float(bpm)

src = sys.argv[1]; out_path = sys.argv[2]
seqs = []
for fname, persons, t0, t1 in clips:
    cap = cv2.VideoCapture(f'{src}/{fname}')
    vfps = cap.get(cv2.CAP_PROP_FPS)
    tracks = [[] for _ in range(persons)]
    t = t0
    while t < t1 and t - t0 < MAXSEC * (1 if persons == 1 else 1):
        cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
        ok, fr = cap.read()
        if not ok: break
        t += 1 / FPS
        m, green = person_mask(fr)
        if green < .5: continue  # title / black frames
        cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
        cnts = [c for c in cnts if cv2.contourArea(c) > fr.shape[0] * fr.shape[1] * .004
                and cv2.boundingRect(c)[3] > fr.shape[0] * .25 and cv2.boundingRect(c)[2] < fr.shape[1] * .8]
        cnts = sorted(cnts, key=cv2.contourArea, reverse=True)[:persons]
        if len(cnts) < persons: continue
        cnts = sorted(cnts, key=lambda c: cv2.boundingRect(c)[0])  # left to right
        for i, c in enumerate(cnts):
            x, y, w, h = cv2.boundingRect(c)
            mom = cv2.moments(c)
            tracks[i].append(dict(pts=resample(c, N), bottom=y + h, h=h, cx=mom['m10'] / mom['m00'], cy=mom['m01'] / mom['m00']))
    for tr in tracks:
        if len(tr) < 60: continue
        ground = np.percentile([f['bottom'] for f in tr], 90)
        H = np.percentile([f['h'] for f in tr], 70)
        # remove walking across the screen (2 s moving average), keep sway
        cxs = np.array([f['cx'] for f in tr])
        k = 31; pad = np.pad(cxs, k // 2, mode='edge')
        cxs = np.convolve(pad, np.ones(k) / k, 'valid')
        frames = []; prev = None
        for f, cx in zip(tr, cxs):
            p = f['pts'].copy()
            p[:, 0] = (p[:, 0] - cx) / H; p[:, 1] = (p[:, 1] - ground) / H
            p[:, 0] = np.clip(p[:, 0], -1.2, 1.2)
            if prev is not None: p = align(prev, p)
            frames.append(p); prev = p
        bpm = tempo([f['cy'] for f in tr], FPS)
        seqs.append(dict(name=fname[:8], frames=np.array(frames), bpm=bpm))
        print(fname[:8], len(frames), 'frames', round(bpm, 1), 'bpm', 'H', round(H))

with open(out_path, 'wb') as f:
    f.write(b'SLXD'); f.write(struct.pack('<HH', 1, len(seqs)))
    for s in seqs:
        fr = s['frames']
        f.write(struct.pack('<HHff', fr.shape[0], fr.shape[1], FPS, s['bpm']))
        f.write(np.clip(np.round(fr * SCALE), -32767, 32767).astype('<i2').tobytes())
np.save('/tmp/vid/seqs.npy', np.array([s['frames'] for s in seqs], dtype=object), allow_pickle=True)
print('bytes', sum(s['frames'].size * 2 for s in seqs))
