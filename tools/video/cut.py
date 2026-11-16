"""Cut the segments of src/edit4.json out of the raw clips into public/sNN.mp4 (exact frame count, 30 fps, speed / rewind / freeze baked in).

  python3 tools/video/cut.py --clips DIR
"""
import argparse, json, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clips", required=True)
    a = ap.parse_args()
    cfg = json.load(open(os.path.join(HERE, "src", "edit4.json")))
    fps = cfg["fps"]
    for i, s in enumerate(cfg["segments"]):
        out = os.path.join(HERE, "public", "s%02d.mp4" % i)
        n = round(s["dur"] * fps)
        path = os.path.join(a.clips, s["clip"])
        t0, t1 = s["src"]
        if s.get("freeze"):
            args = ["-ss", f"{t0:.3f}", "-i", path, "-vf", f"trim=end_frame=1,loop={n}:1:0,fps={fps},setpts=N/{fps}/TB"]
        else:
            lo, hi = min(t0, t1), max(t0, t1)
            factor = s["dur"] / (hi - lo)
            vf = f"setpts={factor:.6f}*(PTS-STARTPTS),fps={fps}"
            if t1 < t0:
                vf = "reverse," + vf
            args = ["-ss", f"{lo:.3f}", "-t", f"{hi - lo + 0.1:.3f}", "-i", path, "-vf", vf]
        subprocess.run(["ffmpeg", "-v", "error", "-y", *args, "-an", "-frames:v", str(n), "-c:v", "libx264", "-preset", "fast", "-crf", "14",
                        "-pix_fmt", "yuv420p", "-g", "1", out], check=True)
        got = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries", "stream=nb_read_frames", "-of",
                              "csv=p=0", out], capture_output=True, text=True).stdout.strip()
        print(f"s{i:02d} {s['clip']} {t0}->{t1} {n} frames (got {got})")


if __name__ == "__main__":
    main()
