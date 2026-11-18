"""Cuts the black dancers out of the 2x2 green-screen grid videos EXACTLY:
native 30 fps, outline taken pixel-exact from the mask (only redundant
points on straight lines dropped), original position in the quadrant,
no resampling, no smoothing, no centring. Scene cuts split the clips.
"""
import sys, os, numpy as np, cv2, pickle
sys.path.insert(0, os.path.dirname(__file__))
from models import frames
OUT = '/tmp/raw'; os.makedirs(OUT, exist_ok=True)
VIDEOS = [('disco', '/mnt/user-data/uploads/Disco_Silhouetten_Greenscreen.mp4'),
          ('sexy', '/mnt/user-data/uploads/6449f356-Sexy_Dance_Silhouetten_Greenscreen.mp4')]
FPS = 30
for vid, path in VIDEOS:
    if len(sys.argv) > 1 and vid not in sys.argv[1:]: continue
    segs = {q: [[]] for q in range(4)}; prev = {q: None for q in range(4)}; k = 0
    for t, fr in frames(path, 0, 180, FPS, 1920):
        H, W = fr.shape[:2]
        hsv = cv2.cvtColor(fr, cv2.COLOR_BGR2HSV)
        fg = cv2.inRange(hsv, (0, 0, 0), (180, 255, 90))
        for q in range(4):
            qx, qy = (q % 2) * W // 2, (q // 2) * H // 2
            sub = fg[qy:qy + H // 2, qx:qx + W // 2]
            cnts, _ = cv2.findContours(sub, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            cnts = [c for c in cnts if cv2.contourArea(c) > 20]
            cur = segs[q][-1]
            if not cnts or max(cv2.contourArea(c) for c in cnts) < 400:
                if cur: segs[q].append([])
                prev[q] = None; continue
            small = cv2.resize(sub, (96, 54), interpolation=cv2.INTER_AREA) > 127
            if prev[q] is not None:
                inter = (small & prev[q]).sum(); uni = (small | prev[q]).sum()
                if uni and inter / uni < .35 and cur: segs[q].append([]); cur = segs[q][-1]
            prev[q] = small
            polys = [c[:, 0, :].astype(np.int16) for c in cnts]
            x, y, w, h = cv2.boundingRect(np.vstack(polys).astype(np.int32))
            edge = x <= 1 or y <= 1 or x + w >= W // 2 - 1 or y + h >= H // 2 - 1
            cur.append(dict(polys=polys, t=t, edge=edge, bottom=y + h, h=h))
        k += 1
        if k % 900 == 0: print(vid, f'{t:.0f}s', flush=True)
    n = 0
    for q in range(4):
        for s in segs[q]:
            if len(s) < 3 * FPS or np.mean([f['edge'] for f in s]) > .1: continue
            n += 1
            s = s[:30 * FPS]
            with open(f'{OUT}/{vid}_q{q + 1}_{n:02d}.pkl', 'wb') as fh:
                pickle.dump(dict(fps=FPS, size=(W // 2, H // 2), t0=s[0]['t'],
                                 frames=[f['polys'] for f in s],
                                 ground=float(np.percentile([f['bottom'] for f in s], 90)),
                                 height=float(np.percentile([f['h'] for f in s], 70))), fh)
            print(f'  {vid} q{q + 1} clip {n}: {len(s) / FPS:.1f}s from {s[0]["t"]:.1f}s', flush=True)
